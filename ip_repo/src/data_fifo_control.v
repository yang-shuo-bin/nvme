`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/24 09:30:12
// Design Name: 
// Module Name: data_fifo_control
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


module data_fifo_control # ( 
    parameter DATA_WIDTH = 128 
) (
	input aclk ,
    input aresetn ,
    
    output [1:0] prog_full ,
    input fifo_pop ,
    output [13:0] data_count ,
    
	input s_axis_tvalid ,
	output s_axis_tready ,
	input [DATA_WIDTH-1:0] s_axis_tdata ,
	
	input [8:0] length ,
	output [DATA_WIDTH-1:0] data_from_fifo ,
	output fifo_empty ,
	output fifo_underflow 
    );
    //localparam integer declarations
    localparam S_IDLE = 4'b0001 ;
    localparam S_WAIT = 4'b0010 ;
    localparam  S_READ_DATA = 4'b0100 ;
    localparam S_READ_DONE = 4'b1000 ; 
    //regs
    reg [3:0] next_state ;
    reg [3:0] state ;
   
    //wires
    wire empty_n ;
    wire full_n ;
    //main codes

    assign s_axis_tready = ( data_count < 16300 ) ? 1'b1 : 1'b0  ;
    assign fifo_empty = ~ empty_n ;
    assign prog_full = 2'b00 ;
    assign fifo_underflow = ~ full_n ;
    
	ddr3_hls_write_gmem_m_axi_fifo # ( 
	   .DATA_BITS ( DATA_WIDTH ) ,
	   .DEPTH ( 16384 ) ,
	   .DEPTH_BITS ( 14 )
	 ) ddr3_hls_write_gmem_m_axi_fifo_wdata (
	      .sclk ( aclk ) ,
          .reset ( ~ aresetn ),
          .sclk_en ( 1'b1 ) ,
          .empty_n ( empty_n ) ,
          .full_n ( full_n ) ,
          .rdreq ( fifo_pop ) ,
          .wrreq ( s_axis_tvalid && s_axis_tready ) ,
          .data_count ( data_count ) ,
          .q ( data_from_fifo ) ,
          .data ( s_axis_tdata )
	 ) ;
	
//	always @ ( posedge aclk )
//	begin
//	   if ( aresetn == 1'b0 )
//	       state <= S_IDLE ;
//	   else
//	       state <= next_state ;
//	end
	
//	always @ ( * )
//	begin
//	   if ( aresetn == 1'b0 ) begin
//	       next_state = S_IDLE ;
//	    end   
//	    else begin
//	       case ( state )
//	           S_IDLE :
//	               begin
//	                   if ( read_req )
//	                       next_state = S_WAIT ;
//	                   else
//	                       next_state = S_IDLE ;
//	               end
//	          S_WAIT :
//	              begin
//	                   if ( ~ fifo_empty )
//	                       next_state = S_READ_DATA ;
//	                   else
//	                       next_state = S_WAIT ;
//	              end     
//	          S_READ_DATA :
//	           begin
//	               if ( transfer_done )
//	                   next_state = S_READ_DONE ;
//	                else
//	                   next_state = S_READ_DATA ;
//	           end     
//	        S_READ_DONE :
//	           begin
//	               next_state = S_IDLE ;
//	           end   
//	      default : ;
//	   endcase            
//	end
//end

//always @ ( posedge aclk )
//begin
//    if ( aresetn == 1'b0 )  
//        rd_en <= 1'b0 ;
//    else if ( ( next_state == S_READ_DATA ) && ( ~ fifo_empty ) )
//        rd_en <= 1'b1 ;
//    else
//        rd_en <= 1'b0 ;
        
//end

endmodule
