`timescale 1ns/1ps
`ifndef IP_axi_master_write
 `define IP_axi_master_write

// INTERNAL FILE
// SECURE_PLACEHOLDER_CONFIG
// SECURE_PLACEHOLDER_NETLIST



module IP_axi_master_write #(
   parameter BUS_MULTIPLIER                 = 4,
   parameter ADDR_WIDTH                     = 32,
   // Allows bus_wvalid to deassert mid-burst if set to "TRUE"
   parameter ALLOW_DATA_PAUSING             = "TRUE",
   // Determines whether sys_write_byte_size is used in bytes-remaining calculations
   parameter ALLOW_BYTE_ACCESS              = "FALSE",
   // Allows output sys_write_err to be driven on detection of BRESP != RESP_OKAY
   parameter ALLOW_ERR_INTR                 = "FALSE",
   // If a R/W request on the sys_bus will cross a 4K address boundary, this allows the module
   // to break the transfer into several smaller transfers straddling the boundary.
   // The theory here is: crossing a 4K boundary is illegal in AXI. If this parameter is set to "TRUE",
   // the AXI Master will enforce the boundary. If set to "FALSE", the user is responsible for enforcing it.
   parameter ENFORCE_4K_BOUND               = "FALSE",
   // Allows sys_byte_enable to directly drive bus_wstrb, without a reg stage -calebw
   parameter BYTE_EN_PASSTHROUGH            = "FALSE",
   // Specify whether or not multiple outstanding requests is supported. If > 1,
   // sys_write_master_ready will only deassert during write requests, instead of waiting
   // for bresp to arrive. In this case, the application layer is expected to consume bresp
   // Only applies to write-side as of 1/25/2018 --calebw
   parameter MAX_ACTIVE_REQS                = 1,
   parameter MAX_BURST_REQ_SIZE             = 32768, // Max size of a single burst request, in bus-words
                                                     // Must be larger than 64/BUS_MULTIPLIER (due to
                                                     // some math on this field)
   // bus_awcache will be calculated from sys_write_modifiable if "TRUE", otherwise 0
   parameter ALLOW_AWCACHE_CTL              = "FALSE",
   parameter NUM_IDS                        = 1,

   // Instantiates the Statistics counter to track Write Channel behavior
   parameter ENABLE_STATISTICS     = 0,
   // By default, statistics will be sim-only. If 1, enables a register interface
   parameter ENABLE_STATISTICS_REG = 0
 )
 (
    input clock,
    input reset_n,

    input                         sys_fifo_empty,
    input                         sys_fifo_warn,
    input [32*BUS_MULTIPLIER-1:0] sys_write_data,
    output                        sys_fifo_read,
    input [4*BUS_MULTIPLIER-1:0]  sys_byte_enable,

    /*-- Register Control Port --*/
    input wire [ADDR_WIDTH-1:0]                    sys_write_addr,
    input wire                                     sys_write_keyhole_addr,
    input wire [3:0]                               sys_write_modifiable,
    input wire [clogb2(MAX_BURST_REQ_SIZE+1)-1:0]  sys_write_burst_size, // bus words.
    input wire [clogb2(BUS_MULTIPLIER*4)-1:0]      sys_write_byte_size,
    input wire                                     sys_write_req,
    input wire [clogb2(NUM_IDS)-1:0]               sys_write_req_id,
    output wire                                    sys_write_master_ready,
    input wire                                     sys_write_resp_ready,
    output wire                                    sys_write_resp_valid,
    output wire [1:0]                              sys_write_resp,
    output wire [clogb2(NUM_IDS)-1:0]              sys_write_resp_id,
    output wire                                    sys_write_err,

    /*-- Write Address Channel --*/
    input                                  bus_awready,
    output reg                             bus_awvalid,
    output reg [ADDR_WIDTH-1:0]            bus_awaddr,
    output reg [1:0]                       bus_awburst,
    output reg [3:0]                       bus_awcache,
    output reg [7:0]                       bus_awlen,
    output reg [2:0]                       bus_awprot,
    output reg [2:0]                       bus_awsize,
    output reg [11:0]                      bus_awuser,
    output reg [clogb2(NUM_IDS)-1:0]       bus_awid,

    /*-- Write Data Channel --*/
    input                                  bus_wready,
    output reg                             bus_wvalid,
    output                                 bus_wlast,
    output /*reg*/ [32*BUS_MULTIPLIER-1:0] bus_wdata, // add reg stage! -EH
    output reg [ 4*BUS_MULTIPLIER-1:0]     bus_wstrb,

    /*-- Write Response Channel --*/
    input                                  bus_bvalid,
    input                      [1:0]       bus_bresp,
    input   [clogb2(NUM_IDS)-1:0]          bus_bid,
    output reg                             bus_bready,

    /*-- Statistics I/F --*/
    output wire [63:0]                        IP_RdData,
    input  wire [3:0]                         IP_WrEn,
    input  wire [3:0]                         IP_Addr,
    input  wire [31:0]                        IP_WrData,
    output wire                               wap_thresh_intr,
    output wire                               wdp_thresh_intr,
    output wire                               wrp_thresh_intr,

    output reg [4:0] c_state_wap,
    output reg [4:0] c_state_wdp

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

 localparam [4:0] WRITE_ADDR_IDLE     = 5'h00,
                  WRITE_ADDR_REQ      = 5'h01,
                  WRITE_ADDR_CALC_REQ = 5'h02;

 localparam [4:0] WRITE_DATA_IDLE = 5'h00,
                  WRITE_DATA_WAIT = 5'h01,
                  WRITE_DATA_CALC_BURST = 5'h02;

 localparam [4:0] WRITE_RESP_IDLE = 5'h00,
                  WRITE_RESP_WAIT = 5'h01;

 // Bits needed to store the maximum number of bytes accepted for a single burst request
 localparam       M_ACT_BYTES_WIDTH = clogb2(4*BUS_MULTIPLIER*MAX_BURST_REQ_SIZE+1);
 localparam       ENABLE_STATS_FOR_RUN =
                  // synthesis translate_off
                                         ENABLE_STATISTICS ? ENABLE_STATISTICS :
                  // synthesis translate_on
                                         ENABLE_STATISTICS_REG;

 // Write Address Pipe State Signals
 reg [4:0] n_state_wap;
 // Write Data Pipe State Signals
 reg [4:0] n_state_wdp;
 // Write Response Pipe State Signals
 reg [4:0] c_state_wrp, n_state_wrp;

 reg [ADDR_WIDTH-1:0]        WriteSysAddr_r;
 reg [1:0]                   WriteBurstType_r;
 reg [3:0]                   WriteCacheType_r;
 reg [M_ACT_BYTES_WIDTH-1:0] WRemainingBurstDataByteCount;
 reg [M_ACT_BYTES_WIDTH-1:0] WRemainingBurstReqByteCount;
 reg [7:0]                   WBurstWordCount;
 reg [2:0]                   WriteBurstSize_r;
 reg [clogb2(NUM_IDS)-1:0]   WriteID_r;
 reg [4*BUS_MULTIPLIER-1:0]  WriteSteadyByteEn_r;
 reg [7:0]                   OutstandingWriteReq;
 wire                        last_resp_active;

 reg [8:0]                   cur_write_burst_length_d;

 // Changed this to be 1 on keyhole writes since the ddr controller (mig) would internally
 // increment the address of a burst. This leads to possible inadvertant data corruption... -EH
 //wire [8:0] write_max_burst_length = (WriteBurstType_r == BURST_FIXED) ? 1 : 256;
 wire [8:0] write_max_burst_length = (WriteBurstType_r == BURST_FIXED) ? 16 :
                                     (ENFORCE_4K_BOUND == "TRUE" &
                                      ((4096-WriteSysAddr_r[11:0]) <
                                       256*(4*BUS_MULTIPLIER)))        ? ((4096-WriteSysAddr_r[11:0]) >>
                                                                         clogb2(4*BUS_MULTIPLIER)) :
                                                                         256;
 reg  [8:0] checkpoint;

 wire [M_ACT_BYTES_WIDTH-1:0] WRemainingBurstReq = WRemainingBurstReqByteCount/(4*BUS_MULTIPLIER);
 wire [8:0] cur_write_burst_length = (WRemainingBurstReqByteCount<(4*BUS_MULTIPLIER))       ? 1                  :
                                     (WRemainingBurstReq <
                                      {{M_ACT_BYTES_WIDTH-9{1'b0}},write_max_burst_length}) ? WRemainingBurstReq :
                                                                                              write_max_burst_length;

 ////////////////////////////////////////
 // DRC Checks
 //
 `include "iprop_assert.vh"
 `iprop_assert(1,
               ((BUS_MULTIPLIER & (BUS_MULTIPLIER-1)) == 32'h0),
               "Parameter BUS_MULTIPLIER not valid! BUS_MULTIPLIER must be a power of 2")
 `iprop_assert(1,
               (ALLOW_DATA_PAUSING == "TRUE") || (ALLOW_DATA_PAUSING == "FALSE"),
               "Parameter ALLOW_DATA_PAUSING not valid! ALLOW_DATA_PAUSING must be either TRUE or FALSE")
 `iprop_assert(1,
               (ALLOW_BYTE_ACCESS == "TRUE") || (ALLOW_BYTE_ACCESS == "FALSE"),
               "Parameter ALLOW_BYTE_ACCESS not valid! ALLOW_BYTE_ACCESS must be either TRUE or FALSE")
 `iprop_assert(1,
               (ALLOW_ERR_INTR == "TRUE") || (ALLOW_ERR_INTR == "FALSE"),
               "Parameter ALLOW_ERR_INTR not valid! ALLOW_ERR_INTR must be either TRUE or FALSE")
 `iprop_assert(1,
               (ENFORCE_4K_BOUND == "TRUE") || (ENFORCE_4K_BOUND == "FALSE"),
               "Parameter ENFORCE_4K_BOUND not valid! ENFORCE_4K_BOUND must be either TRUE or FALSE")
 `iprop_assert(1,
               (BYTE_EN_PASSTHROUGH == "TRUE") || (BYTE_EN_PASSTHROUGH == "FALSE"),
               "Parameter BYTE_EN_PASSTHROUGH not valid! BYTE_EN_PASSTHROUGH must be either TRUE or FALSE")
 `iprop_assert(1,
               (MAX_BURST_REQ_SIZE > (64/BUS_MULTIPLIER)),
               "Parameter MAX_BURST_REQ_SIZE not valid! MAX_BURST_REQ_SIZE must be larger than 64/BUS_MULTIPLIER")
 `include "iprop_clocked_assert.vh"
 `iprop_clocked_assert(clock,
                       sys_write_req,
                       (sys_write_req_id < (NUM_IDS)),
                       "Transfer request not valid! sys_write_req_id must be less than NUM_IDS")
 `iprop_clocked_assert(clock,
                       sys_write_req,
                       sys_write_master_ready,
                       "Transfer request not valid! AXI write channel received Req when not Ready!")
 `iprop_clocked_assert(clock,
                       sys_fifo_read,
                       !sys_fifo_empty,
                       "FIFO under-flow!!!! AXI write channel read from the FIFO when it was empty!!!!")
 `iprop_clocked_assert(clock,
                       bus_awvalid & bus_awready & (ENFORCE_4K_BOUND == "FALSE"),
                       ((WriteSysAddr_r[11:0] + ({8'h00,cur_write_burst_length} << WriteBurstSize_r)) <= 4096),
                       "Write Request to master will cross a 4K Address boundary!")

 //////////////////////////////////////
 // Write Statistics Counter
 //
// generate
//   if (ENABLE_STATS_FOR_RUN) begin: WRITE_STATS
//     wire [3:0]  IP_WrEn_mod;
//     wire [3:0]  IP_Addr_mod;
//     wire [31:0] IP_WrData_mod;
//     wire        wap_wait_trigger,          wdp_wait_trigger,          wrp_wait_trigger;
//     reg         wap_wait_trigger_en_toggle,wdp_wait_trigger_en_toggle,wrp_wait_trigger_en_toggle;
//     wire        wap_counter_enabled,       wdp_counter_enabled,       wrp_counter_enabled;
//     wire        wap_reset,                 wdp_reset,                 wrp_reset;
//     wire [63:0] wap_thresh,                wdp_thresh,                wrp_thresh;
//     reg         wap_thresh_set,            wdp_thresh_set,            wrp_thresh_set;
//     wire [47:0] wap_wait_count,            wdp_wait_count,            wrp_wait_count;
//     reg         wap_intr_en_toggle,        wdp_intr_en_toggle,        wrp_intr_en_toggle;
//     wire        wap_intr_enabled,          wdp_intr_enabled,          wrp_intr_enabled;
//     reg         wap_thresh_wrap_toggle,    wdp_thresh_wrap_toggle,    wrp_thresh_wrap_toggle;
//     wire        wap_thresh_wrap_enabled,   wdp_thresh_wrap_enabled,   wrp_thresh_wrap_enabled;

//     assign wap_wait_trigger = (c_state_wap == WRITE_ADDR_REQ);
//     assign wap_thresh       = 64'h0;
//     assign wap_reset        = 1'b0;
//     assign wdp_wait_trigger = bus_wvalid & !bus_wready;
//     assign wdp_thresh       = 64'h0;
//     assign wdp_reset        = 1'b0;
//     assign wrp_wait_trigger = |OutstandingWriteReq;
//     assign wrp_thresh       = 64'h0;
//     assign wrp_reset        = 1'b0;

//     if (ENABLE_STATISTICS_REG) begin: WRITE_STATS_REG
//       assign IP_WrEn_mod   = IP_WrEn;
//       assign IP_Addr_mod   = IP_Addr;
//       assign IP_WrData_mod = IP_WrData;

//       always@(*) begin
//         wap_wait_trigger_en_toggle = 1'b0;
//         wap_thresh_set             = 1'b0;
//         wap_intr_en_toggle         = 1'b0;
//         wap_thresh_wrap_toggle     = 1'b0;
//         wdp_wait_trigger_en_toggle = 1'b0;
//         wdp_thresh_set             = 1'b0;
//         wdp_intr_en_toggle         = 1'b0;
//         wdp_thresh_wrap_toggle     = 1'b0;
//         wrp_wait_trigger_en_toggle = 1'b0;
//         wrp_thresh_set             = 1'b0;
//         wrp_intr_en_toggle         = 1'b0;
//         wrp_thresh_wrap_toggle     = 1'b0;
//       end
//     end // WRITE_STATS_REG
//     else begin: WRITE_STATS_SIM
//       assign IP_WrEn_mod   = 4'h0;
//       assign IP_Addr_mod   = 4'h0;
//       assign IP_WrData_mod = 32'h00000000;

//       always@(*) begin
//         wap_wait_trigger_en_toggle = !wap_counter_enabled;
//         wap_thresh_set             = 1'b1;
//         wap_intr_en_toggle         = wap_intr_enabled;
//         wap_thresh_wrap_toggle     = wap_thresh_wrap_enabled;
//         wdp_wait_trigger_en_toggle = !wdp_counter_enabled;
//         wdp_thresh_set             = 1'b1;
//         wdp_intr_en_toggle         = wdp_intr_enabled;
//         wdp_thresh_wrap_toggle     = wdp_thresh_wrap_enabled;
//         wrp_wait_trigger_en_toggle = !wrp_counter_enabled;
//         wrp_thresh_set             = 1'b1;
//         wrp_intr_en_toggle         = wrp_intr_enabled;
//         wrp_thresh_wrap_toggle     = wrp_thresh_wrap_enabled;
//       end
//     end // WRITE_STATS_SIM

     // NOTE: NUM_STATS is hardcoded to 3. IP_Addr width is dependent on NUM_STATS,
     //       so if new stats are desired, adjust wire widths appropriately
//     IP_stats_tracker #(
//       .NUM_STATS  (3),
//       .BUS_ENABLE (ENABLE_STATISTICS_REG),
//       .REG_STAGE  (0)
//     ) i_wr_stats (
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
//       .trigger            ({wap_wait_trigger,          wdp_wait_trigger,          wrp_wait_trigger}),
//       .trigger_en_toggle  ({wap_wait_trigger_en_toggle,wdp_wait_trigger_en_toggle,wrp_wait_trigger_en_toggle}),
//       .counter_enabled    ({wap_counter_enabled,       wdp_counter_enabled,       wrp_counter_enabled}),
//       .counter_reset      ({wap_reset,                 wdp_reset,                 wrp_reset}),
//       .event_thresh       ({wap_thresh,                wdp_thresh,                wrp_thresh}),
//       .event_thresh_set   ({wap_thresh_set,            wdp_thresh_set,            wrp_thresh_set}),
//       .event_count        ({wap_wait_count,            wdp_wait_count,            wrp_wait_count}),
//       .intr_en_toggle     ({wap_intr_en_toggle,        wdp_intr_en_toggle,        wrp_intr_en_toggle}),
//       .intr_enabled       ({wap_intr_enabled,          wdp_intr_enabled,          wrp_intr_enabled}),
//       .thresh_interrupt   ({wap_thresh_intr,           wdp_thresh_intr,           wrp_thresh_intr}),
//       .thresh_wrap_toggle ({wap_thresh_wrap_toggle,    wdp_thresh_wrap_toggle,    wrp_thresh_wrap_toggle}),
//       .thresh_wrap_enabled({wap_thresh_wrap_enabled,   wdp_thresh_wrap_enabled,   wrp_thresh_wrap_enabled})
//     );
//   end // WRITE_STATS
//   else begin: NO_STATS
     assign IP_RdData       = 64'h0;
     assign wap_thresh_intr = 1'b0;
     assign wdp_thresh_intr = 1'b0;
     assign wrp_thresh_intr = 1'b0;
//   end // NO_STATS
// endgenerate

 ////////////////////////////////////////
 // Write State Machine
 //
 wire wbeat_complete = bus_wlast & bus_wready & bus_wvalid;
 generate
   if (ENFORCE_4K_BOUND == "TRUE") begin: CHECKPOINT_4K
     reg first_req_not_made;
     always@(posedge clock or negedge reset_n)
       if (!reset_n)
         first_req_not_made <= 1'b1;
       else if ((c_state_wap == WRITE_ADDR_IDLE) & sys_write_req)
         first_req_not_made <= 1'b1;
       else if ((c_state_wap == WRITE_ADDR_REQ) & bus_awvalid & bus_awready)
         first_req_not_made <= 1'b0;
       else
         first_req_not_made <= first_req_not_made;

     always@(posedge clock or negedge reset_n)
       if (!reset_n)
         checkpoint <= 9'h000;
       else if (((c_state_wap == WRITE_ADDR_REQ) & bus_awvalid & bus_awready & first_req_not_made) |
           wbeat_complete |
           (c_state_wdp == WRITE_DATA_IDLE))
         checkpoint <= write_max_burst_length;
       // Prevents AXI protocol violation when checkpoint == 1 and needs to change to something != 1 -- coltons
       else if ((checkpoint == 1) & (c_state_wap == WRITE_ADDR_REQ) & bus_awvalid & first_req_not_made)
         checkpoint <= 9'h000;
       else
         checkpoint <= checkpoint;

   end // CHECKPOINT_4K
   else begin: CHECKPOINT_DEFAULT
     always@(*) checkpoint = write_max_burst_length;
   end // CHECKPOINT_DEFAULT
 endgenerate

 assign bus_wlast = ((WBurstWordCount+8'h1) == checkpoint) |
                    (WRemainingBurstDataByteCount <= 4*BUS_MULTIPLIER);

 wire wap_idle = (c_state_wap == WRITE_ADDR_IDLE);
 wire wdp_idle = (c_state_wdp == WRITE_DATA_IDLE);
 wire wrp_idle = (MAX_ACTIVE_REQS == 1) ? ((c_state_wrp == WRITE_RESP_IDLE) |
                                          ((c_state_wrp == WRITE_RESP_WAIT) & last_resp_active)) :
                                          1'b1;
 assign sys_write_master_ready = wap_idle &
                                 wdp_idle &
                                 wrp_idle;



 always@(posedge clock or negedge reset_n)
  if (!reset_n)
   c_state_wdp <= WRITE_DATA_IDLE;
  else
   c_state_wdp <= n_state_wdp;

 always@(posedge clock or negedge reset_n)
  if (!reset_n)
   c_state_wap <= WRITE_ADDR_IDLE;
  else
   c_state_wap <= n_state_wap;

 always@(posedge clock or negedge reset_n)
  if (!reset_n)
   c_state_wrp <= WRITE_ADDR_IDLE;
  else
   c_state_wrp <= n_state_wrp;

  /*-- Addr Pipe calculates the address cycle after this wire changes, so we store it --*/
  always @(posedge clock or negedge reset_n)
   if(!reset_n)
     cur_write_burst_length_d <= 9'b0;
   else
     cur_write_burst_length_d <= cur_write_burst_length;



  /*-- Keep track of read requests --*/
  always@(posedge clock or negedge reset_n)
   if(!reset_n)
     WRemainingBurstReqByteCount <=  'h0;
   else if ((c_state_wap == WRITE_ADDR_IDLE) & sys_write_req)
     WRemainingBurstReqByteCount <=  sys_write_burst_size*4*BUS_MULTIPLIER +
                                     (((ALLOW_BYTE_ACCESS == "TRUE") && |sys_write_byte_size) ?
                                      4*BUS_MULTIPLIER : 'h0); // Round WRemainingBurstReqByteCount up to next
                                                               // multiple of 4*BUS_MULTIPLIER to save on timing
                                                               // in paths that use cur_write_burst_length.
                                                               // This is necessary when ALLOW_BYTE_ACCESS is
                                                               // true and more logic would otherwise be needed
                                                               // to calculate cur_write_burst_length.
                                                               // This should have no effect on current uses
                                                               // of WRemainingBurstReqByteCount. -calebw
   else if ((c_state_wap == WRITE_ADDR_REQ) & bus_awready)
     WRemainingBurstReqByteCount <= (WRemainingBurstReqByteCount >= ({8'h00,cur_write_burst_length}<<WriteBurstSize_r)) ?
                                    WRemainingBurstReqByteCount - ({8'h00,cur_write_burst_length}<<WriteBurstSize_r) :
                                    'h0;
   else
     WRemainingBurstReqByteCount <=  WRemainingBurstReqByteCount;

   generate
     if (MAX_ACTIVE_REQS == 1) begin
       always@(posedge clock or negedge reset_n)
        if(!reset_n)
         OutstandingWriteReq <= 8'h0;
        else case ({(bus_awvalid&bus_awready),(bus_bvalid&bus_bready)})
          2'b00: OutstandingWriteReq <= OutstandingWriteReq;
          2'b01: OutstandingWriteReq <= OutstandingWriteReq - 8'h1;
          2'b10: OutstandingWriteReq <= OutstandingWriteReq + 8'h1;
          2'b11: OutstandingWriteReq <= OutstandingWriteReq;
         endcase
     end else begin
       always@(*) OutstandingWriteReq = 8'h0;
     end
   endgenerate

  /*-- Keep track of read data received --*/
  always@(posedge clock or negedge reset_n)
   if(!reset_n)
     WRemainingBurstDataByteCount <= 'h0;
   else if ((c_state_wdp == WRITE_DATA_IDLE) & sys_write_req)
     WRemainingBurstDataByteCount <=  sys_write_burst_size*4*BUS_MULTIPLIER +
                                      ((ALLOW_BYTE_ACCESS == "TRUE") ? sys_write_byte_size : 'h0);
   else if ((c_state_wdp == WRITE_DATA_WAIT) & bus_wready & bus_wvalid)
     WRemainingBurstDataByteCount <= (WRemainingBurstDataByteCount >= 4*BUS_MULTIPLIER) ?
                                     (WRemainingBurstDataByteCount - 4*BUS_MULTIPLIER) :
                                     'h0;
   else
     WRemainingBurstDataByteCount <=  WRemainingBurstDataByteCount;

   always@(posedge clock or negedge reset_n)
    if(!reset_n)
     WBurstWordCount <= 8'h0;
    else if (wbeat_complete)
     WBurstWordCount <= 8'h0;
    else if ((c_state_wdp == WRITE_DATA_WAIT) & bus_wready & bus_wvalid)
     WBurstWordCount <= WBurstWordCount + 8'h1;
    else
     WBurstWordCount <= WBurstWordCount;

 wire [2:0] awsize_wire = (BUS_MULTIPLIER ==  1) ? 3'b010 : //  4-bytes in transfer
                          (BUS_MULTIPLIER ==  2) ? 3'b011 : //  8-bytes in transfer
                          (BUS_MULTIPLIER ==  4) ? 3'b100 : // 16-bytes in transfer
                          (BUS_MULTIPLIER ==  8) ? 3'b101 : // 32-bytes in transfer
                          (BUS_MULTIPLIER == 16) ? 3'b110 : // 64-bytes in transfer
                          (BUS_MULTIPLIER == 32) ? 3'b111 : //128-bytes in transfer
                                                   3'b000;  //  1-byte  in transfer

wire [ADDR_WIDTH-1:0] sys_write_addr_aligned = {sys_write_addr[ADDR_WIDTH-1:clogb2(4*BUS_MULTIPLIER)],
                                                {(clogb2(4*BUS_MULTIPLIER)){1'b0}}};
wire [ADDR_WIDTH-1:0] IncrWriteSysAddr = (WriteBurstType_r == BURST_FIXED) ?
                                         WriteSysAddr_r :
                                         (WriteSysAddr_r + ({8'h00,cur_write_burst_length_d}<<WriteBurstSize_r));

   /*-- Begin Write Address Pipe --*/
    always@(posedge clock or negedge reset_n)
     if(!reset_n) begin
       WriteSysAddr_r    <= 32'h0;
       WriteBurstType_r  <=  2'b0;
       WriteCacheType_r  <=  4'b0;
       WriteBurstSize_r  <=  3'b0;
       WriteID_r         <= {clogb2(NUM_IDS){1'b0}};
     end
     else if ((c_state_wap == WRITE_ADDR_IDLE) & sys_write_req) begin
       WriteSysAddr_r    <= sys_write_keyhole_addr ?
                            sys_write_addr :
                            sys_write_addr_aligned;
       WriteBurstType_r  <= sys_write_keyhole_addr ? BURST_FIXED : BURST_INCR;
       WriteCacheType_r  <=  (ALLOW_AWCACHE_CTL == "TRUE") ? sys_write_modifiable : 4'b0; // <- Default as non-cacheable.
       WriteBurstSize_r  <=  awsize_wire;
       WriteID_r         <= sys_write_req_id;
     end
     else if (c_state_wap == WRITE_ADDR_CALC_REQ) begin
       WriteSysAddr_r    <= IncrWriteSysAddr;
       WriteBurstType_r  <= WriteBurstType_r;
       WriteCacheType_r  <= WriteCacheType_r;
       WriteBurstSize_r  <=  awsize_wire;
       WriteID_r         <= WriteID_r;
     end
     else begin
       WriteSysAddr_r    <= WriteSysAddr_r;
       WriteBurstType_r  <= WriteBurstType_r;
       WriteCacheType_r  <= WriteCacheType_r;
       WriteBurstSize_r  <= WriteBurstSize_r;
       WriteID_r         <= WriteID_r;
     end

    always@(*)
     case(c_state_wap)
      WRITE_ADDR_IDLE: begin
       bus_awvalid = 1'b0;
       bus_awaddr  = WriteSysAddr_r;
       bus_awburst = WriteBurstType_r;
       bus_awcache = WriteCacheType_r;
       bus_awlen   = 8'h0;
       bus_awprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
       bus_awsize  = WriteBurstSize_r;
       bus_awuser  = 12'h0;
       bus_awid    = {clogb2(NUM_IDS){1'b0}};
      end
      WRITE_ADDR_REQ: begin
       bus_awvalid = 1'b1;
       bus_awaddr  = WriteSysAddr_r;
       bus_awburst = WriteBurstType_r;
       bus_awcache = WriteCacheType_r;
       bus_awlen   = cur_write_burst_length-8'h1;
       bus_awprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
       bus_awsize  = WriteBurstSize_r;
       bus_awuser  = cur_write_burst_length*4*BUS_MULTIPLIER; // This will need to change to support
                                                              // non-bus-width-bursts in the future -EH
       bus_awid    = WriteID_r;
      end
      WRITE_ADDR_CALC_REQ: begin
       bus_awvalid = 1'b0;
       bus_awaddr  = WriteSysAddr_r;
       bus_awburst = WriteBurstType_r;
       bus_awcache = WriteCacheType_r;
       bus_awlen   = 8'h0;
       bus_awprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
       bus_awsize  = WriteBurstSize_r;
       bus_awuser  = 12'h0;
       bus_awid    = {clogb2(NUM_IDS){1'b0}};
      end
      default: begin
       bus_awvalid = 1'b0;
       bus_awaddr  = WriteSysAddr_r;
       bus_awburst = WriteBurstType_r;
       bus_awcache = WriteCacheType_r;
       bus_awlen   = 8'h0;
       bus_awprot  = 3'h0; // Check protocol (secure, unprivaleged, data) (??)
       bus_awsize  = WriteBurstSize_r;
       bus_awuser  = 12'h0;
       bus_awid    = {clogb2(NUM_IDS){1'b0}};
      end
     endcase

    always@(*)
     case(c_state_wap)
       WRITE_ADDR_IDLE:
        if(sys_write_req)
          n_state_wap = WRITE_ADDR_REQ;
        else
          n_state_wap = WRITE_ADDR_IDLE;
       WRITE_ADDR_REQ:
        if(bus_awready & (WRemainingBurstReqByteCount <= (cur_write_burst_length*4*BUS_MULTIPLIER))) // instead, we
                                                      // may want to bit shift by WriteBurstSize_r -calebw
          n_state_wap = WRITE_ADDR_IDLE;
        else if (bus_awready)
          n_state_wap = WRITE_ADDR_CALC_REQ;
        else
          n_state_wap = WRITE_ADDR_REQ;
       WRITE_ADDR_CALC_REQ:
          n_state_wap = WRITE_ADDR_REQ;
      default:
       n_state_wap = c_state_wap;
     endcase


    always@(posedge clock or negedge reset_n)
     if(!reset_n)
       WriteSteadyByteEn_r <= {BUS_MULTIPLIER{4'h0}};
     else if (sys_write_req)
       WriteSteadyByteEn_r <= sys_byte_enable;
     else
       WriteSteadyByteEn_r <= WriteSteadyByteEn_r;

  generate
  if (BYTE_EN_PASSTHROUGH == "TRUE") begin
    always@(*)
      bus_wstrb = sys_byte_enable;
  end
  else begin
    always@(posedge clock or negedge reset_n)
      if(!reset_n)
         bus_wstrb <= {BUS_MULTIPLIER{4'b0}};
      else case(c_state_wdp)
        WRITE_DATA_IDLE:
         bus_wstrb <= {BUS_MULTIPLIER{4'b0}};
        WRITE_DATA_WAIT:
         if(wbeat_complete)
           bus_wstrb  <= {BUS_MULTIPLIER{4'b0}};
         else
           bus_wstrb  <= WriteSteadyByteEn_r; // Logic will need to be added here to start the byte enable at sys_byte_enable, then modify this value for the middle, and ending byte enables as needed
        default:
         bus_wstrb <= {BUS_MULTIPLIER{4'b0}};
      endcase
  end
  endgenerate

   /*-- Begin Write Data Pipe --*/
    always@(posedge clock or negedge reset_n)
     if(!reset_n) begin
        bus_wvalid <= 1'b0;
     end
     else case(c_state_wdp)
       WRITE_DATA_IDLE: begin
        bus_wvalid <= 1'b0;
       end
       WRITE_DATA_WAIT:
        if(wbeat_complete) begin
          bus_wvalid <= 1'b0;
        end
        else begin
          bus_wvalid <= ((ALLOW_DATA_PAUSING == "TRUE") & (WRemainingBurstDataByteCount > (4*BUS_MULTIPLIER))) ?
                        (!sys_fifo_empty & !sys_fifo_warn) :
                        (!sys_fifo_empty);
        end
       default: begin
        bus_wvalid <= 1'b0;
       end
      endcase



     assign bus_wdata = sys_write_data;

    assign sys_fifo_read = !sys_fifo_empty & (bus_wvalid & bus_wready);


    always@(*)
     case(c_state_wdp)
      WRITE_DATA_IDLE:
       if(sys_write_req)
        n_state_wdp = WRITE_DATA_WAIT;
       else
        n_state_wdp = WRITE_DATA_IDLE;
      WRITE_DATA_WAIT:
       if(wbeat_complete)
        n_state_wdp = WRITE_DATA_CALC_BURST;
       else
        n_state_wdp = WRITE_DATA_WAIT;
      WRITE_DATA_CALC_BURST:
       if(|WRemainingBurstDataByteCount)
        n_state_wdp = WRITE_DATA_WAIT;
       else
        n_state_wdp = WRITE_DATA_IDLE;
      default:
       n_state_wdp = c_state_wdp;
     endcase

   /*-- Begin Write Response Pipe --*/
   generate
     if (MAX_ACTIVE_REQS == 1) begin
       always@(posedge clock or negedge reset_n)
        if(!reset_n)  begin
         bus_bready <= 1'b0;
        end
        else case(c_state_wrp)
          WRITE_RESP_IDLE: begin
           bus_bready <= 1'b0;
          end
          WRITE_RESP_WAIT: begin
           bus_bready <= 1'b1;
          end
          default: begin
           bus_bready <= 1'b0;
          end
        endcase
     end else begin
       always@(*) bus_bready = sys_write_resp_ready;
     end
   endgenerate

    assign sys_write_resp_valid = bus_bvalid;
    assign sys_write_resp       = bus_bresp;
    assign sys_write_resp_id    = bus_bid;

  generate
   if (ALLOW_ERR_INTR == "TRUE") begin: WRITE_ERR_DETECT

    reg WriteErrOccurrence_r;

    assign sys_write_err = WriteErrOccurrence_r;

    always@(posedge clock or negedge reset_n)
     if(!reset_n) begin
       WriteErrOccurrence_r <= 1'b0;
     end else if (((c_state_wrp == WRITE_RESP_WAIT)|(MAX_ACTIVE_REQS > 1)) & bus_bvalid & bus_bready & (bus_bresp != RESP_OKAY)) begin
       WriteErrOccurrence_r <= 1'b1;
     end else begin
       WriteErrOccurrence_r <= WriteErrOccurrence_r;
     end

   end // WRITE_ERR_DETECT
   else begin: NO_WRITE_ERR_DETECT
     assign sys_write_err = 1'b0;
   end // NO_WRITE_ERR_DETECT
  endgenerate

assign last_resp_active = (OutstandingWriteReq == 1) & (bus_bready & bus_bvalid) & !(bus_awready & bus_awvalid);

    always@(*)
     case(c_state_wrp)
      WRITE_RESP_IDLE:
       if(bus_awvalid&bus_awready & (MAX_ACTIVE_REQS == 1))
        n_state_wrp = WRITE_RESP_WAIT;
       else
        n_state_wrp = WRITE_RESP_IDLE;
      WRITE_RESP_WAIT:
       if(last_resp_active)
        n_state_wrp = WRITE_RESP_IDLE;
       else
        n_state_wrp = WRITE_RESP_WAIT;
      default:
       n_state_wrp = c_state_wrp;
     endcase

   /*-- Begin Write Response Pipe --*/

`include "ip_functions.vh"

endmodule
`endif //IP_axi_master_write




