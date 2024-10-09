module ipr_nvme_io_cmd_axi # ( 
    parameter UNIQUE_ID_SZ    = 3,
    parameter BUS_MULTIPLIER  = 1,
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32 ,
    parameter BLOCK_SIZE_EXP = 16 ,
    parameter IO_SIZE = 16'h003f ,
    parameter ACQ_ADDR = 32'ha010_1000 ,
    parameter IOSQ_ADDR = 32'ha010_2000 ,
	parameter IOCQ_ADDR = 32'ha010_3000 ,
	parameter idController_ADDR = 32'ha010_4000 ,
	parameter idNamespace_ADDR = 32'ha010_5000 
) (
	input clk_in ,
	input resetb ,
	
    //axi interface
    // Write ADDR Pipeline
    output                     cmd_awready,
    input                      cmd_awvalid,
    input[ADDR_WIDTH-1:0]      cmd_awaddr,
    input[7:0]                 cmd_awlen,
    input[2:0]                 cmd_awsize,
    input[UNIQUE_ID_SZ-1:0]    cmd_awid,

    //Write DATA Pipe
    input[(DATA_WIDTH/8)-1:0]  cmd_wstrb,
    output                     cmd_wready,
    input                      cmd_wvalid,
    input                      cmd_wlast,
    input[(DATA_WIDTH-1):0]    cmd_wdata,
    //Write RESP Pipe
    output   [1:0]            cmd_bresp,
    output                     cmd_bvalid,
    input                      cmd_bready,
    output[UNIQUE_ID_SZ-1:0]   cmd_bid,
    // Read ADDR Pipeline
    output                     cmd_arready,
    input                      cmd_arvalid,
    input[ADDR_WIDTH-1:0]      cmd_araddr,
    input[7:0]                 cmd_arlen,
    input[2:0]                 cmd_arsize,
    input[UNIQUE_ID_SZ-1:0]    cmd_arid,
    //Read DATA Pipeline
    input                      cmd_rready,
    output                     cmd_rvalid,
    output                     cmd_rlast,
    output[(DATA_WIDTH-1):0]   cmd_rdata,
    output[1:0]                cmd_rresp,
    output[UNIQUE_ID_SZ-1:0]   cmd_rid,
    //prp interface
    // Read ADDR Pipeline
    output                  prp_arready,
    input                      prp_arvalid,
    input[ADDR_WIDTH-1:0]      prp_araddr,
    input[7:0]                 prp_arlen,
    input[2:0]                 prp_arsize,
    input[UNIQUE_ID_SZ-1:0]    prp_arid,
    //Read DATA Pipeline
    input                      prp_rready,
    output                     prp_rvalid,
    output                     prp_rlast,
    output[63:0]           prp_rdata,
    output[1:0]                prp_rresp,
    output[UNIQUE_ID_SZ-1:0]   prp_rid,

    //cmd interface
	input                      write_start ,
	output                     write_start_ack ,
    input                      read_start ,
    output                     read_start_ack ,

    input                      is_io_queue ,
    input [7:0]                max_completion ,
    input                      iocq_read_start ,

    input [63:0]               prp1_addr ,

	input [7:0]                 admin_opc ,
	input [7:0]                 PSDT_FUSE ,
	input [15:0]                cid ,
	input [31:0]                nsid ,
	input [63:0]                MPTR ,
	input [63:0]                PRP1 ,
	input [63:0]                PRP2 ,
	input [31:0]                CDW10 ,
	input [31:0]                CDW11 ,
	input [31:0]                CDW12 ,
	input [31:0]                CDW13 ,
	input [31:0]                CDW14 ,
	input [31:0]                CDW15 ,
	
	output [15:0]               admin_create_queue_cnt ,
    output [15:0]               admin_complete_queue_cnt ,
	output [15:0]               io_create_queue_cnt ,
    output [15:0]               io_complete_queue_cnt ,

	output [15:0]               seq_tail_local ,
	input                       seq_tail_done_ack ,
	output                      seq_tail_done ,
    output [15:0]               acq_head_local_out ,
	input                       acq_head_done_ack ,
	output                      acq_head_done ,
	
	output [15:0]               iosq_tail_local ,
	input                       iosq_tail_done_ack ,
	output                      iosq_tail_done ,
    output [15:0]               iocq_head_local_out ,
	input                       iocq_head_done_ack ,
	output                      iocq_head_done ,

    output                      sq_fifo_wr_en ,
    output [31:0]               sq_data_in ,

    output                      cq_fifo_rd_en ,
    output [31:0]               cq_data_out ,
    
    output                      ip_slave_write_fifo_push ,
    output [31:0]               ip_slave_write_data_in_fifo ,
    output                      wr_en ,
    output [31:0]               data_in ,
    output [31:0]               addr_latch ,
    //ssd information
    input [3:0] PageSize ,
    output [63:0] NS_SIZE ,
    output [7:0] MDTS ,
    output [7:0] BlockSize ,
    output [31:0] MaxTransferSize 
                                             
    );

    //regs

    //wires

