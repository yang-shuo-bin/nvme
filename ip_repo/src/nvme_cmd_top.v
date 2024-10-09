module nvme_cmd_top #( 
    parameter  BASE_ADDR_XDMA = 64'h4_0000_0000 ,
    parameter  BASE_ADDR_BRAM = 32'ha010_0000 ,
    parameter  BASE_ADDR_BAR = 32'ha000_0000 ,
    parameter  PRPLIST_HEAP = 64'ha012_0000 ,
    parameter  ADDR_WIDTH = 32'd64 ,
    parameter  DATA_WIDTH = 32'd128 ,
    parameter  BLOCK_SIZE_EXP = 20 , //MDTS+12
    parameter ASQ_ADDR = 32'ha010_0000 ,
    parameter ACQ_ADDR = 32'ha010_1000 ,
    parameter IO_SIZE = 16'h003f ,
    parameter IOSQ_ADDR = 32'ha010_2000 ,
    parameter IOCQ_ADDR = 32'ha010_3000 ,
    parameter idController_ADDR = 32'ha010_4000 ,
    parameter idNamespace_ADDR = 32'ha010_5000
) (  
    input clk_in ,
    input resetb ,

    input link_up , //xdma link up 
    input init_start ,  //init xdma start
    output init_finish , //init xdma and nvme finish 

    input write_in_start ,//start write data
    output write_in_start_ack ,
  
    input write_done_ack ,
    output write_done ,

    input read_in_start , //start read data
    output read_in_start_ack ,
    
    input data_transfer_ready ,
    input [63:0]prp1_addr ,
    input [63:0]destLBA_in ,
    input [63:0]bytesToRead_or_Write ,
    
    input read_done_ack ,
    output read_done ,

        /*-- Read Address Channel --*/
    output                           bus_arvalid,
    input                            bus_arready,
    output [63:0]                    bus_araddr,
    output [1:0]                     bus_arburst,
    output [3:0]                     bus_arcache,
    output [7:0]                     bus_arlen,
    output [2:0]                     bus_arprot,
    output [2:0]                     bus_arsize,
    output [11:0]                    bus_aruser,
    output                             bus_arid,

    /*-- Read Data Channel --*/
    input                            bus_rvalid,
    input  [31:0]                    bus_rdata,
    input                            bus_rlast,
    input  [1:0]                     bus_rresp,
    input                            bus_rid,
    output                           bus_rready,


    /*-- Write Address Channel --*/
    input                            bus_awready,
    output                           bus_awvalid,
    output [63:0]                    bus_awaddr,
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
    output [31:0]                    bus_wdata,
    output [3:0]                     bus_wstrb,

    /*-- Write Response Channel --*/
    input                            bus_bvalid,
    input  [1:0]                     bus_bresp,
    output                           bus_bready,
    input                           bus_bid,
    
//   //IP DATA TRANSFER
//    // Write ADDR Pipeline
//    output                     s_axi_awready,
//    input                      s_axi_awvalid,
//    input[ADDR_WIDTH-1:0]      s_axi_awaddr,
//    input[7:0]                 s_axi_awlen,
//    input[2:0]                 s_axi_awsize,
//    input[4:0]                 s_axi_awid,

//    //Write DATA Pipe
//    input[(DATA_WIDTH/8)-1:0]  s_axi_wstrb,
//    output                     s_axi_wready,
//    input                      s_axi_wvalid,
//    input                      s_axi_wlast,
//    input[(DATA_WIDTH-1):0]    s_axi_wdata,
//    //Write RESP Pipe
//    output    [1:0]            s_axi_bresp,
//    output                     s_axi_bvalid,
//    input                      s_axi_bready,
//    output[4:0]                s_axi_bid,
//    // Read ADDR Pipeline
//    output                     s_axi_arready,
//    input                      s_axi_arvalid,
//    input[ADDR_WIDTH-1:0]      s_axi_araddr,
//    input[7:0]                 s_axi_arlen,
//    input[2:0]                 s_axi_arsize,
//    input[4:0]                 s_axi_arid,
//    //Read DATA Pipeline
//    input                      s_axi_rready,
//    output                     s_axi_rvalid,
//    output                     s_axi_rlast,
//    output[(DATA_WIDTH-1):0]   s_axi_rdata,
//    output[1:0]                s_axi_rresp,
//    output[4:0]                s_axi_rid,
    //cmd axi interface
    // Write ADDR Pipeline
    output                     cmd_awready,
    input                      cmd_awvalid,
    input[ADDR_WIDTH-1:0]      cmd_awaddr,
    input[7:0]                 cmd_awlen,
    input[2:0]                 cmd_awsize,
    input[4:0]                cmd_awid,

    //Write DATA Pipe
    input[3:0]  cmd_wstrb,
    output                     cmd_wready,
    input                      cmd_wvalid,
    input                      cmd_wlast,
    input[31:0]    cmd_wdata,
    //Write RESP Pipe
    output  [1:0]            cmd_bresp,
    output                     cmd_bvalid,
    input                      cmd_bready,
    output[4:0]             cmd_bid,
    // Read ADDR Pipeline
    output                     cmd_arready,
    input                      cmd_arvalid,
    input[31:0]                cmd_araddr,
    input[7:0]                 cmd_arlen,
    input[2:0]                 cmd_arsize,
    input[4:0]                cmd_arid,
    //Read DATA Pipeline
    input                      cmd_rready,
    output                     cmd_rvalid,
    output                     cmd_rlast,
    output[31:0]               cmd_rdata,
    output[1:0]                cmd_rresp,
    output[4:0]               cmd_rid,
    //prp interface
    // Read ADDR Pipeline
    output                    prp_arready,
    input                      prp_arvalid,
    input[ADDR_WIDTH-1:0]      prp_araddr,
    input[7:0]                 prp_arlen,
    input[2:0]                 prp_arsize,
    input[4:0]    prp_arid,
    //Read DATA Pipeline
    input                      prp_rready,
    output                     prp_rvalid,
    output                     prp_rlast,
    output[63:0]               prp_rdata,
    output[1:0]                prp_rresp,
    output[4:0]   prp_rid,
//    //input steam data
//    input s_axis_tvalid ,
//    output s_axis_tready ,
//    input [DATA_WIDTH-1:0]s_axis_tdata ,
//    //output stream data
//    output m_axis_tvalid ,
//    input m_axis_tready ,
//    output [DATA_WIDTH-1:0]m_axis_tdata ,
    //ssd information
    output [15:0] MaxNumTags ,
    output [3:0] PageSize ,
    output [7:0] MDTS ,
    output  [63:0] NS_SIZE ,
    output  [7:0] BlockSize ,
    output  [31:0] MaxTransferSize ,
    //debug
    output [63:0] speed_cnt ,  
	output [31:0] speed_max ,
	output [31:0] speed_min ,
	output [31:0] speed_cnt_latch ,
	output flag ,
	output [31:0] wait_min ,
	output [31:0] wait_max ,
	output [63:0] block_cnt 
);
//regs
reg is_io_queue ;
//wires
wire write_axi_start ;
wire write_axi_start_ack ;
wire [63:0] reg_out_addr ;
wire [63:0] reg_out_data ;
wire read_axi_start ;
wire read_axi_start_ack ;
wire [63:0] reg_in_data ;
wire sys_write_master_done ;
wire sys_read_master_done ;
wire ap_done ;

