`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/14 11:12:17
// Design Name: 
// Module Name: cq_fifo_control
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


module cq_fifo_control# (
    parameter ADDR_WIDTH = 32 ,
    parameter DATA_WIDTH = 32 ,
    parameter idController_ADDR = 32'ha010_4000 ,
	parameter idNamespace_ADDR = 32'ha010_5000 ,
	parameter ACQ_ADDR = 32'ha010_1000 ,
	parameter IOCQ_ADDR = 32'ha010_3000
) (
    input aclk ,
    input aresetn ,
    input awvalid ,
    input awready ,
    input [ADDR_WIDTH-1:0] awaddr ,
    input [DATA_WIDTH-1:0] data_in_fifo ,
    output fifo_empty ,
    output fifo_full ,
    input fifo_push ,
    output fifo_overflow ,
    
    input [3:0] PageSize ,
    output reg [63:0] NS_SIZE ,
    output reg [7:0] BlockSize ,
    output reg [7:0] MDTS ,
    output reg [31:0] MaxTransferSize ,
    
    output reg [ADDR_WIDTH-1:0] addr_latch ,
    output reg [DATA_WIDTH-1:0] data_in ,
    output reg wr_en ,
    input rd_en ,
    output wire [DATA_WIDTH-1:0] data_out_fifo  
    
    );
    //localparam integer declarations

    //regs
    reg [7:0] cur_lbaf ;
    //wires
    wire [11:0] data_count ;
    wire empty_n ;
    wire full_n ;
    wire [DATA_WIDTH-1:0] data_out ;
    //main codes

    assign fifo_empty = ~ empty_n ;
    assign fifo_full = ( data_count > 12'd4090) ? 1'b1 : 1'b0 ;
    assign fifo_overflow = ~ full_n ;
    
    always @ ( posedge aclk )
    begin
        if ( aresetn == 1'b0 )
            addr_latch <= {DATA_WIDTH{1'b0}} ;
        else if ( awvalid && awready )
            addr_latch <= awaddr ;
        else if ( fifo_push )
            addr_latch <= addr_latch + ( DATA_WIDTH/8 ) ;
            
        if ( aresetn == 1'b0 )
            data_in <= {DATA_WIDTH{1'b0}} ; 
        else if ( fifo_push && ( addr_latch[3:0] == 4'hc ) && ( ( addr_latch[15:12] == ACQ_ADDR[15:12] ) || ( addr_latch[15:12] == IOCQ_ADDR[15:12] ) ) )
            data_in <= data_in_fifo ;
        
        if ( aresetn == 1'b0 )
           MDTS <= 8'd0 ;
        else if ( fifo_push && ( addr_latch[15:0] == ( idController_ADDR[15:0] + 16'd76 ) ) )
           MDTS <= data_in_fifo[15:8] ;
       
       if ( aresetn == 1'b0 )
           NS_SIZE <= 64'd0 ;
       else if ( fifo_push && ( addr_latch[15:0] == idNamespace_ADDR[15:0] ) )
          NS_SIZE[31:0] = data_in_fifo ;
       else if ( fifo_push && ( addr_latch[15:0] == idNamespace_ADDR[15:0] + 16'd4 ) )
          NS_SIZE[63:32] = data_in_fifo ;   
      
      if ( aresetn == 1'b0 )
         cur_lbaf <= 8'd0 ;
      else if ( fifo_push && ( addr_latch[15:0] == idNamespace_ADDR[15:0] + 16'd24 ) )
         cur_lbaf <= data_in_fifo[19:16] ;    
       
      if ( aresetn == 1'b0 )
          BlockSize <= 4'h0 ;
      else if ( fifo_push && ( addr_latch[15:0] == idNamespace_ADDR[15:0] + 16'd128 + ( cur_lbaf << 2 ) ) )    
          BlockSize <= data_in_fifo[19:16] - 4'h9 ;  
            
      if ( aresetn == 1'b0 )
         MaxTransferSize <= 13'h0 ;
       else 
         MaxTransferSize <= 1 << ( MDTS + 12 ) ;    
            
       if ( aresetn == 1'b0 )
            wr_en <= 1'b0 ;
       else if ( fifo_push && ( addr_latch[3:0] == 4'hc ) && ( ( addr_latch[15:12] == ACQ_ADDR[15:12] ) || ( addr_latch[15:12] == IOCQ_ADDR[15:12] ) ) )
            wr_en <= 1'b1 ;
       else
            wr_en <= 1'b0 ;                     
    end
    
	ddr3_hls_write_gmem_m_axi_fifo # ( 
	   .DATA_BITS ( DATA_WIDTH ) ,
	   .DEPTH ( 4096 ) ,
	   .DEPTH_BITS ( 12 )
	 ) ddr3_hls_write_gmem_m_axi_fifo_wdata (
	      .sclk ( aclk ) ,
          .reset ( ~ aresetn ),
          .sclk_en ( 1'b1 ) ,
          .empty_n ( empty_n ) ,
          .full_n ( full_n ) ,
          .rdreq ( rd_en ) ,
          .wrreq ( wr_en ) ,
          .data_count ( data_count ) ,
          .q ( data_out_fifo ) ,
          .data ( data_in )
	 ) ;
endmodule
