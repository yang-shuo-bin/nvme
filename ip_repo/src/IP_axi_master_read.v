`timescale 1ns/1ps

`ifndef IP_axi_master_read
 `define IP_axi_master_read

// INTERNAL FILE
// SECURE_PLACEHOLDER_CONFIG
// SECURE_PLACEHOLDER_NETLIST



module IP_axi_master_read #(
   parameter BUS_MULTIPLIER     = 4,
   parameter ADDR_WIDTH         = 32,
   // Allows bus_rready to deassert mid-burst if set to "TRUE"
   parameter ALLOW_RD_DATA_PAUSING = "FALSE",
   // Allows output sys_read_err to be driven on detection of RRESP != RESP_OKAY
   parameter ALLOW_ERR_INTR     = "FALSE",
   // If a R/W request on the sys_bus will cross a 4K address boundary, this allows the module
   // to break the transfer into several smaller transfers straddling the boundary.
   // The theory here is: crossing a 4K boundary is illegal in AXI. If this parameter is set to "TRUE",
   // the AXI Master will enforce the boundary. If set to "FALSE", the user is responsible for enforcing it.
   parameter ENFORCE_4K_BOUND   = "FALSE",
   parameter MAX_BURST_REQ_SIZE = 32768, // Max size of a single burst request, in bus-words
   parameter MAX_ACTIVE_REQS    = 1,   // System-side requests (not arvalid/arready pairs)
                                       // User is responsible for ensuring that their system
                                       // does not issue more than this many requests at a time
   // bus_arcache will be calculated from sys_read_modifiable if "TRUE", otherwise 0
   parameter ALLOW_ARCACHE_CTL  = "FALSE",
   parameter NUM_IDS            = 1,

   // Instantiates the Statistics counter to track Read Channel behavior
   parameter ENABLE_STATISTICS     = 0,
   // By default, statistics will be sim-only. If 1, enables a register interface that is synthesized
   parameter ENABLE_STATISTICS_REG = 0
 )
 (
    input clock,
    input reset_n,

    input                                          sys_read_throttle, // previously sys_fifo_warning -calebw
    output reg [32*BUS_MULTIPLIER-1:0]             sys_read_data,
    output reg                                     sys_read_data_valid,
    output reg [1:0]                               sys_read_resp,
    output reg [clogb2(NUM_IDS)-1:0]               sys_read_resp_id,
    output reg                                     sys_read_data_last,
    input wire [ADDR_WIDTH-1:0]                    sys_read_addr,
    input wire                                     sys_read_keyhole_addr,
    input wire [3:0]                               sys_read_modifiable,
    input wire [clogb2(MAX_BURST_REQ_SIZE+1)-1:0]  sys_read_burst_size,
    input wire                                     sys_read_req,
    input wire [clogb2(NUM_IDS)-1:0]               sys_read_req_id,
    input wire                                     sys_fifo_full, // this should be tied up..
    output wire                                    sys_read_master_ready,
    output wire                                    sys_read_err,

    /*-- Read Address Channel --*/
    output reg                                bus_arvalid,
    input                                     bus_arready,
    output reg [ADDR_WIDTH-1:0]               bus_araddr,
    output reg [1:0]                          bus_arburst,
    output reg [3:0]                          bus_arcache,
    output reg [7:0]                          bus_arlen,
    output reg [2:0]                          bus_arprot,
    output reg [2:0]                          bus_arsize,
    output reg [11:0]                         bus_aruser,
    output reg [clogb2(NUM_IDS)-1:0]          bus_arid,

    /*-- Read Data Channel --*/
    input                                     bus_rvalid,
    input      [32*BUS_MULTIPLIER-1:0]        bus_rdata,
    input                                     bus_rlast,
    input [1:0]                               bus_rresp,
    input [clogb2(NUM_IDS)-1:0]               bus_rid,
    output reg                                bus_rready,

    /*-- Statistics I/F --*/
    output wire [63:0]                        IP_RdData,
    input  wire [3:0]                         IP_WrEn,
    input  wire [3:0]                         IP_Addr,
    input  wire [31:0]                        IP_WrData,
    output wire                               rap_thresh_intr,
    output wire                               rdp_thresh_intr,

    output reg [4:0]                          c_state_rap,
    output reg [4:0]                          c_state_rdp

    );

 // Size decode: ((2 ^ AxSIZE) # of bytes)
 // AxSIZE[2:0] --- Bytes in transfer
 //  3'b000     ---   1
 //  3'b001     ---   2
 //  3'b010     ---   4
 //  3'b011     ---   8
 //  3'b100     ---   16
 //  3'b101     ---   32
 //  3'b110     ---   64
 //  3'b111     ---   128

 // Burst Type Decode:
  localparam [1:0] BURST_FIXED = 2'b00;// Keyhole/FIFO addressing. Address stays the same through burst.
  localparam [1:0] BURST_INCR  = 2'b01;// The address for each transfer += 1 of previous burst.
  localparam [1:0] BURST_WRAP  = 2'b10;// Address wraps back to lower address if upper address reached.

 //These equations determine addresses of transfers within a burst:
 //â€? Start_Address = AxADDR
 //â€? Number_Bytes = 2 ^ AxSIZE
 //â€? Burst_Length = AxLEN + 1
 //â€? Aligned_Address = (INT(Start_Address / Number_Bytes) ) x Number_Bytes.
 //  (INT(x) is the rounded-down integer value of x)

 // Response Type Decode:
  localparam [1:0] RESP_OKAY = 2'b00; // Normal access success. (May also indicate, exclusive access failed).
  localparam [1:0] RESP_EXOK = 2'b01; // Exclusive access success.
  localparam [1:0] RESP_SLAVE_ERR  = 2'b10; // Slave error. Request reached slave successfully, but slave errored.
  localparam [1:0] RESP_DECODE_ERR = 2'b11; // Decode error. Generated by an interconnect component. (Bad Address)

 // Memory attribute signaling
  //AxCACHE Value Transaction attribute
  // bit[0] 0-Non-bufferable    1-Bufferable
  // bit[1] 0-Non-cacheable     1-Cacheable
  // bit[2] 0-No Read-allocate  1-Read-allocate
  // bit[3] 0-No Write-allocate 1-Write-allocate

 localparam [4:0] READ_ADDR_IDLE = 5'h00,
                  READ_ADDR_REQ  = 5'h01,
                  READ_ADDR_CALC_REQ = 5'h02;

 localparam [4:0] READ_DATA_IDLE = 5'h00,
                  READ_DATA_WAIT = 5'h01;

 localparam       M_BURST_BYTES     = 4*BUS_MULTIPLIER*MAX_BURST_REQ_SIZE;
 localparam       M_ACT_BURST_BYTES = (          M_BURST_BYTES           )*MAX_ACTIVE_REQS;
 localparam       ENABLE_STATS_FOR_RUN =
                  // synthesis translate_off
                                         ENABLE_STATISTICS ? ENABLE_STATISTICS :
                  // synthesis translate_on
                                         ENABLE_STATISTICS_REG;

 // Read Address Pipe State Signls
 reg [4:0] n_state_rap;
 // Read Data Pipe State Signls
 reg [4:0] n_state_rdp;

 reg [ADDR_WIDTH-1:0]                  ReadSysAddr_r;
 reg [1:0]                             ReadBurstType_r;
 reg [3:0]                             ReadCacheType_r;
 reg [clogb2(M_ACT_BURST_BYTES+1)-1:0] RRemainingBurstDataByteCount;
 reg [clogb2(M_BURST_BYTES+1)-1:0]     RRemainingBurstReqByteCount;
 reg [2:0]                             ReadBurstSize_r;
 reg [clogb2(NUM_IDS)-1:0]             ReadID_r;

 reg [8:0]                             cur_read_burst_length_d;

 // Changed this to be 1 on keyhole reads since the ddr controller (mig) would internally
 // increment the address of a burst. This leads to possible inadvertant data corruption... -EH
 //wire [8:0] read_max_burst_length  = (ReadBurstType_r  == BURST_FIXED) ? 1 : 256;
 wire [8:0] read_max_burst_length  = (ReadBurstType_r  == BURST_FIXED) ? 16 :
                                     (ENFORCE_4K_BOUND == "TRUE" &
                                      ((4096-ReadSysAddr_r[11:0]) <
                                       256*(4*BUS_MULTIPLIER)))        ? ((4096-ReadSysAddr_r[11:0]) >>
                                                                         clogb2(4*BUS_MULTIPLIER)) :
                                                                         256;
 wire [8:0] cur_read_burst_length = (RRemainingBurstReqByteCount<(4*BUS_MULTIPLIER)) ? 1 :
        ((RRemainingBurstReqByteCount/(4*BUS_MULTIPLIER)) < {4'h0,read_max_burst_length}) ?
         (RRemainingBurstReqByteCount/(4*BUS_MULTIPLIER)) : read_max_burst_length;

 wire [ADDR_WIDTH-1:0]   sys_read_addr_aligned;

 assign sys_read_addr_aligned = {sys_read_addr[ADDR_WIDTH-1 : clogb2(BUS_MULTIPLIER*4)],
                                 {clogb2(BUS_MULTIPLIER*4){1'b0}}};

  // The c_state_rap condition will usually only deassert sys_read_master_ready for a single cycle, while
  // in READ_ADDR_REQ, but it also deasserts ready when a single request is being broken into smaller
  // bursts, based on read_max_burst_length, while in READ_ADDR_CALC_REQ.
  assign sys_read_master_ready = (MAX_ACTIVE_REQS == 1) ?
                                 ((c_state_rap == READ_ADDR_IDLE) & (c_state_rdp == READ_DATA_IDLE)) :
                                  (c_state_rap == READ_ADDR_IDLE);

 //////////////////////////////////////
 // DRC Checks
 //
 `include "iprop_assert.vh"
 `iprop_assert(1,
               ((BUS_MULTIPLIER & (BUS_MULTIPLIER-1)) == 32'h0),
               "Parameter BUS_MULTIPLIER not valid! BUS_MULTIPLIER must be a power of 2")
 `iprop_assert(1,
               (ALLOW_ERR_INTR == "TRUE") || (ALLOW_ERR_INTR == "FALSE"),
               "Parameter ALLOW_ERR_INTR not valid! ALLOW_ERR_INTR must be either TRUE or FALSE")
 `iprop_assert(1,
               (ENFORCE_4K_BOUND == "TRUE") || (ENFORCE_4K_BOUND == "FALSE"),
               "Parameter ENFORCE_4K_BOUND not valid! ENFORCE_4K_BOUND must be either TRUE or FALSE")
 `iprop_assert(1,
               (MAX_BURST_REQ_SIZE > (64/BUS_MULTIPLIER)),
               "Parameter MAX_BURST_REQ_SIZE not valid! MAX_BURST_REQ_SIZE must be larger than 64/BUS_MULTIPLIER")
 `include "iprop_clocked_assert.vh"
 `iprop_clocked_assert(clock,
                       sys_read_req,
                       (sys_read_req_id < (NUM_IDS)),
                       "Transfer request not valid! sys_read_req_id must be less than NUM_IDS")
 `iprop_clocked_assert(clock,
                       sys_read_req,
                       sys_read_master_ready,
                       "Transfer request not valid! AXI read channel received Req when not Ready!")
 `iprop_clocked_assert(clock,
                       sys_read_data_valid,
                       !sys_fifo_full,
                       "FIFO overflow!!!! AXI read channel pushed to FIFO when full!!!!")
 `iprop_clocked_assert(clock,
                       bus_arvalid & bus_arready & (ENFORCE_4K_BOUND == "FALSE"),
                       ((ReadSysAddr_r[11:0] + (cur_read_burst_length << ReadBurstSize_r)) <= 4096),
                       "Read Request to master will cross a 4K Address boundary!")

 //////////////////////////////////////
 // Read Statistics Counter
 //
// generate
//   if (ENABLE_STATS_FOR_RUN) begin: READ_STATS
//     wire [3:0]  IP_WrEn_mod;
//     wire [3:0]  IP_Addr_mod;
//     wire [31:0] IP_WrData_mod;
//     wire        rap_wait_trigger,          rdp_wait_trigger;
//     reg         rap_wait_trigger_en_toggle,rdp_wait_trigger_en_toggle;
//     wire        rap_counter_enabled,       rdp_counter_enabled;
//     wire        rap_reset,                 rdp_reset;
//     wire [63:0] rap_thresh,                rdp_thresh;
//     reg         rap_thresh_set,            rdp_thresh_set;
//     wire [47:0] rap_wait_count,            rdp_wait_count;
//     reg         rap_intr_en_toggle,        rdp_intr_en_toggle;
//     wire        rap_intr_enabled,          rdp_intr_enabled;
//     reg         rap_thresh_wrap_toggle,    rdp_thresh_wrap_toggle;
//     wire        rap_thresh_wrap_enabled,   rdp_thresh_wrap_enabled;

//     assign rap_wait_trigger = (c_state_rap == READ_ADDR_REQ);
//     assign rap_thresh       = 64'h0;
//     assign rap_reset        = 1'b0;
//     assign rdp_wait_trigger = |RRemainingBurstDataByteCount;
//     assign rdp_thresh       = 64'h0;
//     assign rdp_reset        = 1'b0;

//     if (ENABLE_STATISTICS_REG) begin: READ_STATS_REG
//       assign IP_WrEn_mod   = IP_WrEn;
//       assign IP_Addr_mod   = IP_Addr;
//       assign IP_WrData_mod = IP_WrData;

//       always@(*) begin
//         rap_wait_trigger_en_toggle = 1'b0;
//         rap_thresh_set             = 1'b0;
//         rap_intr_en_toggle         = 1'b0;
//         rap_thresh_wrap_toggle     = 1'b0;
//         rdp_wait_trigger_en_toggle = 1'b0;
//         rdp_thresh_set             = 1'b0;
//         rdp_intr_en_toggle         = 1'b0;
//         rdp_thresh_wrap_toggle     = 1'b0;
//       end
//     end // READ_STATS_REG
//     else begin: READ_STATS_SIM
//       assign IP_WrEn_mod   = 4'h0;
//       assign IP_Addr_mod   = 4'h0;
//       assign IP_WrData_mod = 32'h00000000;

//       always@(*) begin
//         rap_wait_trigger_en_toggle = !rap_counter_enabled;
//         rap_thresh_set             = 1'b1;
//         rap_intr_en_toggle         = rap_intr_enabled;
//         rap_thresh_wrap_toggle     = rap_thresh_wrap_enabled;
//         rdp_wait_trigger_en_toggle = !rdp_counter_enabled;
//         rdp_thresh_set             = 1'b1;
//         rdp_intr_en_toggle         = rdp_intr_enabled;
//         rdp_thresh_wrap_toggle     = rdp_thresh_wrap_enabled;
//       end
//     end // READ_STATS_SIM

//     // NOTE: NUM_STATS is hardcoded to 2. IP_Addr width is dependent on NUM_STATS,
//     //       so if new stats are desired, adjust wire widths appropriately
//     IP_stats_tracker #(
//       .NUM_STATS  (2),
//       .BUS_ENABLE (ENABLE_STATISTICS_REG),
//       .REG_STAGE  (0)
//     ) i_rd_stats (
//       /*-- Clock and Reset --*/
//       .clock          (clock),
//       .reset          (~reset_n), // Posedge, synchronous

//       /*-- IntelliProp Register Bus i/f --*/
//       .IP_RdData      (IP_RdData),
//       .IP_WrEn        (IP_WrEn_mod),
//       .IP_WrBusy      (), // Unused
//       .IP_RdDataValid (), // Unused
//       .IP_Addr        (IP_Addr_mod),
//       .IP_WrData      (IP_WrData_mod),
//       .IP_RdEn        (), // Unused

//       /*-- SM i/f --*/
//       .trigger            ({rdp_wait_trigger,          rap_wait_trigger}),
//       .trigger_en_toggle  ({rdp_wait_trigger_en_toggle,rap_wait_trigger_en_toggle}),
//       .counter_enabled    ({rdp_counter_enabled,       rap_counter_enabled}),
//       .counter_reset      ({rdp_reset,                 rap_reset}),
//       .event_thresh       ({rdp_thresh,                rap_thresh}),
//       .event_thresh_set   ({rdp_thresh_set,            rap_thresh_set}),
//       .event_count        ({rdp_wait_count,            rap_wait_count}),
//       .intr_en_toggle     ({rdp_intr_en_toggle,        rap_intr_en_toggle}),
//       .intr_enabled       ({rdp_intr_enabled,          rap_intr_enabled}),
//       .thresh_interrupt   ({rdp_thresh_intr,           rap_thresh_intr}),
//       .thresh_wrap_toggle ({rdp_thresh_wrap_toggle,    rap_thresh_wrap_toggle}),
//       .thresh_wrap_enabled({rdp_thresh_wrap_enabled,   rap_thresh_wrap_enabled})
//     );
//   end // READ_STATS
//   else begin: NO_STATS
     assign IP_RdData       = 64'h0;
     assign rap_thresh_intr = 1'b0;
     assign rdp_thresh_intr = 1'b0;
//   end // NO_STATS
// endgenerate

 //////////////////////////////////////
 // Read State Machine
 //
 always@(posedge clock or negedge reset_n)
  if (!reset_n)
   c_state_rap <= READ_ADDR_IDLE;
  else
   c_state_rap <= n_state_rap;

 always@(posedge clock or negedge reset_n)
  if (!reset_n)
   c_state_rdp <= READ_DATA_IDLE;
  else
   c_state_rdp <= n_state_rdp;

  always @(posedge clock or negedge reset_n)
   if(!reset_n)
     cur_read_burst_length_d <= 9'b0;
   else
     cur_read_burst_length_d <= cur_read_burst_length;

  /*-- Keep track of read requests --*/
  always@(posedge clock or negedge reset_n)
   if(!reset_n)
     RRemainingBurstReqByteCount <=  {clogb2(M_BURST_BYTES+1){1'b0}};
   else if ((c_state_rap == READ_ADDR_IDLE) & sys_read_req)
     RRemainingBurstReqByteCount <=  sys_read_burst_size*4*BUS_MULTIPLIER;
   else if ((c_state_rap == READ_ADDR_REQ) & bus_arready)
     RRemainingBurstReqByteCount <= (RRemainingBurstReqByteCount >= (cur_read_burst_length<<ReadBurstSize_r)) ?
                                    (RRemainingBurstReqByteCount - (cur_read_burst_length<<ReadBurstSize_r)) :
                                    {clogb2(M_BURST_BYTES+1){1'b0}};
   else
     RRemainingBurstReqByteCount <=  RRemainingBurstReqByteCount;

  /*-- Keep track of read data received --*/
  always@(posedge clock or negedge reset_n)
   if(!reset_n)
     RRemainingBurstDataByteCount <= 'h0;
   else if (sys_read_req & (MAX_ACTIVE_REQS > 1) & (c_state_rdp == READ_DATA_WAIT) & bus_rvalid & bus_rready)
     RRemainingBurstDataByteCount <= RRemainingBurstDataByteCount + sys_read_burst_size*4*BUS_MULTIPLIER - 4*BUS_MULTIPLIER;
   else if (sys_read_req & ((MAX_ACTIVE_REQS > 1) | (c_state_rdp == READ_DATA_IDLE)))
     RRemainingBurstDataByteCount <= RRemainingBurstDataByteCount + sys_read_burst_size*4*BUS_MULTIPLIER;
   else if ((c_state_rdp == READ_DATA_WAIT) & bus_rvalid & bus_rready)
     RRemainingBurstDataByteCount <= (RRemainingBurstDataByteCount >= 4*BUS_MULTIPLIER) ?
                                     (RRemainingBurstDataByteCount - 4*BUS_MULTIPLIER) :
                                     'h0;
   else
     RRemainingBurstDataByteCount <= RRemainingBurstDataByteCount;

 wire [2:0] arsize_wire = (BUS_MULTIPLIER ==  1) ? 3'b010 : //  4-bytes in transfer
                          (BUS_MULTIPLIER ==  2) ? 3'b011 : //  8-bytes in transfer
                          (BUS_MULTIPLIER ==  4) ? 3'b100 : // 16-bytes in transfer
                          (BUS_MULTIPLIER ==  8) ? 3'b101 : // 32-bytes in transfer
                          (BUS_MULTIPLIER == 16) ? 3'b110 : // 64-bytes in transfer
                          (BUS_MULTIPLIER == 32) ? 3'b111 : //128-bytes in transfer
                                                   3'b000;  //  1-byte  in transfer

 wire [ADDR_WIDTH-1:0] IncrReadSysAddr = (ReadBurstType_r == BURST_FIXED) ?
                                          ReadSysAddr_r :
                                          (ReadSysAddr_r + ({8'h00,cur_read_burst_length_d}<<ReadBurstSize_r));

 /*-- Begin Read Address Pipe: --*/
    always@(posedge clock or negedge reset_n)
     if(!reset_n) begin
       ReadSysAddr_r   <= 32'h0;
       ReadBurstType_r <=  2'b0;
       ReadCacheType_r <=  4'b0;
       ReadBurstSize_r <=  3'b0;
       ReadID_r        <= {clogb2(NUM_IDS){1'b0}};
     end
     else if ((c_state_rap == READ_ADDR_IDLE) & sys_read_req) begin
       ReadSysAddr_r   <= sys_read_keyhole_addr ? sys_read_addr : sys_read_addr_aligned;
       ReadBurstType_r <= sys_read_keyhole_addr ? BURST_FIXED : BURST_INCR;
       ReadCacheType_r <= (ALLOW_ARCACHE_CTL == "TRUE") ? sys_read_modifiable : 4'b0; // <- Default as non-cacheable.
       ReadBurstSize_r <= arsize_wire;
       ReadID_r        <= sys_read_req_id;
     end
     else if (c_state_rap == READ_ADDR_CALC_REQ) begin
       ReadSysAddr_r   <= IncrReadSysAddr;
       ReadBurstType_r <= ReadBurstType_r;
       ReadCacheType_r <= ReadCacheType_r;
       ReadBurstSize_r <= arsize_wire;
       ReadID_r        <= ReadID_r;
     end
     else begin
       ReadSysAddr_r   <= ReadSysAddr_r;
       ReadBurstType_r <= ReadBurstType_r;
       ReadCacheType_r <= ReadCacheType_r;
       ReadBurstSize_r <= ReadBurstSize_r;
       ReadID_r        <= ReadID_r;
     end

    always@(*)
     case(c_state_rap)
       READ_ADDR_IDLE: begin
        bus_arvalid = 1'b0;
        bus_araddr  = ReadSysAddr_r;
        bus_arburst = ReadBurstType_r;
        bus_arcache = ReadCacheType_r;
        bus_arlen   = 8'h0;
        bus_arprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
        bus_arsize  = ReadBurstSize_r;
        bus_aruser  = 12'h0;
        bus_arid    = {clogb2(NUM_IDS){1'b0}};
       end
       READ_ADDR_REQ: begin
        bus_arvalid = 1'b1;
        bus_araddr  = ReadSysAddr_r;
        bus_arburst = ReadBurstType_r;
        bus_arcache = ReadCacheType_r;
        bus_arlen   = cur_read_burst_length-1;
        bus_arprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
        bus_arsize  = ReadBurstSize_r;
        bus_aruser  = cur_read_burst_length*4*BUS_MULTIPLIER; // This will need to change to support
                                                              // non-bus-width-bursts in the future -EH
        bus_arid    = ReadID_r;
       end
       READ_ADDR_CALC_REQ: begin
        bus_arvalid = 1'b0;
        bus_araddr  = ReadSysAddr_r;
        bus_arburst = ReadBurstType_r;
        bus_arcache = ReadCacheType_r;
        bus_arlen   = cur_read_burst_length-1;
        bus_arprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
        bus_arsize  = ReadBurstSize_r;
        bus_aruser  = 12'h0;
        bus_arid    = ReadID_r;
       end
      default: begin
        bus_arvalid = 1'b0;
        bus_araddr  = ReadSysAddr_r;
        bus_arburst = ReadBurstType_r;
        bus_arcache = ReadCacheType_r;
        bus_arlen   = cur_read_burst_length-1;
        bus_arprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
        bus_arsize  = ReadBurstSize_r;
        bus_aruser  = 12'h0;
        bus_arid    = {clogb2(NUM_IDS){1'b0}};
      end
      endcase

    always@(*)
     case(c_state_rap)
       READ_ADDR_IDLE:
        if(sys_read_req)
          n_state_rap = READ_ADDR_REQ;
        else
          n_state_rap = READ_ADDR_IDLE;
       READ_ADDR_REQ:
        if(bus_arready & (RRemainingBurstReqByteCount <= (cur_read_burst_length*4*BUS_MULTIPLIER)))
          n_state_rap = READ_ADDR_IDLE;
        else if (bus_arready)
          n_state_rap = READ_ADDR_CALC_REQ;
        else
          n_state_rap = READ_ADDR_REQ;
       READ_ADDR_CALC_REQ:
          n_state_rap = READ_ADDR_REQ;
      default:
       n_state_rap = c_state_rap;
     endcase

   /*-- Begin Read Data Pipe --*/
    always@(posedge clock or negedge reset_n)
     if(!reset_n) begin
      sys_read_data       <= {BUS_MULTIPLIER{32'h0}};
      sys_read_data_valid <= 1'b0;
      sys_read_resp       <= 2'b00;
      sys_read_resp_id    <= {clogb2(NUM_IDS){1'b0}};
     end
     else if (bus_rvalid & bus_rready) begin
      sys_read_data       <= bus_rdata;
      sys_read_data_valid <= 1'b1;
      sys_read_resp       <= bus_rresp;
      sys_read_resp_id    <= bus_rid;
     end
     else begin
      sys_read_data       <= sys_read_data;
      sys_read_data_valid <= 1'b0;
      sys_read_resp       <= sys_read_resp;
      sys_read_resp_id    <= sys_read_resp_id;
     end

    always@(posedge clock) begin
      sys_read_data_last     <= bus_rlast;
    end

  generate
   if (ALLOW_ERR_INTR == "TRUE") begin: READ_ERR_DETECT

    reg ReadErrOccurrence_r;

    assign sys_read_err = ReadErrOccurrence_r;

    always@(posedge clock or negedge reset_n)
     if(!reset_n)
       ReadErrOccurrence_r <= 1'b0;
     else case (c_state_rdp)
       READ_DATA_IDLE:
         ReadErrOccurrence_r <= (bus_rvalid & bus_rready) | ReadErrOccurrence_r;
       READ_DATA_WAIT:
         ReadErrOccurrence_r <= (bus_rvalid & bus_rready & (bus_rresp != RESP_OKAY)) | ReadErrOccurrence_r;
       default:
         ReadErrOccurrence_r <= (bus_rvalid & bus_rready) | ReadErrOccurrence_r;
     endcase

   end // READ_ERR_DETECT
   else begin: NO_READ_ERR_DETECT
     assign sys_read_err = 1'b0;
   end // NO_READ_ERR_DETECT
  endgenerate

    wire rready_pause = (ALLOW_RD_DATA_PAUSING == "TRUE") ? sys_read_throttle : 1'b0;
    always@(posedge clock or negedge reset_n)
     if(!reset_n)
                      bus_rready <= 1'b0;
     else if (bus_rready & bus_rvalid & bus_rlast &
              ((MAX_ACTIVE_REQS > 1) ? (RRemainingBurstDataByteCount <= 4*BUS_MULTIPLIER) : 1'b1))
                      bus_rready <= 1'b0;
     else case (c_state_rdp)
      READ_DATA_IDLE: bus_rready <= 1'b0;
      READ_DATA_WAIT: bus_rready <= ~rready_pause;
      default:        bus_rready <= 1'b0;
     endcase

    always@(*)
     case(c_state_rdp)
      READ_DATA_IDLE:
       if(sys_read_req)
        n_state_rdp = READ_DATA_WAIT;
       else
        n_state_rdp = READ_DATA_IDLE;
      READ_DATA_WAIT:
       if((bus_rlast & bus_rvalid & bus_rready) & (RRemainingBurstDataByteCount <= 4*BUS_MULTIPLIER) & ~sys_read_req)
        n_state_rdp = READ_DATA_IDLE;
       else
        n_state_rdp = READ_DATA_WAIT;
      default:
       n_state_rdp = c_state_rdp;
     endcase


`include "ip_functions.vh"

endmodule
`endif //IP_axi_master_read