wire seq_tail_done ;
wire seq_tail_done_ack ;
wire acq_head_done ;
wire acq_head_done_ack ;
wire [31:0] config_data ;
wire init_busy ;

wire [63:0] numLBA ;
wire iocq_read_start ;
wire NVMERead_out ;
wire NVMEWrite_out ;
wire [63:0] io_create_queue_cnt ;
wire [63:0] io_complete_queue_cnt ;
wire [7:0] max_completion_out ;
wire [63:0] WritedestLBA_out ;
wire [63:0] ReadsrcLBA_out ;
wire iosq_tail_done_ack ;
wire iosq_tail_done ;
wire iocq_head_done_ack ;
wire iocq_head_done ;

wire [63:0] prp_list_head ;

wire [3:0] MPSMIN ;

wire [15:0] admin_create_queue_cnt ;
wire [15:0] admin_complete_queue_cnt ;
wire write_start_check_phase ;
wire write_start_check_phase_ack ;
wire read_start_check_phase ;
wire read_start_check_phase_ack ;
wire [7:0] admin_opc ;
wire [7:0] PSDT_FUSE ;
wire [15:0] cid ;
wire [31:0] nsid_out ;
wire [63:0] MPTR ;
wire [63:0] PRP1 ;
wire [63:0] PRP2 ;
wire [31:0] CDW10 ;
wire [31:0] CDW11 ;
wire [31:0] CDW12 ;
wire [31:0] CDW13 ;
wire [31:0] CDW14 ;
wire [31:0] CDW15 ;