//    wire [1:0]  sq_fifo_full ;
//    wire [1:0]  sq_fifo_pop ;
//    wire [1:0]  sq_fifo_empty ;
//    wire [1:0]  sq_fifo_underflow ;
//    wire [63:0] sq_data_from_fifo ; 
    
    wire [31:0] ip_slave_read_data_from_fifo ;
    wire           ip_slave_read_fifo_empty ;
    wire           ip_slave_read_fifo_full ;
    wire           ip_slave_read_fifo_pop ;
    wire           ip_slave_read_fifo_underflow ;
    
//    wire [1:0]  cq_fifo_full ;
//    wire [1:0]  cq_fifo_push ;
//    wire [1:0]  cq_fifo_empty ;
//    wire [1:0]  cq_fifo_overflow ;
//    wire [63:0] cq_data_in_fifo ; 
    
    wire           ip_slave_write_fifo_full ;
    wire           ip_slave_write_fifo_empty ;
    wire           ip_slave_write_fifo_overflow ;
    
    wire        prp_fifo_pop ;
    wire        prp_fifo_empty ;
    wire        prp_fifo_underflow ;
    wire [63:0]  prp_data_from_fifo ;
    
//    assign ip_slave_read_data_from_fifo = ( is_io_queue == 1'b1 ) ? sq_data_from_fifo[63:32] : sq_data_from_fifo[31:0] ;
//    assign ip_slave_read_fifo_empty = ( is_io_queue == 1'b1 ) ? sq_fifo_empty[1] : sq_fifo_empty[0] ;
//    assign ip_slave_read_fifo_full = ( is_io_queue == 1'b1 ) ? sq_fifo_full[1] : sq_fifo_full[0] ;
//    assign sq_fifo_pop[0] = ip_slave_read_fifo_pop & ( ~ is_io_queue ) ;
//    assign sq_fifo_pop[1] = ip_slave_read_fifo_pop & is_io_queue ;
//    assign ip_slave_read_fifo_underflow = ( is_io_queue == 1'b1 ) ? sq_fifo_underflow[1] : sq_fifo_underflow[0] ;
    
