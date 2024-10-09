`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/30 17:25:20
// Design Name: 
// Module Name: axi_arbit
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


module axi_arbit#( 
	parameter BASE_ADDR_BAR = 32'h0000_0000 
) (
	input clk_in ,
	input areset_n ,
	
	input read_start ,
	input write_start ,
	output reg write_start_ack ,
	output reg read_start_ack ,
	
	output reg [31:0] reg_in_data ,
	input  [31:0] reg_out_data ,
	input  [63:0] reg_out_addr ,
	input  [63:0] reg_in_addr ,
	
	input sys_write_master_ready ,
	output reg sys_write_req ,
	output reg [63:0]sys_write_addr ,
	output reg [31:0]sys_write_data ,
    output reg sys_write_master_done ,
	
	input sys_read_master_ready ,
	output reg sys_read_req ,
	output reg [63:0] sys_read_addr ,
	input [31:0] sys_read_data , 
	input     sys_read_data_valid ,
	output reg sys_read_master_done ,
	
	input [15:0] seq_tail_local ,
	output reg seq_tail_done_ack ,
	input seq_tail_done ,
	input [15:0] acq_head_local ,
	output reg acq_head_done_ack ,
	input acq_head_done ,
	
	input [15:0] iosq_tail_local ,
	output  reg    iosq_tail_done_ack ,
	input       iosq_tail_done ,
	input [15:0] iocq_head_local ,
	output  reg      iocq_head_done_ack ,
	input  iocq_head_done 
    );
    //localparam integer declarations
    localparam S_IDLE = 4'b0001 ;
    localparam S_WRITE = 4'b0010 ;
    localparam S_READ = 4'b0100 ;
    localparam S_DONE = 4'b1000 ;
    //regs
    reg write_start_d0 ;
    reg write_start_d1 ;
    
    reg read_start_d0 ;
    reg read_start_d1 ;
    
    reg sys_write_master_ready_d0 ;
    reg sys_write_master_ready_d1 ;
    
    reg sys_read_master_ready_d0 ;
    reg sys_read_master_ready_d1 ;

    reg sys_write_data_idle ;

    reg [3:0] state ;
    reg [3:0] next_state ;
    //wires
    
    //main codes
    
    always @ ( posedge clk_in )
    begin
    
    	if ( areset_n == 1'b0 ) begin
    		write_start_d0 <= 1'b0 ;
    		write_start_d1 <= 1'b0 ;
    	end
    	else begin
    		write_start_d0 <= write_start ;
    		write_start_d1 <= write_start_d0 ;
    	end
    
    	if ( areset_n == 1'b0 ) begin
    		read_start_d0 <= 1'b0 ;
    		read_start_d1 <= 1'b0 ;
    	end
    	else begin
    		read_start_d0 <= read_start ;
    		read_start_d1 <= read_start_d1 ;
    	end
    		
    	if ( areset_n == 1'b0 ) begin
    		sys_write_master_ready_d0 <= 1'b0 ;
    		sys_write_master_ready_d1 <= 1'b0 ;
    	end	
    	else begin
    		sys_write_master_ready_d0 <= sys_write_master_ready ;	
    		sys_write_master_ready_d1 <= sys_write_master_ready_d0 ;
    	end
    	
    	if ( areset_n == 1'b0 ) begin
    		sys_read_master_ready_d0 <= 1'b0 ;
    		sys_read_master_ready_d1 <= 1'b0 ;
    	end
    	else begin
    		sys_read_master_ready_d0 <= sys_read_master_ready ;
    		sys_read_master_ready_d1 <= sys_read_master_ready_d0 ;
    	end
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( areset_n == 1'b0 )
    		state <= S_IDLE ;
    	else
    		state <= next_state ;
    end
    
    always @ ( * )
    begin
    	if ( areset_n == 1'b0 )
    		next_state = S_IDLE ;
    	else
    		case ( state )
    			S_IDLE :
    				begin
    					if ( write_start && write_start_ack )
    						next_state = S_WRITE ;
    					else if ( read_start && read_start_ack )
    						next_state = S_READ ;
    					else
    						next_state = S_IDLE ;
    				end
    			S_WRITE :
    				begin
    					if ( sys_write_master_done )
    						next_state = S_DONE ;
    					else 
    						next_state = S_WRITE ;
    				end	
    			S_READ :
    				begin
    					if ( sys_read_master_done )
    						next_state = S_DONE ;
    					else
    						next_state = S_READ ;
    				end
    			S_DONE :	
    				begin
    					next_state = S_IDLE ;
    				end
    			default : ;
    		endcase
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( areset_n == 1'b0 )
    		write_start_ack <= 1'b0 ;
    	else if ( write_start && sys_write_master_ready )
    		write_start_ack <= 1'b1 ;
    	else if ( write_start == 1'b0 )
    		write_start_ack <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		read_start_ack <= 1'b0 ;
    	else if ( read_start && sys_read_master_ready )
    		read_start_ack <= 1'b1 ;
    	else if ( read_start == 1'b0 )
    		read_start_ack <= 1'b0 ;
    	
    	if ( areset_n == 1'b0 )
    		sys_write_master_done <= 1'b0 ;
    	else if ( sys_write_master_ready_d0 && ( ~ sys_write_master_ready_d1 ) && ( next_state == S_WRITE ) )	
    		sys_write_master_done <= 1'b1 ;
    	else
    		sys_write_master_done <= 1'b0 ;
    	
    	if ( areset_n == 1'b0 )
    	   sys_write_data_idle <= 1'b1 ;
       else if ( sys_write_master_ready_d0 && ( ~ sys_write_master_ready_d1 ) )
           sys_write_data_idle <= 1'b1 ;	   
       else if ( sys_write_master_ready && ( seq_tail_done || acq_head_done || iosq_tail_done || iocq_head_done ) )
           sys_write_data_idle <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		sys_read_master_done <= 1'b0 ;
    	else if ( sys_read_master_ready_d0 && ( ~ sys_read_master_ready_d1 ) && ( next_state == S_READ ) )
    		sys_read_master_done <= 1'b1 ;
    	else
    		sys_read_master_done <= 1'b0 ;				 
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( areset_n == 1'b0 )
    		seq_tail_done_ack <= 1'b0 ;
    	else if ( sys_write_data_idle && seq_tail_done )
    		seq_tail_done_ack <= 1'b1 ;
    	else if ( seq_tail_done == 1'b0 )
    		seq_tail_done_ack <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		acq_head_done_ack <= 1'b0 ;
    	else if ( sys_write_data_idle && acq_head_done && ( ~ seq_tail_done ) )
    		acq_head_done_ack <= 1'b1 ;
    	else if ( acq_head_done == 1'b0 )
    		acq_head_done_ack <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		iosq_tail_done_ack <= 1'b0 ;
    	else if ( sys_write_data_idle && iosq_tail_done )
    		iosq_tail_done_ack <= 1'b1 ;
    	else if ( iosq_tail_done == 1'b0 )
    		iosq_tail_done_ack <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		iocq_head_done_ack <= 1'b0 ;
    	else if ( sys_write_data_idle && iocq_head_done && ( ~ iosq_tail_done ) )
    		iocq_head_done_ack <= 1'b1 ;			
    	else if ( iocq_head_done == 1'b0 )
    		iocq_head_done_ack <= 1'b0 ;	
    		
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( areset_n == 1'b0 )
    		sys_write_req <= 1'b0 ;
    	else if ( write_start_ack && ( ~ write_start ) )
    		sys_write_req <= 1'b1 ;
    	else if ( seq_tail_done_ack && ( ~ seq_tail_done ) )
    		sys_write_req <= 1'b1 ;
    	else if ( acq_head_done_ack && ( ~ acq_head_done ) )
    		sys_write_req <= 1'b1 ;
    	else if ( iosq_tail_done_ack && ( ~ iosq_tail_done ) )
    		sys_write_req <= 1'b1 ;
    	else if ( iocq_head_done_ack && ( ~ iocq_head_done ) )
    		sys_write_req <= 1'b1 ;
    	else
    		sys_write_req <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		sys_write_data <= 32'd0 ;
    	else if ( write_start && write_start_ack )
    		sys_write_data <= reg_out_data ;
    	else if ( sys_write_data_idle && seq_tail_done )
    		sys_write_data <= { 16'd0 , seq_tail_local } ;
    	else if ( sys_write_data_idle && acq_head_done )
    		sys_write_data <= { 16'd0 , acq_head_local } ; 
    	else if ( sys_write_data_idle && iosq_tail_done )
    		sys_write_data <= { 16'd0 , iosq_tail_local } ;
    	else if ( sys_write_data_idle && iocq_head_done )
    		sys_write_data <= { 16'd0 , iocq_head_local } ;
    	
    	if ( areset_n == 1'b0 )
    		sys_write_addr <= 32'd0 ;
    	else if ( write_start && write_start_ack )
    		sys_write_addr <= reg_out_addr ;
    	else if ( sys_write_data_idle && seq_tail_done )
    		sys_write_addr <= BASE_ADDR_BAR + 32'h00001000 ;
    	else if ( sys_write_data_idle && acq_head_done )
    		sys_write_addr <= BASE_ADDR_BAR + 32'h00001004 ;
    	else if ( sys_write_data_idle && iosq_tail_done )
    		sys_write_addr <= BASE_ADDR_BAR + 32'h00001008 ;
    	else if ( sys_write_data_idle && iocq_head_done )
    		sys_write_addr <= BASE_ADDR_BAR + 32'h0000100c ;		
          
    	if ( areset_n == 1'b0 )
    		sys_read_req <= 1'b0 ;
    	else if ( ( ~ read_start ) && read_start_ack )
    		sys_read_req <= 1'b1 ;
    	else
    		sys_read_req <= 1'b0 ;
    		
    	if ( areset_n == 1'b0 )
    		sys_read_addr <= 32'd0 ;
    	else if ( read_start && read_start_ack )
    		sys_read_addr <= reg_in_addr ;
    		
    	if ( areset_n == 1'b0 )
    		reg_in_data <= 32'd0 ;
    	else if ( sys_read_data_valid )
    		reg_in_data <= sys_read_data ;				
    end
    
endmodule
