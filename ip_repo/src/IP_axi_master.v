`timescale 1ns/1ps

`ifndef IP_axi_master
 `define IP_axi_master

  // INTERNAL FILE
  // SECURE_PLACEHOLDER_CONFIG
  // SECURE_PLACEHOLDER_NETLIST


module IP_axi_master #(
   parameter BUS_MULTIPLIER        = 1,
   // Allows bus_wvalid to deassert mid-burst if set to "TRUE"
   parameter ALLOW_DATA_PAUSING    = "FALSE",
   // Allows bus_rready to deassert mid-burst if set to "TRUE"
   parameter ALLOW_RD_DATA_PAUSING = "FALSE",
   // Determines whether sys_write_byte_size is used in bytes-remaining calculations
   parameter ALLOW_BYTE_ACCESS     = "FALSE",
   // Allows sys_byte_enable to directly drive bus_wstrb, without a reg stage -calebw
   parameter BYTE_EN_PASSTHROUGH   = "FALSE",
   // Allows outputs sys_read_err and sys_write_err to be driven on detection of RRESP/BRESP != RESP_OKAY
   parameter ALLOW_ERR_INTR        = "FALSE",
   // If a R/W request on the sys_bus will cross a 4K address boundary, this allows the module
   // to break the transfer into several smaller transfers straddling the boundary.
   // The theory here is: crossing a 4K boundary is illegal in AXI. If this parameter is set to "TRUE",
   // the AXI Master will enforce the boundary. If set to "FALSE", the user is responsible for enforcing it.
   parameter ENFORCE_4K_BOUND      = "FALSE",
   // bus_awcache will be calculated from sys_write_modifiable if "TRUE", otherwise 0
   parameter ALLOW_AWCACHE_CTL     = "FALSE",
   // bus_arcache will be calculated from sys_read_modifiable if "TRUE", otherwise 0
   parameter ALLOW_ARCACHE_CTL     = "FALSE",
   // Specify whether or not multiple outstanding requests is supported. If > 1,
   // sys_write_master_ready will only deassert during write requests, instead of waiting
   // for bresp to arrive. In this case, the application layer is expected to consume bresp.
   // If > 1, sys_read_master_ready will only deassert during read requests, instead of
   // waiting for (rlast & rready & rvalid). In this case, the application layer is
   // expected to consume all read data as it becomes available (potentially out of
   // order), and to limit the number of read requests as specified by MAX_ACTIVE_REQS.
   //  --calebw
   parameter MAX_ACTIVE_REQS       = 1,
   parameter MAX_BURST_REQ_SIZE    = 32768,
   // Max number of AXI ID values supported
   parameter NUM_IDS               = 1,
   parameter ADDR_WIDTH            = 64,

   // Instantiates the Statistics counter to track Write/Read Channel behavior
   parameter ENABLE_STATISTICS     = 0,
   // By default, statistics will be sim-only. If "TRUE", enables a register interface
   parameter ENABLE_STATISTICS_REG = 1
 )
 (
    input clock,
    input reset_n,

    /*-- Read Address Channel --*/
    output                           bus_arvalid,
    input                            bus_arready,
    output [ADDR_WIDTH-1:0]          bus_araddr,
    output [1:0]                     bus_arburst,
    output [3:0]                     bus_arcache,
    output [7:0]                     bus_arlen,
    output [2:0]                     bus_arprot,
    output [2:0]                     bus_arsize,
    output [11:0]                    bus_aruser,
    output                             bus_arid,

    /*-- Read Data Channel --*/
    input                            bus_rvalid,
    input  [32*BUS_MULTIPLIER-1:0]   bus_rdata,
    input                            bus_rlast,
    input  [1:0]                     bus_rresp,
    input                            bus_rid,
    output                           bus_rready,


    /*-- Write Address Channel --*/
    input                            bus_awready,
    output                           bus_awvalid,
    output [ADDR_WIDTH-1:0]          bus_awaddr,
    output [1:0]                     bus_awburst,
    output [3:0]                     bus_awcache,
    output [7:0]                     bus_awlen,
    output [2:0]                     bus_awprot,
    output [2:0]                     bus_awsize,
    output [11:0]                    bus_awuser,
    output                             bus_awid,

    /*-- Write Data Channel --*/
    input                            bus_wready,
    output                           bus_wvalid,
    output                           bus_wlast,
    output [32*BUS_MULTIPLIER-1:0]   bus_wdata,
    output [ 4*BUS_MULTIPLIER-1:0]   bus_wstrb,

    /*-- Write Response Channel --*/
    input                            bus_bvalid,
    input  [1:0]                     bus_bresp,
    output                           bus_bready,
    input                           bus_bid,

    /*-- System Read Control Signals--*/
    input                                      sys_read_keyhole_addr,
    input  [15:0]  sys_read_burst_size,
    input  [ADDR_WIDTH-1:0]                    sys_read_addr,
    input                                      sys_read_req,
    input                                       sys_read_req_id,
    input  [3:0]                               sys_read_modifiable,
    output [32*BUS_MULTIPLIER-1:0]             sys_read_data,
    output                                     sys_read_data_valid,
    output                                     sys_read_data_last,
    input                                      sys_read_throttle,
    output                                     sys_read_master_ready,
    output                                     sys_read_resp_id,
    output [1:0]                               sys_read_resp,
    output                                     sys_read_err,


    /*-- System Write Control Signals--*/
    input                                      sys_write_keyhole_addr,
    input                                      sys_write_req,
    input                                    sys_write_req_id,
    input  [15:0]  sys_write_burst_size, // bus words.
    input  [3:0]      sys_write_byte_size,
    input  [ADDR_WIDTH-1:0]                    sys_write_addr,
    input  [32*BUS_MULTIPLIER-1:0]             sys_write_data,
    input  [ 4*BUS_MULTIPLIER-1:0]             sys_byte_enable,
    input  [3:0]                               sys_write_modifiable,
    output                                     sys_write_master_ready,
    input                                      sys_write_resp_ready,
    output                                     sys_write_resp_valid,
    output [1:0]                               sys_write_resp,
    output                                     sys_write_resp_id,
    output                                     sys_write_err,

    /*-- Fifo I/F signals --*/
    output                                sys_fifo_read,
    input                                 sys_fifo_warn,
    input                                 sys_fifo_empty,

    /*-- Statistics I/F --*/
    output wire [63:0]                        IP_RdData_rd,
    input  wire [3:0]                         IP_WrEn_rd,
    input  wire [3:0]                         IP_Addr_rd,
    input  wire [31:0]                        IP_WrData_rd,
    output wire                               rap_thresh_intr,
    output wire                               rdp_thresh_intr,

    output wire [63:0]                        IP_RdData_wr,
    input  wire [3:0]                         IP_WrEn_wr,
    input  wire [3:0]                         IP_Addr_wr,
    input  wire [31:0]                        IP_WrData_wr,
    output wire                               wap_thresh_intr,
    output wire                               wdp_thresh_intr,
    output wire                               wrp_thresh_intr,

    output [4:0]                          c_state_wap,
    output [4:0]                          c_state_wdp,
    output [4:0]                          c_state_rap,
    output [4:0]                          c_state_rdp

 );


  IP_axi_master_write #(
    .BUS_MULTIPLIER       (BUS_MULTIPLIER),
    .ADDR_WIDTH           (ADDR_WIDTH),
    .ALLOW_DATA_PAUSING   (ALLOW_DATA_PAUSING),
    .ALLOW_BYTE_ACCESS    (ALLOW_BYTE_ACCESS),
    .ALLOW_ERR_INTR       (ALLOW_ERR_INTR),
    .ENFORCE_4K_BOUND     (ENFORCE_4K_BOUND),
    .BYTE_EN_PASSTHROUGH  (BYTE_EN_PASSTHROUGH),
    .MAX_ACTIVE_REQS      (MAX_ACTIVE_REQS),
    .MAX_BURST_REQ_SIZE   (MAX_BURST_REQ_SIZE),
    .ALLOW_AWCACHE_CTL    (ALLOW_AWCACHE_CTL),
    .NUM_IDS              (NUM_IDS),
    .ENABLE_STATISTICS    (ENABLE_STATISTICS),
    .ENABLE_STATISTICS_REG(ENABLE_STATISTICS_REG)
  ) i_wr_channel (
    .clock                          (clock),
    .reset_n                        (reset_n),
    .sys_fifo_empty                 (sys_fifo_empty),
    .sys_fifo_warn                  (sys_fifo_warn),
    .sys_write_data                 (sys_write_data),
    .sys_fifo_read                  (sys_fifo_read),
    .sys_byte_enable                (sys_byte_enable),
    /*-- Register Control Port --*/
    .sys_write_addr                 (sys_write_addr),
    .sys_write_keyhole_addr         (sys_write_keyhole_addr),
    .sys_write_modifiable           (sys_write_modifiable),
    .sys_write_burst_size           (sys_write_burst_size),
    .sys_write_byte_size            (sys_write_byte_size),
    .sys_write_req                  (sys_write_req),
    .sys_write_req_id               (sys_write_req_id),
    .sys_write_master_ready         (sys_write_master_ready),
    .sys_write_resp_ready           (sys_write_resp_ready),
    .sys_write_resp_valid           (sys_write_resp_valid),
    .sys_write_resp                 (sys_write_resp),
    .sys_write_resp_id              (sys_write_resp_id),
    .sys_write_err                  (sys_write_err),
    /*-- Write Address Channel --*/
    .bus_awready                    (bus_awready),
    .bus_awvalid                    (bus_awvalid),
    .bus_awaddr                     (bus_awaddr),
    .bus_awburst                    (bus_awburst),
    .bus_awcache                    (bus_awcache),
    .bus_awlen                      (bus_awlen),
    .bus_awprot                     (bus_awprot),
    .bus_awsize                     (bus_awsize),
    .bus_awuser                     (bus_awuser),
    .bus_awid                       (bus_awid),
    /*-- Write Data Channel --*/
    .bus_wready                     (bus_wready),
    .bus_wvalid                     (bus_wvalid),
    .bus_wlast                      (bus_wlast),
    .bus_wdata                      (bus_wdata),
    .bus_wstrb                      (bus_wstrb),
    /*-- Write Response Channel --*/
    .bus_bvalid                     (bus_bvalid),
    .bus_bresp                      (bus_bresp),
    .bus_bready                     (bus_bready),
    .bus_bid                        (bus_bid),
    /*-- Statistics I/F --*/
    .IP_RdData                      (IP_RdData_wr),
    .IP_WrEn                        (IP_WrEn_wr),
    .IP_Addr                        (IP_Addr_wr),
    .IP_WrData                      (IP_WrData_wr),
    .wap_thresh_intr                (wap_thresh_intr),
    .wdp_thresh_intr                (wdp_thresh_intr),
    .wrp_thresh_intr                (wrp_thresh_intr),

    .c_state_wap                    (c_state_wap),
    .c_state_wdp                    (c_state_wdp)

  );

  IP_axi_master_read #(
    .BUS_MULTIPLIER       (BUS_MULTIPLIER),
    .ADDR_WIDTH           (ADDR_WIDTH),
    .ALLOW_RD_DATA_PAUSING(ALLOW_RD_DATA_PAUSING),
    .ALLOW_ERR_INTR       (ALLOW_ERR_INTR),
    .ENFORCE_4K_BOUND     (ENFORCE_4K_BOUND),
    .MAX_BURST_REQ_SIZE   (MAX_BURST_REQ_SIZE),
    .MAX_ACTIVE_REQS      (MAX_ACTIVE_REQS),
    .ALLOW_ARCACHE_CTL    (ALLOW_ARCACHE_CTL),
    .NUM_IDS              (NUM_IDS),
    .ENABLE_STATISTICS    (ENABLE_STATISTICS),
    .ENABLE_STATISTICS_REG(ENABLE_STATISTICS_REG)
  ) i_rd_channel (
    .clock                        (clock),
    .reset_n                      (reset_n),
    .sys_read_throttle            (sys_read_throttle),
    .sys_read_data                (sys_read_data),
    .sys_read_data_valid          (sys_read_data_valid),
    .sys_read_resp                (sys_read_resp),
    .sys_read_resp_id             (sys_read_resp_id),
    .sys_read_data_last           (sys_read_data_last),
    .sys_read_addr                (sys_read_addr),
    .sys_read_keyhole_addr        (sys_read_keyhole_addr),
    .sys_read_modifiable          (sys_read_modifiable),
    .sys_read_burst_size          (sys_read_burst_size),
    .sys_read_req                 (sys_read_req),
    .sys_read_req_id              (sys_read_req_id),
    .sys_read_master_ready        (sys_read_master_ready),
    .sys_read_err                 (sys_read_err),
    /*-- Read Address Channel --*/
    .bus_arvalid                  (bus_arvalid),
    .bus_arready                  (bus_arready),
    .bus_araddr                   (bus_araddr),
    .bus_arburst                  (bus_arburst),
    .bus_arcache                  (bus_arcache),
    .bus_arlen                    (bus_arlen),
    .bus_arprot                   (bus_arprot),
    .bus_arsize                   (bus_arsize),
    .bus_aruser                   (bus_aruser),
    .bus_arid                     (bus_arid),
    /*-- Read Data Channel --*/
    .bus_rvalid                   (bus_rvalid),
    .bus_rdata                    (bus_rdata),
    .bus_rlast                    (bus_rlast),
    .bus_rresp                    (bus_rresp),
    .bus_rid                      (bus_rid),
    .bus_rready                   (bus_rready),
    /*-- Statistics I/F --*/
    .IP_RdData                      (IP_RdData_rd),
    .IP_WrEn                        (IP_WrEn_rd),
    .IP_Addr                        (IP_Addr_rd),
    .IP_WrData                      (IP_WrData_rd),
    .rap_thresh_intr                (rap_thresh_intr),
    .rdp_thresh_intr                (rdp_thresh_intr),

    .c_state_rap                  (c_state_rap),
    .c_state_rdp                  (c_state_rdp)

  );

`include "ip_functions.vh"
endmodule
`endif //IP_axi_master