wire [31:0]bram_cmd_addrb_check_phase ;
wire [3:0] bram_cmd_web_check_phase ;
wire [15:0] seq_tail_local ;
wire [15:0] acq_head_local_out ;
wire [15:0] iosq_tail_local ;
wire [15:0] iocq_head_local_out ;

wire sys_write_req ; // axi write register
wire [63:0] sys_write_addr ; 
wire [31:0] sys_write_data ;  
wire sys_write_master_ready ;
    
wire sys_read_req ; // axi read register
wire [63:0] sys_read_addr ; 
wire [31:0] sys_read_data ;
wire sys_read_master_ready ;
wire sys_read_data_valid ;

wire fifo_pop ;
wire [DATA_WIDTH-1:0]data_from_fifo ;
wire fifo_empty ;
wire fifo_underflow ;

wire fifo_full ;
wire [DATA_WIDTH-1:0]data_to_fifo ;
wire fifo_overflow ;
wire fifo_push ;

always @ ( posedge clk_in )
begin
    if ( resetb == 1'b1 )
        is_io_queue <= 1'b0 ;
     else if ( init_finish )
        is_io_queue <= ~ is_io_queue ;
end
// assign bram_cmd_clkb = clk_in ;
// assign bram_cmd_rstb = resetb ;

// assign prp_clkb = clk_in ;
// assign prp_rstb = resetb ;
// assign prp_enb = 1'b1 ;

xdma_init #(
    .BASE_ADDR_XDMA ( BASE_ADDR_XDMA ) ,
    .BASE_ADDR_BRAM ( BASE_ADDR_BRAM ) ,
    .BASE_ADDR_BAR ( BASE_ADDR_BAR ) ,
    .ASQ_ADDR ( ASQ_ADDR ) ,
    .ACQ_ADDR ( ACQ_ADDR )
)xdma_init(
    .aclk ( clk_in ) ,
    .rst ( resetb ) ,
    //link up indicate
    .link_up ( link_up ) ,
    //start init xdma
    .ap_start ( init_start ) ,
    //write xdma registers
    .write_start ( write_axi_start ) ,
    .write_start_ack ( write_axi_start_ack ) ,
    .reg_out_addr ( reg_out_addr ) ,
    .reg_out_data ( reg_out_data ) ,
    //read xdma registers
    .read_start ( read_axi_start ) ,
    .read_start_ack ( read_axi_start_ack ) ,
    .reg_in_data ( reg_in_data ) ,
    //axi ack signals
    .sys_write_master_done ( sys_write_master_done ) ,
    .sys_read_master_done ( sys_read_master_done ) ,
    //xdma init done start init nvme
    .ap_done ( ap_done ) ,
    //ssd information
    .MaxNumTags ( MaxNumTags ) ,
	.PageSize ( PageSize ) 
) ;

nvme_init nvme_init (
    .clk_in ( clk_in ) ,
    .resetb ( resetb ) ,
    //start init nvme
    .init_start ( ap_done ) ,
    //admin cmd signals
    .seq_tail_done_ack ( seq_tail_done_ack ) ,
    .seq_tail_done ( seq_tail_done ) ,
    .cmd_complete ( acq_head_done ) ,
    .cmd_complete_ack ( acq_head_done_ack ) ,
    //control nvme init type
    .config_data ( config_data ) ,
    //init indicate signals
    .init_finish ( init_finish ) ,
    .init_busy ( init_busy ) 
) ;

