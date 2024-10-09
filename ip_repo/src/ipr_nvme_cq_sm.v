`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/21 14:17:40
// Design Name: 
// Module Name: check_acq_phase
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


module ipr_nvme_cq_sm # ( 
    parameter IO_SIZE = 16'h003f
) (
	input clk_in ,
	input resetb ,
	
	input read_start ,
	output reg read_start_ack ,
	
    input is_io_queue ,
	
	output reg [15:0] admin_complete_queue_cnt ,
	output reg [31:0] io_complete_queue_cnt ,
	
    input       cq_fifo_empty ,
	input [31:0] dinb ,
	output reg rd_en ,

	output reg [15:0] acq_head_local_out ,
	input      acq_head_done_ack ,
	output reg acq_head_done ,
	
	output reg [15:0] iocq_head_local_out ,
	input      iocq_head_done_ack ,
	output reg iocq_head_done 
    );
    //localparam integer declarations
    localparam  S_IDLE = 4'b0001 ;
	localparam S_READ_STATUS = 4'b0010 ;
	localparam S_REV = 4'b0100 ;
	localparam S_ERR = 4'b1000 ;
    //regs
	reg [3:0] state ;
	reg [3:0] next_state ;
    
    reg [31:0] cnt ;
    
    reg read_start_pulse ;
    
    reg [1:0] idle_cnt ;
	  
	reg acq_head_done_tmp ;  
    reg iocq_head_done_tmp ;  	  
	
	reg rec_flag ;
	
	reg finish_flag ;

	reg [7:0] iocq_head_cnt ;
    
    reg [15:0] io_cid_last_complete ;
	reg [7:0] acq_head_local ;
    reg [7:0] acq_head_local_d0 ;
    
    reg [7:0] iocq_head_local ;
    reg [7:0] iocq_head_local_d0 ;
    
    reg [15:0] dinb_tmp ;
    
    reg acq_phase ;
    reg io_phase ;
    
    //wires
    
    //main codes
    
//      ila_2 ila_2 (
//     	.clk ( clk_in ) , // input wire clk
//     	.probe0 ( io_phase ) ,// input wire [31:0] probe0
//     	.probe1 ( cnt ) 
//     );
    
	always @ ( posedge clk_in )
	begin
		if ( resetb == 1'b1 ) 
			state <= S_IDLE ;
		else	
			state <= next_state ;
	end

	always @ ( * )
	begin
		if ( resetb == 1'b1 ) begin
			next_state = S_IDLE ;
		end
		else begin
			case ( state )
				S_IDLE :
					begin
                    if ( is_io_queue && ( idle_cnt == 2'd3 ) && ( ~ cq_fifo_empty ) )
					   		next_state = S_READ_STATUS ;
					   else if ( read_start_pulse == 1'b1 ) 
					       next_state = S_READ_STATUS ;
						else
							next_state = S_IDLE ;
					end
			   S_READ_STATUS :
			      begin
			          if ( rec_flag && is_io_queue )
			             next_state = S_REV ;
			          else if ( rec_flag )
			             next_state = S_IDLE ;   
			          else if ( cnt == 32'd5 ) 
			             next_state = S_ERR ;
			          else
			             next_state = S_READ_STATUS ;
			      end
			   S_REV :
			     begin
			         if ( iocq_head_done && iocq_head_done_ack )
			             next_state = S_IDLE ;
			         else
			             next_state = S_REV ;
			     end   
			   S_ERR :
			     begin
			         next_state = S_ERR ;
			     end 
				default : ;
			endcase
		end
	end

    always @ ( posedge clk_in )
    begin
        if ( resetb == 1'b1 )
            read_start_pulse <= 1'b0 ;
       else if ( ( read_start == 1'b1 ) && ( read_start_ack == 1'b1 ) )
            read_start_pulse <= 1'b1 ;
       else
            read_start_pulse <= 1'b0 ; 
        
        if ( resetb == 1'b1 )
            read_start_ack <= 1'b0 ;
        else if ( ( read_start == 1'b1 ) && ( next_state == S_IDLE ) && ( ~ cq_fifo_empty ) && ( ~ is_io_queue ) )
            read_start_ack <= 1'b1 ;
         else 
            read_start_ack <= 1'b0 ;    

    	if ( resetb == 1'b1 )
    		acq_head_local <= 8'd0 ;
    	else if ( ( rec_flag ) && ( state == S_READ_STATUS ) && ( ~ is_io_queue ) )
			if ( acq_head_local == 8'h0f )
				acq_head_local <= 8'd0 ;
			else
    			acq_head_local <= acq_head_local + 8'd1 ;
    		
    	if ( resetb == 1'b1 )
    	   acq_head_local_d0 <= 4'd0 ;
    	else 
    	   acq_head_local_d0 <= acq_head_local ;	

        if ( resetb == 1'b1 )
            idle_cnt <= 2'b00 ;
        else if ( ( state == S_IDLE  ) && ( idle_cnt < 2'b11) )
            idle_cnt <= idle_cnt + 2'b01 ;
        else 
            idle_cnt <= 2'b00 ;    
        
        if ( resetb == 1'b1 )
            cnt <= 32'd0 ;
        else if ( next_state == S_READ_STATUS )
            cnt <= cnt + 32'd1 ;
        else
            cnt <= 32'd0 ;

    	if ( resetb == 1'b1 )
    		iocq_head_local <= 8'd0 ;
    	else if ( ( rec_flag ) && ( state == S_READ_STATUS ) && is_io_queue )
			if ( iocq_head_local == IO_SIZE )
				iocq_head_local <= 8'd0 ;
			else
    			iocq_head_local <= iocq_head_local + 8'd1 ;
    		
    	if ( resetb == 1'b1 )
    	   iocq_head_local_d0 <= 4'd0 ;
    	else 
    	   iocq_head_local_d0 <= iocq_head_local ;   
    	
    	if ( resetb == 1'b1 )
    	   rd_en <= 1'b0 ;
        else if ( ( state == S_IDLE ) && ( next_state == S_READ_STATUS ) )
    	   rd_en <= 1'b1 ;
        else 
           rd_en <= 1'b0 ;
    		
    	if ( resetb == 1'b1 )
    	   dinb_tmp <= 16'd0 ;
    	else if ( rd_en )
    	   dinb_tmp <= dinb[31:16] ;
    	else if ( ~ is_io_queue )
    	   dinb_tmp <= {15'd0,acq_phase} ;
       else 
           dinb_tmp <= {15'd0,io_phase} ;
    	
    	if ( resetb == 1'b1 )
    	   rec_flag <= 1'b0 ;
    	else if ( ( state == S_READ_STATUS ) && ( dinb_tmp == { 15'd0, ( ~ io_phase ) } ) && ( is_io_queue ) && ( rec_flag == 1'b0 ) )
    	   rec_flag <= 1'b1 ;
    	else if ( ( state == S_READ_STATUS ) && ( dinb_tmp == { 15'd0, ( ~ acq_phase ) } ) && ( ~ is_io_queue ) && ( rec_flag == 1'b0 ) )
    	   rec_flag <= 1'b1 ;   
    	else if ( state != S_READ_STATUS ) 
    	   rec_flag <= 1'b0 ;   
    		
    	if ( resetb == 1'b1 )
    	   acq_phase <= 1'b0 ;
    	else if ( ( acq_head_local == 8'h0 ) && ( acq_head_local_d0 == 8'h0f ) && ( ~ is_io_queue ) )
    	   acq_phase <= ~ acq_phase ;	   
    	   
        if ( resetb == 1'b1 )
    	   io_phase <= 1'b0 ;
    	else if ( ( iocq_head_local == 8'h0 ) && ( iocq_head_local_d0 == IO_SIZE ) && ( is_io_queue ) )
    	   io_phase <= ~ io_phase ;	   	   
    	
    	if ( resetb == 1'b1 )
    	   admin_complete_queue_cnt <= 16'd0 ;
    	else if ( acq_head_done_ack && acq_head_done )
    	   admin_complete_queue_cnt <= admin_complete_queue_cnt + 16'd1 ;
    		
    	if ( resetb == 1'b1 )
    		acq_head_done_tmp <= 1'b0 ;
    	else if ( rec_flag && ( state == S_READ_STATUS ) && ( ~ is_io_queue ) )
    		acq_head_done_tmp <= 1'b1 ;
    	else 
    		acq_head_done_tmp <= 1'b0 ;	
    		
    	if ( resetb == 1'b1 )
    	   	io_cid_last_complete <= 16'd0 ;
    	else if ( rec_flag && ( state == S_READ_STATUS ) && is_io_queue )  
    	   	io_cid_last_complete <= dinb[15:0] ;
         
        if ( resetb == 1'b1 )
            acq_head_done <= 1'b0 ;
        else if ( acq_head_done_tmp == 1'b1 )
            acq_head_done <= 1'b1 ;
        else if ( acq_head_done_ack == 1'b1 )
            acq_head_done <= 1'b0 ;
            		
        if ( resetb == 1'b1 )
            acq_head_local_out <= 4'h0 ;
        else if ( acq_head_done_tmp )
            acq_head_local_out <= acq_head_local ;   	
            
        if ( resetb == 1'b1 )
    	   io_complete_queue_cnt <= 32'd0 ;
    	else if ( iocq_head_done_tmp == 1'b1 )
    	   io_complete_queue_cnt <= io_complete_queue_cnt + 32'd1 ;
    		
    	if ( resetb == 1'b1 )
    		iocq_head_done_tmp <= 1'b0 ;
    	else if ( ( next_state == S_REV ) && ( state == S_READ_STATUS ) )
    		iocq_head_done_tmp <= 1'b1 ;
    	else 
    		iocq_head_done_tmp <= 1'b0 ;		
         
        if ( resetb == 1'b1 )
            iocq_head_done <= 1'b0 ;
        else if ( iocq_head_done_tmp == 1'b1 )
            iocq_head_done <= 1'b1 ;
        else if ( iocq_head_done_ack == 1'b1 )
            iocq_head_done <= 1'b0 ;
            		
        if ( resetb == 1'b1 )
            iocq_head_local_out <= 4'h0 ;
        else if ( iocq_head_done_tmp == 1'b1 )
            iocq_head_local_out <= iocq_head_local ;   	     	
            		
    end


endmodule
