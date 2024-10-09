`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/24 18:41:48
// Design Name: 
// Module Name: bram_arbit
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


module bram_arbit(
	input keyhole_control ,
	input [31:0] addr_keyhole ,
	input [31:0] addr_in ,
	input [3:0] web_in ,

	output [31:0] addr_out ,
	output [3:0] web_out 
    );
   //localparam integer declarations
   
   //regs
   
   //wires
   
   //main codes
   
   assign addr_out = ( keyhole_control ) ? addr_keyhole : addr_in ;
   assign web_out = ( ~ keyhole_control ) ? web_in : 4'h0 ;
    
endmodule