nvme_read_write_control #( 
    .PRPLIST_HEAP ( PRPLIST_HEAP ) ,
    .BLOCK_SIZE_EXP ( BLOCK_SIZE_EXP ) ,
    .IO_SIZE ( IO_SIZE ) ,
    .DDR_PAGE_SIZE_EXP ( 12 )
) nvme_read_write_control(
    .clk_in ( clk_in ) ,
    .resetb ( resetb ) ,
    //from xdma_init
    .init_busy ( init_busy ) ,
    .numLBA_out ( numLBA ) ,
    .iocq_read_start ( iocq_read_start ) ,
    //read ssd control
    .read_start ( read_in_start ) ,
    .read_start_ack ( read_in_start_ack ) ,
    .destLBA_in ( destLBA_in ) ,
    .ReadsrcLBA_out ( ReadsrcLBA_out ) ,
    .bytesToRead_or_Write ( bytesToRead_or_Write ) ,
    .NVMERead_out ( NVMERead_out ) ,
    .read_done_ack ( read_done_ack ) ,
    .read_done ( read_done ) ,
    //write ssd control
    .write_start ( write_in_start && data_transfer_ready ) ,
    .write_start_ack ( write_in_start_ack ) ,
    .WritedestLBA_out ( WritedestLBA_out ) ,
    .NVMEWrite_out ( NVMEWrite_out ) ,
    .write_done_ack ( write_done_ack ) ,
    .write_done ( write_done ) ,
    //create cmd ids
    .io_create_queue_cnt ( io_create_queue_cnt ) ,
    .io_complete_queue_cnt ( io_complete_queue_cnt ) ,
    .iocq_head_done_ack ( iocq_head_done_ack ) ,
    .iocq_head_done ( iocq_head_done ) ,
    .iosq_tail_done_ack ( iosq_tail_done_ack ) ,
    .iosq_tail_done ( iosq_tail_done ) ,
    //prp control signals
    .prp_list_head ( prp_list_head ) ,
    //debug speed
     .speed_cnt ( speed_cnt ) ,
	 .speed_max ( speed_max ) ,
	 .speed_min ( speed_min ) ,
	 .speed_cnt_latch ( speed_cnt_latch ) ,
	 .flag ( flag ) ,
	 .wait_min ( wait_min ) ,
	 .wait_max ( wait_max ) ,
	 .block_cnt ( block_cnt ) 
) ;

