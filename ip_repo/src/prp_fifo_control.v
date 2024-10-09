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


module prp_fifo_control # (
    parameter DATA_WIDTH = 64 ,
    parameter DDR_BASE_ADDR = 64'h10_0000_0000 ,
    parameter BLOCK_SIZE_EXP = 16 ,
    parameter DDR_PAGE_SIZE_EXP = 12
) (
    input aclk ,
    input aresetn ,
    
    output prog_full ,
    input fifo_pop ,
    output [14:0] data_count ,
	
	input [63:0] prp1_addr ,
	input [8:0] length ,
	output [DATA_WIDTH-1:0] data_from_fifo ,
	output fifo_empty ,
	output fifo_underflow 
    );
    //localparam integer declarations

    //regs
    reg [63:0] prp_list_data ;
    reg [31:0] prp_cnt ;
    //wires
    wire empty_n ;
    wire full_n ;
    //main codes

    assign fifo_empty = 1'b0 ;
    assign prog_full = 1'b0 ;
    assign fifo_underflow = 1'b0 ;
    assign data_from_fifo = prp_list_data ;
    
    always @ ( posedge aclk )
    begin
        
        if ( aresetn == 1'b0 )
            prp_cnt <= 32'd1 ;
        else if ( fifo_pop )
            if ( prp_cnt == ( ( ( ( 1 << BLOCK_SIZE_EXP ) >> DDR_PAGE_SIZE_EXP ) - 1 ) ) )
                prp_cnt <= 32'd1 ;
            else
                prp_cnt <= prp_cnt + 32'd1 ;    
         
        if ( aresetn == 1'b0 )
            prp_list_data <= prp1_addr ;
        else if ( fifo_pop )   
            if ( prp_cnt == ( ( ( ( 1 << BLOCK_SIZE_EXP ) >> DDR_PAGE_SIZE_EXP ) - 1 ) ) )
                prp_list_data <= prp1_addr + 64'h1000 ;
            else 
                prp_list_data <= prp_list_data + 64'h1000 ;   
    end
    
//	ddr3_hls_write_gmem_m_axi_fifo # ( 
//	   .DATA_BITS ( DATA_WIDTH ) ,
//	   .DEPTH ( DATA_DEPTH ) ,
//	   .DEPTH_BITS ( 15 )
//	 ) ddr3_hls_write_gmem_m_axi_fifo_wdata (
//	      .sclk ( aclk ) ,
//          .reset ( ~ aresetn ),
//          .sclk_en ( 1'b1 ) ,
//          .empty_n ( empty_n ) ,
//          .full_n ( full_n ) ,
//          .rdreq ( fifo_pop ) ,
//          .wrreq ( prp_list_wr_en ) ,
//          .data_count ( data_count ) ,
//          .q ( data_from_fifo ) ,
//          .data ( prp_list_data )
//	 ) ;

endmodule
