`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/23 10:39:16
// Design Name: 
// Module Name: nvme_init
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


module nvme_init #(
	parameter IDENTIFY_CONTROLLER = 32'd1 ,
	parameter IDENTIFY_NAMESPACE_0 = 32'd2 ,
	parameter IDENTIFY_NAMESPACE_1 = 32'd3 ,
	parameter CREATE_IO_QUEUES_0 = 32'd4 ,
	parameter CREATE_IO_QUEUES_1 = 32'd5
)(
	input clk_in ,
	input resetb ,
	input init_start ,
	
	// output reg keyhole_control ,
	// output reg [31:0]addr_keyhole ,
	// input [31:0] dinb ,
	output [31:0] nsid ,
	
	output reg [31:0] config_data ,
	input seq_tail_done_ack ,
	input seq_tail_done ,
	input cmd_complete ,
	input cmd_complete_ack ,
	output reg init_finish ,	
	output reg init_busy  
    );
    //localparam integer declarations	
    localparam S_IDLE = 5'b00001 ;
    localparam S_IDENTIFY_CONTROLLER = 5'b00010 ;
    localparam S_IDENTIFY_NAMESPACE = 5'b00100 ;
    localparam S_CREATE_IO_QUEUES = 5'b01000 ;
    localparam S_INIT_DONE = 5'b10000 ;
    //regs
    reg init_start_d0 ;
    reg init_start_d1 ;
    
    reg keyhole_control_d0 ;
    
    reg init_start_pulse ;
    
    reg [4:0] state ;
    reg [4:0] next_state ;
    
    reg [1:0] namespace_cnt ;
    reg io_cnt ;
    
    //wires
    
    //main codes
    
	assign nsid = 1'b1 ;

    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 ) begin
    		init_start_d0 <= 1'b0 ;
    		init_start_d1 <= 1'b0 ;
    	end
    	else begin
    		init_start_d0 <= init_start ;
    		init_start_d1 <= init_start_d0 ;
    	end
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 )
    		state <= S_IDLE ;
    	else
    		state <= next_state ;
    end
    
    always @ ( * )
    begin
    	if ( resetb == 1'b1 )
    		next_state = S_IDLE ;
    	else
    		case ( state )
    			S_IDLE :
    				begin
    					if ( init_start_pulse )
    						next_state = S_IDENTIFY_CONTROLLER ;
    					else
    						next_state = S_IDLE ;
    				end
    			S_IDENTIFY_CONTROLLER :
    				begin
    					if ( cmd_complete && cmd_complete_ack )
    						next_state = S_IDENTIFY_NAMESPACE ;
    					else
    						next_state = S_IDENTIFY_CONTROLLER ;
    				end
    			S_IDENTIFY_NAMESPACE :	
    				begin
    					if ( cmd_complete && cmd_complete_ack ) 
    						next_state = S_CREATE_IO_QUEUES ;
    					else
    						next_state = S_IDENTIFY_NAMESPACE ;
    				end
    		  S_CREATE_IO_QUEUES :
    		  	   begin
    		  	   		if ( ( cmd_complete && cmd_complete_ack ) && ( io_cnt == 1'b1 ) )
    		  	   			next_state = S_INIT_DONE ;
    		  	   		else
    		  	   			next_state = S_CREATE_IO_QUEUES ;
    		  	   end	
    		 S_INIT_DONE :
    		 	begin
    		 		next_state = S_IDLE ;	
    		 	end
    		 default : ;
    	endcase	 
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 )
    		init_start_pulse <= 1'b0 ;
    	else if ( ( init_start_d0 == 1'b1 ) && ( init_start_d1 == 1'b0 ) )
    		init_start_pulse <= 1'b1 ;
    	else
    		init_start_pulse <= 1'b0 ;
    	
    	if ( resetb == 1'b1 )
    		io_cnt <= 1'b0 ;
    	else if ( ( state == S_CREATE_IO_QUEUES ) && ( cmd_complete && cmd_complete_ack ) )
    	 	io_cnt <= ~ io_cnt ;	
    	else if ( state != S_CREATE_IO_QUEUES )
    		io_cnt <= 1'b0 ;
    		
    	if ( resetb == 1'b1 )
    		init_finish <= 1'b0 ;
    	else if ( ( next_state == S_IDLE ) && ( state == S_INIT_DONE ) )
    		init_finish <= 1'b1 ;
    	else
    		init_finish <= 1'b0 ;
    	
    	if ( resetb == 1'b1 )
    		init_busy <= 1'b0 ;
    	else if ( state != S_IDLE )
    		init_busy <= 1'b1 ;
    	else
    		init_busy <= 1'b0 ;	
    		
    	if ( resetb == 1'b1 )
    		config_data <= 32'd0 ;
    	else if ( next_state == S_IDENTIFY_CONTROLLER  ) 
    		config_data <= IDENTIFY_CONTROLLER ;
    	else if ( next_state == S_IDENTIFY_NAMESPACE )
    		config_data <= IDENTIFY_NAMESPACE_1 ;
    	else if ( ( next_state == S_CREATE_IO_QUEUES ) && ( io_cnt == 1'b0 ) )
    		config_data <= CREATE_IO_QUEUES_0 ;
    	else if ( ( next_state == S_CREATE_IO_QUEUES ) && ( io_cnt == 1'b1 ) )
    		config_data <= CREATE_IO_QUEUES_1 ;
		 		
    end
    
endmodule