//    assign cq_data_in_fifo[63:32] = ip_slave_write_data_in_fifo ;
//    assign cq_data_in_fifo[31:0] = ip_slave_write_data_in_fifo ; 
//    assign ip_slave_write_fifo_empty = ( is_io_queue == 1'b1 ) ? cq_fifo_empty[1] : cq_fifo_empty[0] ;
//    assign ip_slave_write_fifo_full = ( is_io_queue == 1'b1 ) ? cq_fifo_full[1] : cq_fifo_full[0] ;
//    assign cq_fifo_push[0] = ip_slave_write_fifo_push & ( ~ is_io_queue ) ;
//    assign cq_fifo_push[1] = ip_slave_write_fifo_push & is_io_queue ;
//    assign ip_slave_write_fifo_overflow = ( is_io_queue == 1'b1 ) ? cq_fifo_overflow[1] : cq_fifo_overflow[0] ;
//    assign cq_data_out = ( is_io_queue == 1'b1 ) ? cq_fifo_data[63:32] : cq_fifo_data[31:0] ;

    sq_fifo_control # ( 
        .DATA_WIDTH ( 32 ) ,
        .DATA_DEPTH ( ( IO_SIZE + 2 )*16 )
    ) sq_fifo_control_0 (
        .aclk ( clk_in ) ,
        .aresetn ( ~ resetb ) ,
        .prog_full ( ip_slave_read_fifo_full ) ,
        .fifo_pop ( ip_slave_read_fifo_pop ) ,
        .wr_en ( sq_fifo_wr_en ) ,
        .data_in ( sq_data_in ) ,
        .data_from_fifo ( ip_slave_read_data_from_fifo ) ,
        .fifo_empty ( ip_slave_read_fifo_empty ) ,
        .fifo_underflow ( ip_slave_read_fifo_underflow ) 
    ) ;

    IP_axi_slave_read #( 
        .DATA_WIDTH ( DATA_WIDTH )
        ) IP_axi_slave_read (
        .clock ( clk_in ) ,
        .reset_n ( ~ resetb ) ,
        // Read ADDR Pipeline
        .arready ( cmd_arready ) ,
        .arvalid ( cmd_arvalid ) ,
        .araddr ( cmd_araddr ) ,
        .arlen ( cmd_arlen ) ,
        .arsize ( cmd_arsize ) ,
        .arid ( cmd_arid ) ,
        //Read DATA Pipeline
        .rready ( cmd_rready ) ,
        .rvalid ( cmd_rvalid ) ,
        .rlast ( cmd_rlast ) , 
        .rdata ( cmd_rdata ) ,
        .rresp ( cmd_rresp ) ,
        .rid ( cmd_rid ) ,
        .data_from_fifo ( ip_slave_read_data_from_fifo ) ,
        .fifo_empty ( ip_slave_read_fifo_empty ) ,
        .fifo_underflow ( ip_slave_read_fifo_underflow ) ,
        .fifo_pop ( ip_slave_read_fifo_pop )
    ) ;

    ipr_nvme_sq_sm # ( 
        .IO_SIZE ( IO_SIZE ) 
    ) ipr_nvme_sq_sm (
        .clk_in ( clk_in ) ,
        .resetb ( resetb ) ,
        .write_start ( write_start ) ,
        .write_start_ack ( write_start_ack ) ,
        .is_io_queue ( is_io_queue ) ,
        .admin_opc ( admin_opc ) ,
        .PSDT_FUSE ( PSDT_FUSE ) ,
        .cid ( cid ) ,
        .nsid ( nsid ) ,
        .MPTR ( MPTR ) ,
        .PRP1 ( PRP1 ) ,
        .PRP2 ( PRP2 ) ,
        .CDW10 ( CDW10 ) ,
        .CDW11 ( CDW11 ) ,
        .CDW12 ( CDW12 ) ,
        .CDW13 ( CDW13 ) ,
        .CDW14 ( CDW14 ) ,
        .CDW15 ( CDW15 ) ,
        .admin_create_queue_cnt ( admin_create_queue_cnt ) ,
        .io_create_queue_cnt ( io_create_queue_cnt ) ,
        .doutb ( sq_data_in ) ,
        .wr_en ( sq_fifo_wr_en ) ,
        .sq_fifo_full ( ip_slave_read_fifo_full ) ,
        .seq_tail_local ( seq_tail_local ) ,
        .seq_tail_done ( seq_tail_done ) ,
        .seq_tail_done_ack ( seq_tail_done_ack ) ,
        .iosq_tail_local ( iosq_tail_local ) ,
        .iosq_tail_done ( iosq_tail_done ) ,
        .iosq_tail_done_ack ( iosq_tail_done_ack ) 
     ) ;

    prp_fifo_control # ( 
        .DATA_WIDTH ( 64 ) ,
        .BLOCK_SIZE_EXP ( BLOCK_SIZE_EXP ) 
    ) prp_fifo_control (
        .aclk ( clk_in ) ,
        .aresetn ( ~ resetb ) ,
        .prog_full ( prp_fifo_full ) ,
        .fifo_pop ( prp_fifo_pop ) ,
        .prp1_addr ( prp1_addr ) ,
        .data_from_fifo ( prp_data_from_fifo ) ,
        .fifo_empty ( prp_fifo_empty ) ,
        .fifo_underflow ( prp_fifo_underflow ) 
    ) ; 

    IP_axi_slave_read #( 
        .DATA_WIDTH ( 64 )
    ) IP_axi_slave_read_1 (
        .clock ( clk_in ) ,
        .reset_n ( ~ resetb ) ,
        // Read ADDR Pipeline
        .arready ( prp_arready ) ,
        .arvalid ( prp_arvalid ) ,
        .araddr ( prp_araddr ) ,
        .arlen ( prp_arlen ) ,
        .arsize ( prp_arsize ) ,
        .arid ( prp_arid ) ,
        //Read DATA Pipeline
        .rready ( prp_rready ) ,
        .rvalid ( prp_rvalid ) ,
        .rlast ( prp_rlast ) , 
        .rdata ( prp_rdata ) ,
        .rresp ( prp_rresp ) ,
        .rid ( prp_rid ) ,
        .data_from_fifo ( prp_data_from_fifo ) ,
        .fifo_empty ( prp_fifo_empty ) ,
        .fifo_underflow ( prp_fifo_underflow ) ,
        .fifo_pop ( prp_fifo_pop )
    ) ;

    cq_fifo_control # (
        .DATA_WIDTH ( 32 ) ,
        .ACQ_ADDR ( ACQ_ADDR ) ,
        .IOCQ_ADDR ( IOCQ_ADDR ) ,
        .idController_ADDR ( idController_ADDR ) ,
        .idNamespace_ADDR ( idNamespace_ADDR )
    ) cq_fifo_control_0 (
        .aclk ( clk_in ) ,
        .aresetn ( ~ resetb ) ,
        .awready ( cmd_awready ) ,
        .awvalid ( cmd_awvalid ) ,
        .awaddr ( cmd_awaddr ) , 
        .fifo_empty ( ip_slave_write_fifo_empty ) ,
        .fifo_full ( ip_slave_write_fifo_full ) ,
        .fifo_push ( ip_slave_write_fifo_push ) ,
        .fifo_overflow ( ip_slave_write_fifo_overflow ) ,
        .data_in_fifo ( ip_slave_write_data_in_fifo ) ,
        .wr_en ( wr_en ) ,
        .data_in ( data_in ) ,
        .addr_latch ( addr_latch ) ,
        .rd_en ( cq_fifo_rd_en ) ,
        .data_out_fifo ( cq_data_out ) ,
        .PageSize ( PageSize ) ,
        .MDTS ( MDTS ) ,
        .NS_SIZE ( NS_SIZE ) ,
        .BlockSize ( BlockSize ) ,
        .MaxTransferSize ( MaxTransferSize )
    ) ;

