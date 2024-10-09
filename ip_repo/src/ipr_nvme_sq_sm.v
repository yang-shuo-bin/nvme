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


module ipr_nvme_sq_sm # ( 
    parameter IO_SIZE = 16'h003f 
) (
	input clk_in ,
	input resetb ,
	
	input write_start ,
	output reg write_start_ack ,
	
    input is_io_queue ,

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
	
	output reg [15:0] admin_create_queue_cnt ,
	output reg [31:0] io_create_queue_cnt ,
	
  	output reg [31:0] doutb ,
	output wr_en ,
	input  sq_fifo_full ,

	output reg [15:0] seq_tail_local ,
	input     seq_tail_done_ack ,
	output reg seq_tail_done ,
	
	output reg [15:0] iosq_tail_local ,
	input     iosq_tail_done_ack ,
	output reg iosq_tail_done 
    );
    //localparam integer declarations
    localparam  S_IDLE = 4'b0001 ;
	localparam  S_PACK_HEAD = 4'b0010 ;
	localparam  S_RESERVE_MODE = 4'b0100 ;
	localparam  S_CDW = 4'b1000 ;
    //regs
	reg [3:0] state ;
	reg [3:0] next_state ;

    reg [1:0] idle_cnt ;
    
	reg write_start_d0 ;
	reg write_start_d1 ;
    
	reg write_start_pulse ;
   
	reg [3:0] counter ;	  
	  
	reg [7:0] seq_tail_local_d0 ;
	reg [7:0] iosq_tail_local_d0 ;
    
    //wires
    
    //main codes
    
//      ila_2 ila_2 (
//     	.clk ( clk_in ) , // input wire clk
//     	.probe0 ( io_phase ) ,// input wire [31:0] probe0
//     	.probe1 ( cnt ) 
//     );
    
    
    // assign addrb = ( next_state != S_READ_STATUS ) ? write_addr : ( is_io_queue ) ? IOCQ_BASE_ADDRESS + ( iocq_head_local << 4 ) + 32'd12 : CQE_BASE_ADDRESS + ( acq_head_local << 4 ) + 32'd12 ;
	assign wr_en = ( state != S_IDLE ) ? 1'b1 : 1'b0 ;
    // assign enb = ( ( state == S_IDLE ) || ( state == S_TIME_OUT ) ) ? 1'b0 : 1'b1 ;
    
	always @ ( posedge clk_in )
	begin
		case ( { state , counter } )
		    8'b00010001 : doutb <= { cid , PSDT_FUSE , admin_opc } ;
		    8'b00100001 : doutb <= nsid ;
			8'b00100010 : doutb <= 32'd0 ;
			8'b01000001 : doutb <= 32'd0;
			8'b01000010 : doutb <= MPTR[31:0] ;
			8'b01000011 : doutb <= MPTR[63:32] ;
			8'b01000100 : doutb <= PRP1[31:0] ;
			8'b01000101 : doutb <= PRP1[63:32] ;
			8'b01000110 : doutb <= PRP2[31:0] ;
			8'b01000111 : doutb <= PRP2[63:32] ;
			8'b01001000 : doutb <= CDW10 ;
			8'b10000001 : doutb <= CDW11 ;
			8'b10000010 : doutb <= CDW12 ;
			8'b10000011 : doutb <= CDW13 ;
			8'b10000100 : doutb <= CDW14 ;
			8'b10000101 : doutb <= CDW15 ;
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
        else if ( ( write_start == 1'b1 ) && ( next_state == S_IDLE ) && ( ~ sq_fifo_full ) )
            write_start_ack <= 1'b1 ;
        else if ( write_start == 1'b0 )
            write_start_ack <= 1'b0 ;
        
		if ( resetb == 1'b1 )
			counter <= 4'd1 ;
		else if ( next_state != state )
			counter <= 4'd1 ;
		else if ( next_state != S_IDLE )
			counter <= counter + 4'd1 ; 
        
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
			if ( iosq_tail_local == IO_SIZE )
				iosq_tail_local <= 8'h0 ;
			else
				iosq_tail_local <= iosq_tail_local + 8'h1 ;

		if ( resetb == 1'b1 )
			iosq_tail_local_d0 <= 4'h0 ;
		else 
			iosq_tail_local_d0 <= iosq_tail_local ;
			
	  if ( resetb == 1'b1 )
	       admin_create_queue_cnt <= 16'd0 ;
	  else if ( seq_tail_done_ack && seq_tail_done )
	       admin_create_queue_cnt <= admin_create_queue_cnt + 16'd1 ;	
	   
	  if ( resetb == 1'b1 )
	       io_create_queue_cnt <= 32'd0 ;
	  else if ( iosq_tail_done_ack && iosq_tail_done )
	       io_create_queue_cnt <= io_create_queue_cnt + 32'd1 ;	    
					
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


endmodule