nvme_control # ( 
    .IO_SIZE ( IO_SIZE ) ,
    .IOSQ_ADDR ( IOSQ_ADDR ) ,
    .IOCQ_ADDR ( IOCQ_ADDR ) ,
    .idController_ADDR ( idController_ADDR ) ,
    .idNamespace_ADDR ( idNamespace_ADDR )
) nvme_control (
    .clk_in ( clk_in ) ,
    .resetb ( resetb ) ,
    //from xdma_init
    .nsid_in ( 32'd1 ) ,
    .numLBA ( numLBA ) ,
    .is_io_queue ( is_io_queue ) ,
    .init_finish ( init_finish ) ,
    .config_data ( config_data ) ,
    //read_write_nvme_signals
    .NVMEWrite ( NVMEWrite_out ) ,
    .WRITE_ADDR ( prp1_addr ) ,
    .WritedestLBA ( WritedestLBA_out ) ,
    .NVMERead ( NVMERead_out ) ,
    .READ_ADDR ( prp1_addr ) ,
    .ReadsrcLBA ( ReadsrcLBA_out ) ,
    //prp list header
    .PRP_LIST ( prp_list_head ) ,
    //create complete ids
    .admin_create_queue_cnt ( admin_create_queue_cnt ) ,
    .admin_complete_queue_cnt ( admin_complete_queue_cnt ) ,
    .io_create_queue_cnt ( io_create_queue_cnt ) ,
    .io_complete_queue_cnt ( io_complete_queue_cnt ) ,
    // start read write signal to cmd_bram
    .write_start ( write_start_check_phase ) ,
    .write_start_ack ( write_start_check_phase_ack ) ,
    .read_start ( read_start_check_phase ) ,
    .read_start_ack ( read_start_check_phase_ack ) ,
    //admin cmd signals 
    .seq_tail_done_ack ( seq_tail_done_ack ) ,
    .seq_tail_done ( seq_tail_done ) ,
    .acq_head_done ( acq_head_done ) ,
    .acq_head_done_ack ( acq_head_done_ack ) ,
    //io cmd signals
    .iocq_head_done_ack ( iocq_head_done_ack ) ,
    .iocq_head_done ( iocq_head_done ) ,
    .iosq_tail_done_ack ( iosq_tail_done_ack ) ,
    .iosq_tail_done ( iosq_tail_done ) ,
    //cmd sequences
    .admin_opc ( admin_opc ) ,
    .PSDT_FUSE ( PSDT_FUSE ) ,
    .cid ( cid ) ,
    .nsid ( nsid_out ) ,
    .MPTR ( MPTR ) ,
    .PRP1 ( PRP1 ) ,
    .PRP2 ( PRP2 ) ,
    .CDW10 ( CDW10 ) ,
    .CDW11 ( CDW11 ) ,
    .CDW12 ( CDW12 ) ,
    .CDW13 ( CDW13 ) ,
    .CDW14 ( CDW14 ) ,
    .CDW15 ( CDW15 ) 
) ;

ipr_nvme_io_cmd_axi #( 
       .BLOCK_SIZE_EXP ( BLOCK_SIZE_EXP ) ,
       .IO_SIZE ( IO_SIZE ) ,
       .ACQ_ADDR ( ACQ_ADDR ) ,
       .IOSQ_ADDR ( IOSQ_ADDR ) ,
       .IOCQ_ADDR ( IOCQ_ADDR ) ,
       .idController_ADDR ( idController_ADDR ) ,
       .idNamespace_ADDR ( idNamespace_ADDR ) 
) ipr_nvme_io_cmd_axi (
    .clk_in ( clk_in ) ,
    .resetb ( resetb ) ,
    //axi interface
    // Write ADDR Pipeline
    .cmd_awready ( cmd_awready ) ,
    .cmd_awvalid ( cmd_awvalid ) ,
    .cmd_awaddr ( cmd_awaddr ) ,
    .cmd_awlen ( cmd_awlen ) ,
    .cmd_awsize ( cmd_awsize ) ,
    .cmd_awid ( cmd_awid ) ,
    //Write DATA Pipe
    .cmd_wstrb ( cmd_wstrb ) ,
    .cmd_wready ( cmd_wready ) ,
    .cmd_wvalid ( cmd_wvalid ) ,
    .cmd_wlast ( cmd_wlast ) ,
    .cmd_wdata ( cmd_wdata ) ,
    //Write RESP Pipe
    .cmd_bresp ( cmd_bresp ) ,
    .cmd_bvalid ( cmd_bvalid ) ,
    .cmd_bready ( cmd_bready ) ,
    .cmd_bid ( cmd_bid ) ,
    // Read ADDR Pipeline
    .cmd_arready ( cmd_arready ) ,
    .cmd_arvalid ( cmd_arvalid ) ,
    .cmd_araddr ( cmd_araddr ) ,
    .cmd_arlen ( cmd_arlen ) ,
    .cmd_arsize ( cmd_arsize ) ,
    .cmd_arid ( cmd_arid ) ,
    //Read DATA Pipeline
    .cmd_rready ( cmd_rready ) ,
    .cmd_rvalid ( cmd_rvalid ) ,
    .cmd_rlast ( cmd_rlast ) ,
    .cmd_rdata ( cmd_rdata ) ,
    .cmd_rresp ( cmd_rresp ) ,
    .cmd_rid ( cmd_rid ) ,
    //prp interface
    // Read ADDR Pipeline
    .prp_arready ( prp_arready ) ,
    .prp_arvalid ( prp_arvalid ) ,
    .prp_araddr ( prp_araddr ) ,
    .prp_arlen ( prp_arlen ) ,
    .prp_arsize ( prp_arsize ) ,
    .prp_arid ( prp_arid ) ,
    //Read DATA Pipeline
    .prp_rready ( prp_rready ) ,
    .prp_rvalid ( prp_rvalid ) ,
    .prp_rlast ( prp_rlast ) ,
    .prp_rdata ( prp_rdata ) ,
    .prp_rresp ( prp_rresp ) ,
    .prp_rid ( prp_rid ) ,
    //from nvme control
    .write_start ( write_start_check_phase ) ,
    .write_start_ack ( write_start_check_phase_ack ) ,
    .read_start ( read_start_check_phase ) ,
    .read_start_ack ( read_start_check_phase_ack ) ,
    .prp1_addr ( prp1_addr ) ,
    .is_io_queue ( is_io_queue ) ,
    .max_completion ( max_completion_out ) ,
    .iocq_read_start ( iocq_read_start ) ,
    //cmd sequence
    .admin_opc ( admin_opc ) ,
    .PSDT_FUSE ( PSDT_FUSE ) ,
    .cid ( cid ) ,
    .nsid ( nsid_out ) ,
    .MPTR ( MPTR ) ,
    .PRP1 ( PRP1 ) ,
    .PRP2 ( PRP2 ) ,
    .CDW10 ( CDW10 ) ,
    .CDW11 ( CDW11 ) ,
    .CDW12 ( CDW12 ) ,
    .CDW13 ( CDW13 ) ,
    .CDW14 ( CDW14 ) ,
    .CDW15 ( CDW15 ) ,
    //create complete ids
    .admin_create_queue_cnt ( admin_create_queue_cnt ) ,
    .admin_complete_queue_cnt ( admin_complete_queue_cnt ) ,
    .io_create_queue_cnt ( io_create_queue_cnt ) ,
    .io_complete_queue_cnt ( io_complete_queue_cnt ) ,
    //admin cmd signals 
    .seq_tail_local ( seq_tail_local ) ,
    .seq_tail_done_ack ( seq_tail_done_ack ) ,
    .seq_tail_done ( seq_tail_done ) ,
    .acq_head_done ( acq_head_done ) ,
    .acq_head_done_ack ( acq_head_done_ack ) ,
    .acq_head_local_out ( acq_head_local_out ) ,
    //io_cmd signals
    .iocq_head_local_out ( iocq_head_local_out ) ,
    .iocq_head_done ( iocq_head_done ) ,
    .iocq_head_done_ack ( iocq_head_done_ack ) ,
    .iosq_tail_local ( iosq_tail_local ) ,
    .iosq_tail_done ( iosq_tail_done ) ,
    .iosq_tail_done_ack ( iosq_tail_done_ack ) ,
    //ssd information
    .PageSize ( PageSize ) ,
    .MDTS ( MDTS ) ,
    .NS_SIZE ( NS_SIZE ) ,
    .BlockSize ( BlockSize ) ,
    .MaxTransferSize ( MaxTransferSize )
) ;

