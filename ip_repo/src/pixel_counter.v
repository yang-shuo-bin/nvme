`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/03/06 18:16:59
// Design Name: 
// Module Name: pixel_counter
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


module pixel_counter #(
    parameter DATA_WIDTH = 48
) (
	input aclk ,
	input aresetn ,
    input [DATA_WIDTH-1:0] data_to_fifo ,
    input fifo_push ,   
    output fifo_overflow ,
    output fifo_full ,
       
    output [DATA_WIDTH-1:0] s_axi_tx_tdata_out ,
    input s_axi_tx_tready_out ,
    output reg s_axi_tx_tvalid_out 
    );
    //localparam integer declarations
    
    //regs
    reg rd_en ;
    //wires
    // wire [63:0] dout ;
    wire [13:0] data_count ;
    wire full ;
    //main codes
    // assign s_axi_tx_tdata_out = { dout[63:40],dout[31:8] } ;
    assign fifo_full = ( data_count > 14'd16300 ) ;
    assign fifo_overflow = 1'b0 ;
	 
    ddr3_hls_write_gmem_m_axi_fifo #(
       .DATA_BITS ( DATA_WIDTH ) ,
	   .DEPTH ( 16384 ) ,
	   .DEPTH_BITS ( 14 ) 
    )ddr3_hls_write_gmem_m_axi_fifo_wdata (
  .sclk(aclk),                
  .reset ( ~ aresetn ),
  .sclk_en ( 1'b1 ),
  .data(data_to_fifo),                
  .wrreq(fifo_push),           
  .rdreq(s_axi_tx_tvalid_out&&s_axi_tx_tready_out),            
  .q(s_axi_tx_tdata_out),           
  .full_n(full),              
  .empty_n(),            
  .data_count(data_count)  
);

    
    always @ ( posedge aclk )
    begin
        
        if ( aresetn == 1'b0 )
            rd_en <= 1'b0 ;
        else if ( data_count > 12'd128 ) 
            rd_en <= 1'b1 ;  
        else
            rd_en <= 1'b0 ;
        
        if ( aresetn == 1'b0 )
            s_axi_tx_tvalid_out <= 1'b0 ;
        else if ( rd_en )   
            s_axi_tx_tvalid_out <= 1'b1 ;
        else if ( s_axi_tx_tready_out ) 
            s_axi_tx_tvalid_out <= 1'b0 ;  
    end
endmodule
