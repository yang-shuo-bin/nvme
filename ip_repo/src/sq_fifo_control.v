`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/13 18:21:34
// Design Name: 
// Module Name: sq_fifo_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sq_fifo_control # (
    parameter DATA_WIDTH = 32 ,
    parameter DATA_DEPTH = 4096 
) (
    input aclk ,
    input aresetn ,
    
    output prog_full ,
    input fifo_pop ,
    output [14:0] data_count ,
    
	input wr_en ,
	input [DATA_WIDTH-1:0] data_in ,
	
	input [8:0] length ,
	output [DATA_WIDTH-1:0] data_from_fifo ,
	output fifo_empty ,
	output fifo_underflow 
    );
    //localparam integer declarations

    //regs
    
    //wires
    wire empty_n ;
    wire full_n ;
    //main codes

    assign fifo_empty = ( DATA_WIDTH == 64 ) ? 1'b0 : ( ~ empty_n ) ;
    assign prog_full = ( data_count > DATA_DEPTH - 17 ) ? 1'b1 : 1'b0 ;
    assign fifo_underflow = ~ full_n ;
    
	ddr3_hls_write_gmem_m_axi_fifo # ( 
	   .DATA_BITS ( DATA_WIDTH ) ,
	   .DEPTH ( DATA_DEPTH ) ,
	   .DEPTH_BITS ( 15 )
	 ) ddr3_hls_write_gmem_m_axi_fifo_wdata (
	      .sclk ( aclk ) ,
          .reset ( ~ aresetn ),
          .sclk_en ( 1'b1 ) ,
          .empty_n ( empty_n ) ,
          .full_n ( full_n ) ,
          .rdreq ( fifo_pop ) ,
          .wrreq ( wr_en ) ,
          .data_count ( data_count ) ,
          .q ( data_from_fifo ) ,
          .data ( data_in )
	 ) ;

endmodule