axi_arbit # ( 
    .BASE_ADDR_BAR ( BASE_ADDR_BAR )
) axi_arbit (
    .clk_in ( clk_in ) ,
    .areset_n ( ~ resetb ) ,
    // from xdma_init
    .read_start ( read_axi_start ) ,
    .write_start ( write_axi_start ) ,
    .read_start_ack ( read_axi_start_ack ) ,
    .write_start_ack ( write_axi_start_ack ) ,
    .reg_out_data ( reg_out_data ) ,
    .reg_out_addr ( reg_out_addr ) ,
    .reg_in_addr ( reg_out_addr ) ,
    .reg_in_data ( reg_in_data ) ,
    //control register read write to xdma or nvme ssd
    .sys_write_master_ready ( sys_write_master_ready ) ,
    .sys_write_addr ( sys_write_addr ) ,
    .sys_write_data ( sys_write_data ) ,
    .sys_write_req ( sys_write_req ) ,
    .sys_write_master_done ( sys_write_master_done ) ,
    .sys_read_master_ready ( sys_read_master_ready ) ,
    .sys_read_addr ( sys_read_addr ) ,
    .sys_read_data ( sys_read_data ) ,
    .sys_read_data_valid ( sys_read_data_valid ) ,
    .sys_read_req ( sys_read_req ) ,
    .sys_read_master_done ( sys_read_master_done ) ,
    //admin cmd signals 
    .seq_tail_local ( seq_tail_local ) ,
    .seq_tail_done ( seq_tail_done ) ,
    .seq_tail_done_ack ( seq_tail_done_ack ) ,
    .acq_head_local ( acq_head_local_out ) ,
    .acq_head_done ( acq_head_done ) ,
    .acq_head_done_ack ( acq_head_done_ack ) ,
    //io cmd signals
    .iosq_tail_done ( iosq_tail_done ) ,
    .iosq_tail_local ( iosq_tail_local ) ,
    .iosq_tail_done_ack ( iosq_tail_done_ack ) ,
    .iocq_head_done ( iocq_head_done ) ,
    .iocq_head_local ( iocq_head_local_out ) ,
    .iocq_head_done_ack ( iocq_head_done_ack ) 
) ;

