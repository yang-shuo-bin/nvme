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


module check_acq_phase#(
	parameter SQE_BASE_ADDRESS = 32'h0000_0000 ,
    parameter CQE_BASE_ADDRESS = 32'h0000_1000 ,
    parameter IOSQ_BASE_ADDRESS = 32'h0000_2000 ,
    parameter IOCQ_BASE_ADDRESS = 32'h0000_3000 
) (
	input clk_in ,
	input resetb ,
	
	input write_start ,
	output reg write_start_ack ,
	
	input read_start ,
	output reg read_start_ack ,
	
    input is_io_queue ,
	
	input [7:0] max_completion ,
	input iocq_read_start ,

	input [7:0] admin_opc ,
	input [7:0] PSDT_FUSE ,
	input [15:0] cid ,
	input [31:0] nsid ,
	input [63:0] MPTR ,
	input [63:0] PRP1 ,
	input [63:0] PRP2 ,
	input [31:0] CDW10 ,
	input [31:0] CDW11 ,
	input [31:0] CDW12 ,
	input [31:0] CDW13 ,
	input [31:0] CDW14 ,
	input [31:0] CDW15 ,
	
	output reg [7:0] iocq_head_cnt_out ,
	output reg [15:0] admin_create_queue_cnt ,
	output reg [15:0] io_create_queue_cnt ,
	output reg [15:0] admin_complete_queue_cnt ,
	output reg [15:0] io_complete_queue_cnt ,
	
  	output reg [31:0] doutb ,
	output [31:0] addrb ,
	input [31:0] dinb ,
	output [3:0] web ,
	output enb ,
	
	output reg [15:0] seq_tail_local ,
	input     seq_tail_done_ack ,
	output reg seq_tail_done ,
	output reg [15:0] acq_head_local_out ,
	input      acq_head_done_ack ,
	output reg acq_head_done ,
	
	output reg [15:0] iosq_tail_local ,
	input     iosq_tail_done_ack ,
	output reg iosq_tail_done ,
	output reg [15:0] iocq_head_local_out ,
	input      iocq_head_done_ack ,
	output reg iocq_head_done 
    );
    //localparam integer declarations
    localparam  S_IDLE = 7'b000_0001 ;
	localparam  S_PACK_HEAD = 7'b000_0010 ;
	localparam  S_RESERVE_MODE = 7'b000_0100 ;
	localparam  S_CDW = 7'b000_1000 ;
	localparam S_READ_STATUS = 7'b001_0000 ;
	localparam S_TIME_OUT = 7'b010_0000 ;
	localparam S_ERR = 7'b100_0000 ;
    //regs
	reg [6:0] state ;
	reg [6:0] next_state ;

	reg [31:0] write_addr ;
    
    reg read_start_d0 ;
    reg read_start_d1 ;
    
    reg [31:0] cnt ;
    
    reg read_start_pulse ;
    
    reg [1:0] idle_cnt ;
    
	reg write_start_d0 ;
	reg write_start_d1 ;
    
	reg write_start_pulse ;
    
    reg is_io_queue_d0 ;
    reg is_io_queue_d1 ;
   
	reg [3:0] counter ;
	  
	reg acq_head_done_tmp ;  
    reg iocq_head_done_tmp ;  	  
	  
	reg [7:0] seq_tail_local_d0 ;
	reg [7:0] iosq_tail_local_d0 ;
	
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
    
    
    assign addrb = ( next_state != S_READ_STATUS ) ? write_addr : ( is_io_queue ) ? IOCQ_BASE_ADDRESS + ( iocq_head_local << 4 ) + 32'd12 : CQE_BASE_ADDRESS + ( acq_head_local << 4 ) + 32'd12 ;
	assign web = ( ( state != S_READ_STATUS ) && ( state != S_IDLE ) && ( state != S_TIME_OUT ) ) ? 4'hf : 4'h0 ;
    assign enb = ( ~ is_io_queue ) ? 1'b1 : ( ( state == S_IDLE ) && ( state == S_TIME_OUT ) ) ? 1'b0 : 1'b1 ;
    
	always @ ( posedge clk_in )
	begin
		case ( { state , counter } )
		    11'b00000010001 : doutb <= { cid , PSDT_FUSE , admin_opc } ;
		    11'b00000100001 : doutb <= nsid ;
			11'b00000100010 : doutb <= 32'd0 ;
			11'b00001000001 : doutb <= 32'd0;
			11'b00001000010 : doutb <= MPTR[31:0] ;
			11'b00001000011 : doutb <= MPTR[63:32] ;
			11'b00001000100 : doutb <= PRP1[31:0] ;
			11'b00001000101 : doutb <= PRP1[63:32] ;
			11'b00001000110 : doutb <= PRP2[31:0] ;
			11'b00001000111 : doutb <= PRP2[63:32] ;
			11'b00001001000 : doutb <= CDW10 ;
			11'b00010000001 : doutb <= CDW11 ;
			11'b00010000010 : doutb <= CDW12 ;
			11'b00010000011 : doutb <= CDW13 ;
			11'b00010000100 : doutb <= CDW14 ;
			11'b00010000101 : doutb <= CDW15 ;
			default : ;
		endcase
	end

	always @ ( posedge clk_in )
	begin
		if ( resetb == 1'b1 ) begin
			write_start_d0 <= 1'b0 ;
			write_start_d1 <= 1'b0 ;
		end
		else begin
			write_start_d0 <= write_start ;
			write_start_d1 <= write_start_d0 ;
		end
		
		if ( resetb == 1'b1 ) begin
		    is_io_queue_d0 <= 1'b0 ;
		    is_io_queue_d1 <= 1'b0 ;
		end
		else begin
		   is_io_queue_d0 <= is_io_queue ;
		   is_io_queue_d1 <= is_io_queue_d0 ;
		end
		
		if ( resetb == 1'b1 ) begin
		    read_start_d0 <= 1'b0 ;
		    read_start_d1 <= 1'b0 ;
		end
		else begin
		    read_start_d0 <= read_start ;
		    read_start_d1 <= read_start_d0 ;
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
		if ( resetb == 1'b1 ) begin
			next_state = S_IDLE ;
		end
		else begin
			case ( state )
				S_IDLE :
					begin
						if ( write_start_pulse == 1'b1 )
							next_state = S_PACK_HEAD ;
					   else if ( ( iocq_head_cnt < max_completion ) && ( ~ finish_flag ) && ( iocq_read_start ) && ( idle_cnt == 2'd3 ) )
					   		next_state = S_READ_STATUS ;
					   else if ( read_start_pulse == 1'b1 )
					       next_state = S_READ_STATUS ;
						else
							next_state = S_IDLE ;
					end
				S_PACK_HEAD :
					begin
						if ( counter == 4'd2 )
							next_state = S_RESERVE_MODE ;
						else
							next_state = S_PACK_HEAD ;
					end
				S_RESERVE_MODE :
					begin
						if ( counter == 4'd8 )
							next_state = S_CDW ;
						else
							next_state = S_RESERVE_MODE ;
					end
				S_CDW :
					begin
						if ( counter == 4'd6 )
							next_state = S_IDLE ;
						else 
							next_state = S_CDW ;	
					end
			   S_READ_STATUS :
			      begin
			          if ( rec_flag  )
			             next_state = S_IDLE ;
			          else if ( ( cnt == 32'd5 ) && is_io_queue )
			             next_state = S_TIME_OUT ;
			          else if ( cnt == 32'd249_999_99 )
			             next_state = S_ERR ;
			          else
			             next_state = S_READ_STATUS ;
			      end
			   S_ERR :
			     begin
			         next_state = S_ERR ;
			     end
			   S_TIME_OUT :
			     begin
			         next_state = S_IDLE ;
			     end   
				default : ;
			endcase
		end
	end

	always @ ( posedge clk_in )
	begin
		if ( resetb == 1'b1 )
			write_start_pulse <= 1'b0 ;
		else if ( ( write_start == 1'b1 ) && ( write_start_ack == 1'b1 ) )
			write_start_pulse <= 1'b1 ;
		else	
			write_start_pulse <= 1'b0 ;
       
        if ( resetb == 1'b1 )
            write_start_ack <= 1'b0 ;
        else if ( ( write_start == 1'b1 ) && ( next_state == S_IDLE ) )
            write_start_ack <= 1'b1 ;
        else if ( write_start == 1'b0 )
            write_start_ack <= 1'b0 ;
        
       if ( resetb == 1'b1 )
            read_start_pulse <= 1'b0 ;
       else if ( ( read_start == 1'b1 ) && ( read_start_ack == 1'b1 ) )
            read_start_pulse <= 1'b1 ;
       else
            read_start_pulse <= 1'b0 ; 
        
        if ( resetb == 1'b1 )
            read_start_ack <= 1'b0 ;
        else if ( ( read_start == 1'b1 ) && ( next_state == S_IDLE ) )
            read_start_ack <= 1'b1 ;
         else 
            read_start_ack <= 1'b0 ;
        
		if ( resetb == 1'b1 )
			counter <= 4'd1 ;
		else if ( ( next_state != state ) && ( next_state != S_READ_STATUS ) )
			counter <= 4'd1 ;
		else if ( ( next_state != S_IDLE ) && ( next_state != S_READ_STATUS ) )
			counter <= counter + 4'd1 ;
        
        if ( resetb == 1'b1 )
            idle_cnt <= 2'b00 ;
        else if ( state == S_IDLE  )
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
			seq_tail_local <= 4'h0 ;
		else if ( ( next_state == S_IDLE ) && ( state == S_CDW ) && ( ~ is_io_queue ) )
			if ( seq_tail_local == 8'h0f )
				seq_tail_local <= 8'h0 ;
			else
				seq_tail_local <= seq_tail_local + 8'h1 ;

		if ( resetb == 1'b1 )
			seq_tail_local_d0 <= 4'h0 ;
		else 
			seq_tail_local_d0 <= seq_tail_local ;

       if ( resetb == 1'b1 )
			iosq_tail_local <= 4'h0 ;
		else if ( ( next_state == S_IDLE ) && ( state == S_CDW ) && ( is_io_queue ) )
			if ( iosq_tail_local == 8'h3f )
				iosq_tail_local <= 8'h0 ;
			else
				iosq_tail_local <= iosq_tail_local + 8'h1 ;

		if ( resetb == 1'b1 )
			iosq_tail_local_d0 <= 4'h0 ;
		else 
			iosq_tail_local_d0 <= iosq_tail_local ;

		if ( resetb == 1'b1 )
			write_addr <= SQE_BASE_ADDRESS ;
        else if ( is_io_queue_d0 && ( ~ is_io_queue_d1 ) )	
            write_addr <= IOSQ_BASE_ADDRESS ;
        else if ( ( ~ is_io_queue_d0 ) && is_io_queue_d1 )
            write_addr <= SQE_BASE_ADDRESS ;  
        else if ( ( seq_tail_local == 8'h0 ) && ( seq_tail_local_d0 == 8'h0f ) )
			write_addr <= SQE_BASE_ADDRESS ;
        else if ( ( iosq_tail_local == 8'h0 ) && ( iosq_tail_local_d0 == 8'h3f ) )
			write_addr <= IOSQ_BASE_ADDRESS ;	    
		else if ( ( state != S_IDLE ) && ( state != S_READ_STATUS ) && ( state != S_TIME_OUT ) && ( state != S_ERR ) )
			write_addr <= write_addr + 32'd4 ;
			
	  if ( resetb == 1'b1 )
	       admin_create_queue_cnt <= 16'd0 ;
	  else if ( seq_tail_done_ack && seq_tail_done )
	       admin_create_queue_cnt <= admin_create_queue_cnt + 16'd1 ;	
	   
	  if ( resetb == 1'b1 )
	       io_create_queue_cnt <= 16'd0 ;
	  else if ( iosq_tail_done_ack && iosq_tail_done )
	       io_create_queue_cnt <= io_create_queue_cnt + 16'd1 ;	    
					
	   if ( resetb == 1'b1 )
	       seq_tail_done <= 1'b0 ;	  
	   else if ( ( next_state == S_IDLE ) && ( state == S_CDW ) && ( ~ is_io_queue ) )		
	       seq_tail_done <= 1'b1 ;
	   else  if ( seq_tail_done_ack )
	       seq_tail_done <= 1'b0 ;
	      
	   	if ( resetb == 1'b1 )
	       iosq_tail_done <= 1'b0 ;	  
	   else if ( ( next_state == S_IDLE ) && ( state == S_CDW ) && ( is_io_queue ) )		
	       iosq_tail_done <= 1'b1 ;
	   else  if ( iosq_tail_done_ack )
	       iosq_tail_done <= 1'b0 ;   
	       
	end

    always @ ( posedge clk_in )
    begin
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
			iocq_head_cnt <= 8'd0 ;
	   else if ( iocq_head_done_tmp )
		    iocq_head_cnt <= 8'd0 ;		
		else if ( ( next_state == S_IDLE ) && ( state == S_READ_STATUS ) && is_io_queue )
			iocq_head_cnt <= iocq_head_cnt + 8'd1 ;
        
        if ( resetb == 1'b1 )
            iocq_head_cnt_out <= 8'd0 ;
         else if ( ( iocq_head_done_tmp ) && ( iocq_head_cnt > 8'd0 ) )
            iocq_head_cnt_out <= iocq_head_cnt ;
        
		if ( resetb == 1'b1 )
			finish_flag <= 1'b0 ;
		else if ( iocq_head_done_tmp )
		   finish_flag <= 1'b1 ;
		else if ( ( next_state == S_TIME_OUT ) && ( state == S_READ_STATUS ) && ( iocq_head_cnt > 8'd0 ) )
			finish_flag <= 1'b1 ;
		else if ( ( next_state == S_PACK_HEAD ) && ( state == S_IDLE ) && ( is_io_queue ) )
			finish_flag <= 1'b0 ;

    	if ( resetb == 1'b1 )
    		iocq_head_local <= 8'd0 ;
    	else if ( ( rec_flag ) && ( state == S_READ_STATUS ) && is_io_queue )
			if ( iocq_head_local == 8'h3f )
				iocq_head_local <= 8'd0 ;
			else
    			iocq_head_local <= iocq_head_local + 8'd1 ;
    		
    	if ( resetb == 1'b1 )
    	   iocq_head_local_d0 <= 4'd0 ;
    	else 
    	   iocq_head_local_d0 <= iocq_head_local ;   
    		
    	if ( resetb == 1'b1 )
    	   dinb_tmp <= 16'd0 ;
    	else if ( state == S_READ_STATUS )
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
    	else if ( ( iocq_head_local == 8'h0 ) && ( iocq_head_local_d0 == 8'h3f ) && ( is_io_queue ) )
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
    	   io_complete_queue_cnt <= 16'd0 ;
    	else if ( iocq_head_done_tmp )
    	   io_complete_queue_cnt <= io_complete_queue_cnt + iocq_head_cnt ;
    		
    	if ( resetb == 1'b1 )
    		iocq_head_done_tmp <= 1'b0 ;
    	else if ( ( next_state == S_IDLE ) && ( state == S_TIME_OUT ) && ( iocq_head_cnt != 8'd0 ) )
    		iocq_head_done_tmp <= 1'b1 ;
    	else if ( ( next_state == S_IDLE ) && ( iocq_head_cnt == max_completion ) )	
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
        else if ( iocq_head_done_tmp )
            iocq_head_local_out <= iocq_head_local ;   	     	
            		
    end


endmodule