//    cq_fifo_control # (
//        .DATA_WIDTH ( 32 )
//    ) cq_fifo_control_1 (
//        .aclk ( clk_in ) ,
//        .aresetn ( ~ resetb ) ,
//        .fifo_empty ( cq_fifo_empty[1] ) ,
//        .fifo_full ( cq_fifo_full[1] ) ,
//        .fifo_push ( cq_fifo_push[1] ) ,
//        .fifo_overflow ( cq_fifo_overflow[1] ) ,
//        .data_in_fifo ( cq_data_in_fifo[63:32] ) ,
//        .rd_en ( cq_fifo_rd_en && is_io_queue ) ,
//        .data_out ( cq_fifo_data[63:32] )
//    ) ;

    IP_axi_slave_write # ( 
        .DATA_WIDTH ( DATA_WIDTH )
    ) IP_axi_slave_write (
        .clock ( clk_in ) ,
        .reset_n ( ~ resetb ) ,
        // Write ADDR Pipeline
        .awready ( cmd_awready ) ,
        .awvalid ( cmd_awvalid ) ,
        .awaddr ( cmd_awaddr ) ,
        .awlen ( cmd_awlen ) ,
        .awsize ( cmd_awsize ) ,
        .awid ( cmd_awid ) ,
        //Write DATA Pipeline
        .wready ( cmd_wready ) ,
        .wvalid ( cmd_wvalid ) ,
        .wlast ( cmd_wlast ) ,
        .wstrb ( cmd_wstrb ) ,
        .wdata ( cmd_wdata ) ,
        //Write RESP pipe
        .bresp ( cmd_bresp ) ,
        .bvalid ( cmd_bvalid ) ,
        .bready ( cmd_bready ) ,
        .bid ( cmd_bid ) ,
        .data_to_fifo ( ip_slave_write_data_in_fifo ) ,
        .fifo_full ( ip_slave_write_fifo_full ) ,
        .fifo_overflow (ip_slave_write_fifo_overflow ) ,
        .fifo_push ( ip_slave_write_fifo_push )
    ) ;

    ipr_nvme_cq_sm # (
        .IO_SIZE ( IO_SIZE ) 
     ) ipr_nvme_cq_sm   (
        .clk_in ( clk_in ) ,
        .resetb ( resetb ) ,
        .read_start ( read_start ) ,
        .read_start_ack ( read_start_ack ) ,
        .is_io_queue ( is_io_queue ) ,
        .admin_complete_queue_cnt ( admin_complete_queue_cnt ) ,
        .io_complete_queue_cnt ( io_complete_queue_cnt ) ,
        .cq_fifo_empty ( ip_slave_write_fifo_empty ) ,
        .dinb ( cq_data_out ) ,
        .rd_en ( cq_fifo_rd_en ) ,
        .acq_head_local_out ( acq_head_local_out ) ,
        .acq_head_done ( acq_head_done ) ,
        .acq_head_done_ack ( acq_head_done_ack ) ,
        .iocq_head_local_out ( iocq_head_local_out ) ,
        .iocq_head_done ( iocq_head_done ) ,
        .iocq_head_done_ack ( iocq_head_done_ack )
    ) ;

    endmodule