IP_axi_master IP_axi_master (
    .clock  ( clk_in ) ,
    .reset_n ( ~ resetb ) ,
    //axi bus interface
    /*-- Read Address Channel --*/
    .bus_arvalid ( bus_arvalid ),
    .bus_arready ( bus_arready ) ,
    .bus_araddr ( bus_araddr ) ,
    .bus_arburst ( bus_arburst ),
    .bus_arcache ( bus_arcache ),
    .bus_arlen ( bus_arlen ) ,
    .bus_arprot ( bus_arprot ),
    .bus_arsize ( bus_arsize ),
    .bus_aruser ( bus_aruser ),
    .bus_arid ( bus_arid ) ,

    /*-- Read Data Channel --*/
    .bus_rvalid ( bus_rvalid ),
    .bus_rdata ( bus_rdata ),
    .bus_rlast ( bus_rlast ),
    .bus_rresp ( bus_rresp ),
    .bus_rid ( bus_rid ) ,
    .bus_rready ( bus_rready ) ,
    /*-- Write Address Channel --*/
    .bus_awready ( bus_awready ) , 
    .bus_awvalid ( bus_awvalid ) ,
    .bus_awaddr ( bus_awaddr ) ,
    .bus_awburst ( bus_awburst ) ,
    .bus_awcache ( bus_awcache ) ,
    .bus_awlen ( bus_awlen ),
    .bus_awprot ( bus_awprot ),
    .bus_awsize ( bus_awsize ),
    .bus_awuser ( bus_awuser ),
    .bus_awid ( bus_awid ) ,

    /*-- Write Data Channel --*/
    .bus_wready ( bus_wready ),
    .bus_wvalid ( bus_wvalid ),
    .bus_wlast ( bus_wlast ) ,
    .bus_wdata ( bus_wdata ) ,
    .bus_wstrb ( bus_wstrb ) ,

    /*-- Write Response Channel --*/
    .bus_bvalid ( bus_bvalid ) ,
    .bus_bresp ( bus_bresp ),
    .bus_bready ( bus_bready ),
    .bus_bid ( bus_bid ) ,
    // read register
    .sys_read_keyhole_addr ( 1'b0 ) ,
    .sys_read_burst_size ( 16'd1 ) ,
    .sys_read_addr ( sys_read_addr ) ,
    .sys_read_data ( sys_read_data ) ,
    .sys_read_data_valid ( sys_read_data_valid ) ,
    .sys_read_req ( sys_read_req ) ,
    .sys_read_req_id ( 1'b0 ) ,
    .sys_read_master_ready ( sys_read_master_ready ) ,
    // write register
    .sys_write_keyhole_addr ( 1'b0 ) ,
    .sys_write_burst_size ( 16'd1 ) ,
    .sys_write_addr ( sys_write_addr ) ,
    .sys_write_req ( sys_write_req ) ,
    .sys_write_req_id ( 1'b0 ) ,
    .sys_write_data ( sys_write_data ) ,
    .sys_write_master_ready ( sys_write_master_ready ) ,
    // sys interface
    .sys_byte_enable ( 4'hf ) ,
    .sys_write_resp_ready ( 1'b1 ) ,
    .sys_fifo_empty ( 1'b0 ) ,
    .sys_read_err ( sys_read_err ) ,
    .sys_write_err ( sys_write_err ) 
) ;

//data_fifo_control # ( 
//    .DATA_WIDTH ( DATA_WIDTH )
//) data_fifo_control (
//    .aclk ( clk_in ) ,
//    .aresetn ( ~ resetb ) ,
//    .fifo_pop ( fifo_pop ) ,
//    .s_axis_tvalid ( s_axis_tvalid ) ,
//    .s_axis_tready ( s_axis_tready ) ,
//    .s_axis_tdata ( s_axis_tdata ) ,
//    .data_from_fifo ( data_from_fifo ) ,
//    .fifo_empty ( fifo_empty ) ,
//    .fifo_underflow ( fifo_underflow )
//) ;

//IP_axi_slave_read #( 
//    .DATA_WIDTH ( DATA_WIDTH )
//) IP_axi_slave_read (
//    .clock ( clk_in ) ,
//    .reset_n ( ~ resetb ) ,
//    // Read ADDR Pipeline
//    .arready ( s_axi_arready ) ,
//    .arvalid ( s_axi_arvalid ) ,
//    .araddr ( s_axi_araddr ) ,
//    .arlen ( s_axi_arlen ) ,
//    .arsize ( s_axi_arsize ) ,
//    .arid ( s_axi_arid ) ,
//    //Read DATA Pipeline
//    .rready ( s_axi_rready ) ,
//    .rvalid ( s_axi_rvalid ) ,
//    .rlast ( s_axi_rlast ) , 
//    .rdata ( s_axi_rdata ) ,
//    .rresp ( s_axi_rresp ) ,
//    .rid ( s_axi_rid ) ,
//    .data_from_fifo ( data_from_fifo ) ,
//    .fifo_empty ( fifo_empty) ,
//    .fifo_underflow ( fifo_underflow ) ,
//    .fifo_pop ( fifo_pop )
//) ;

////pixel_counter #(
////    .DATA_WIDTH ( DATA_WIDTH )
////) pixel_counter (
////    .aclk ( clk_in ) ,
////    .aresetn ( ~ resetb ) ,
////    .data_to_fifo ( data_to_fifo ) ,
////    .fifo_push ( fifo_push ) ,
////    .fifo_overflow ( fifo_overflow ) ,
////    .fifo_full ( fifo_full ) ,
////    .s_axi_tx_tdata_out ( m_axi_tdata ) ,
////    .s_axi_tx_tready_out ( m_axi_tready ) ,
////    .s_axi_tx_tvalid_out ( m_axi_tvalid )
////) ;

//IP_axi_slave_write # ( 
//    .DATA_WIDTH ( DATA_WIDTH )
//) IP_axi_slave_write (
//    .clock ( clk_in ) ,
//    .reset_n ( ~ resetb ) ,
//    // Write ADDR Pipeline
//    .awready ( s_axi_awready ) ,
//    .awvalid ( s_axi_awvalid ) ,
//    .awaddr ( s_axi_awaddr ) ,
//    .awlen ( s_axi_awlen ) ,
//    .awsize ( s_axi_awsize ) ,
//    .awid ( s_axi_awid ) ,
//    //Write DATA Pipeline
//    .wready ( s_axi_wready ) ,
//    .wvalid ( s_axi_wvalid ) ,
//    .wlast ( s_axi_wlast ) ,
//    .wstrb ( s_axi_wstrb ) ,
//    .wdata ( s_axi_wdata ) ,
//    //Write RESP pipe
//    .bresp ( s_axi_bresp ) ,
//    .bvalid ( s_axi_bvalid ) ,
//    .bready ( s_axi_bready ) ,
//    .bid ( s_axi_bid ) ,
//    .data_to_fifo ( m_axis_tdata ) ,
//    .fifo_full ( ~ m_axis_tready ) ,
//    .fifo_overflow ( 1'b0 ) ,
//    .fifo_push ( m_axis_tvalid )
//) ;

endmodule