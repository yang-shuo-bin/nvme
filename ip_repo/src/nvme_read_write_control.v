`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/05 17:54:25
// Design Name: 
// Module Name: nvme_read_control
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


module nvme_read_write_control # ( 
    parameter PRPLIST_HEAP = 32'h44a0_4000 ,
    parameter BLOCK_SIZE_EXP = 16 ,
    parameter DDR_PAGE_SIZE_EXP = 12 ,
    parameter IO_SIZE = 16'h003f ,
    parameter LBA_SIZE_EXP = 9
) (
	input clk_in ,
	input resetb ,
	
	input init_busy ,
	
	input read_start ,
	output reg read_start_ack ,
	
	input [63:0] destLBA_in ,
	input [63:0] bytesToRead_or_Write ,
	output reg [63:0] ReadsrcLBA_out ,
	output reg NVMERead_out ,
	
	output reg read_done ,
	input  read_done_ack ,
	
	input write_start ,
	output reg write_start_ack ,
	
	output reg [63:0] WritedestLBA_out ,
	output reg NVMEWrite_out ,
	
	output reg write_done ,
	input write_done_ack ,
	
	output reg [63:0] prp_list_head ,
	
	output reg [63:0] speed_cnt ,
	output reg [31:0] speed_max ,
	output reg [31:0] speed_min ,
	output reg [31:0] speed_cnt_latch ,
	output reg flag ,
	output reg [31:0] wait_min ,
	output reg [31:0] wait_max ,
	output reg [63:0] block_cnt ,
	
	output reg [63:0] numLBA_out ,	
	
	input [15:0] io_create_queue_cnt ,
	input [15:0] io_complete_queue_cnt ,
	output reg iocq_read_start ,
	
	input iocq_head_done_ack ,
	input iocq_head_done ,
	input iosq_tail_done_ack ,
	input iosq_tail_done 
    );
    //lcoalparam integer declarations
    localparam S_IDLE = 10'b00_0000_0001 ;
    localparam S_REG_CONFIG = 10'b00_0000_0010 ;
    localparam S_GET_PAR = 10'b00_0000_0100 ;
    localparam S_GEN_PRP = 10'b00_0000_1000 ;
    localparam S_SET_PAGE = 10'b00_0001_0000 ;
    localparam S_SET_LBA = 10'b00_0010_0000 ;
    localparam S_TRANSFER_DATA = 10'b00_0100_0000 ;
    localparam S_WAIT = 10'b00_1000_0000 ;
    localparam S_PRP_DONE = 10'b01_0000_0000 ;
    localparam S_DONE = 10'b10_0000_0000 ;
    //regs
    reg [9:0] next_state ;
    reg [9:0] state ;
    
    reg start_pulse ;
    
    reg [31:0] page_cnt ;
    reg  lba_cnt ;
    
    reg [31:0] ddr_page_num ;

    reg read_start_latch ;
    reg write_start_latch ;
    
    reg [63:0] numLBA ;
    
    reg [63:0] lbaPerBlock ;
    reg [31:0] time_cnt ;
    reg [31:0] wait_cnt ;
    
    reg [31:0] wait_cnt_latch ;
    
    //wires
    
    //main codes
    
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
   					if ( start_pulse == 1'b1 )
   						next_state = S_REG_CONFIG ;
   					else
   						next_state = S_IDLE ;	
   				end
   			S_REG_CONFIG :
   				begin
   					next_state = S_GET_PAR ;
   				end
   			S_GET_PAR :
   				begin
   				   if ( ( ( bytesToRead_or_Write >> BLOCK_SIZE_EXP ) > 0 ) ) 
   			          next_state = S_TRANSFER_DATA ;
   			      else 
   					  next_state = S_DONE ;   
   				end	
   			S_SET_PAGE :
   			   begin
   			          next_state = S_TRANSFER_DATA ;
   			   end	
   			S_SET_LBA :
   			  begin
                    next_state = S_TRANSFER_DATA ;
              end   
   			S_TRANSFER_DATA :
   				begin
   					if ( ( ( io_create_queue_cnt - io_complete_queue_cnt ) >= 8'h3e ) && ( iosq_tail_done && iosq_tail_done_ack ) )
   						next_state = S_WAIT ;
   					else if ( iosq_tail_done && iosq_tail_done_ack )
   					    next_state = S_DONE ;	
   					else
   						next_state = S_TRANSFER_DATA ;
   				end
   			S_WAIT :
   				begin
   					if ( iocq_head_done && iocq_head_done_ack )
   						next_state = S_DONE ;
   					else 
   						next_state = S_WAIT ;
   				end	
   			S_DONE :
   				begin
   					if ( block_cnt < ( bytesToRead_or_Write >> BLOCK_SIZE_EXP ) )
   						next_state = S_GET_PAR ;
   					else if ( ( page_cnt < ( bytesToRead_or_Write[BLOCK_SIZE_EXP-1:0] >> DDR_PAGE_SIZE_EXP ) ) ) 
   					    next_state = S_SET_PAGE ;
   					else if ( ( bytesToRead_or_Write[DDR_PAGE_SIZE_EXP-1:0] > 0 ) && ( lba_cnt == 1'b0 ) )
   					    next_state = S_SET_LBA ;        
   					else 
   						next_state = S_IDLE ;	
   				end
   			default : ;
   		endcase
   end
   
   always @ ( posedge clk_in )
   begin
   		if ( resetb == 1'b1 )
   			start_pulse <= 1'b0 ;
   		else if ( ( read_start && read_start_ack ) || ( write_start && write_start_ack ) )
   			start_pulse <= 1'b1 ;
   		else 
   			start_pulse <= 1'b0 ;
   			
   		if ( resetb == 1'b1 )
   			read_start_ack <= 1'b0 ;
   		else if ( read_start && ( next_state == S_IDLE ) && ( ~ init_busy ) )
   			read_start_ack <= 1'b1 ;
   		else
   			read_start_ack <= 1'b0 ;
   			
   		if ( resetb == 1'b1 )
   			write_start_ack <= 1'b0 ;
   		else if ( write_start && ( next_state == S_IDLE ) && ( ~ init_busy ) )	
   			write_start_ack <= 1'b1 ;
   		else
   			write_start_ack <= 1'b0 ;
   		
   		if ( resetb == 1'b1 )
   			write_start_latch <= 1'b0 ;
   		else if ( write_start && write_start_ack )
   			write_start_latch <= 1'b1 ;
   		else if ( ( next_state == S_IDLE ) && ( state == S_DONE ) ) 
   			write_start_latch <= 1'b0 ;	
   				
   		if ( resetb == 1'b1 )
   			read_start_latch <= 1'b0 ;
   		else if ( read_start && read_start_ack )
   			read_start_latch <= 1'b1 ;
   		else if ( ( next_state == S_IDLE ) && ( state == S_DONE ) )  
   			read_start_latch <= 1'b0 ;		
   		
   		if ( resetb == 1'b1 )
   			lbaPerBlock <= 64'd0 ;
   		else if ( next_state == S_GET_PAR )
   			lbaPerBlock <= ( 1 << BLOCK_SIZE_EXP ) >> LBA_SIZE_EXP ;
   		else if ( next_state == S_SET_PAGE )
   			lbaPerBlock <= ( 1 << DDR_PAGE_SIZE_EXP ) >> LBA_SIZE_EXP ; 
   		else if ( next_state == S_SET_LBA )    
   		    lbaPerBlock <= bytesToRead_or_Write[DDR_PAGE_SIZE_EXP-1:LBA_SIZE_EXP] ;	
   		
   		if ( resetb == 1'b1 )
   		   read_done <= 1'b0 ;
   		else if ( ( next_state == S_IDLE ) && ( state == S_DONE ) && read_start_latch )
   		   read_done <= 1'b1 ;
   		else if ( read_done_ack )
   		   read_done <= 1'b0 ;
   		   
   	    if ( resetb == 1'b1 )
   		   write_done <= 1'b0 ;
   		else if ( ( next_state == S_IDLE ) && ( state == S_DONE ) && write_start_latch )
   		   write_done <= 1'b1 ;
   		else if ( write_done_ack )
   		   write_done <= 1'b0 ;	   
   		
   		if ( resetb == 1'b1 )
   		   iocq_read_start <= 1'b0 ;
   		else if ( next_state == S_WAIT )
   		   iocq_read_start <= 1'b1 ;
   		else
   		   iocq_read_start <= 1'b0 ;
   		
   		if ( resetb == 1'b1 )
   			block_cnt <= 32'd0 ;
   		else if ( ( next_state == S_DONE ) && ( next_state != state ) )
   			block_cnt <= block_cnt + 32'd1 ;
   		else if ( next_state == S_IDLE )
   			block_cnt <= 32'd0 ;	
   		
   		if ( resetb == 1'b1 )
   		   page_cnt <= 32'd0 ;
   		else if ( ( next_state == S_SET_PAGE ) && ( state == S_DONE ) )
   		   page_cnt <= page_cnt + 32'd1 ;
   		else if ( state == S_IDLE )
   		   page_cnt <= 32'd0 ;
   		   
   		if ( resetb == 1'b1 )
   		   lba_cnt <= 1'b0 ;
   		else if ( ( next_state == S_SET_LBA ) && ( state == S_DONE ) )
   		   lba_cnt <= 1'b1 ;
   		else if ( state == S_IDLE )
   		   lba_cnt <= 1'b0 ;
   			
   		if ( resetb == 1'b1 )
   			ReadsrcLBA_out <= 64'd0 ;
   		else if ( read_start && read_start_ack )
   			ReadsrcLBA_out <= destLBA_in ;
   		else if ( ( next_state != state ) && ( state == S_TRANSFER_DATA ) && ( read_start_latch ) )
   			ReadsrcLBA_out <= ReadsrcLBA_out + lbaPerBlock ;
   			
   		if ( resetb == 1'b1 )
   			WritedestLBA_out <= 64'd0 ;
   		else if ( write_start && write_start_ack )
   			WritedestLBA_out <= destLBA_in ;
   		else if ( ( next_state != state ) && ( state == S_TRANSFER_DATA ) &&  ( write_start_latch ) )
   			WritedestLBA_out <= WritedestLBA_out + lbaPerBlock ;
   		
   		if ( resetb == 1'b1 )
   		   numLBA_out <= 64'd0 ;
   		else if ( next_state == S_GET_PAR )
   		   numLBA_out <= ( 1 << BLOCK_SIZE_EXP ) >> LBA_SIZE_EXP ;
   		else if ( next_state == S_SET_PAGE )
   		   numLBA_out <= ( 1 << DDR_PAGE_SIZE_EXP ) >> LBA_SIZE_EXP ;
   		else if ( next_state == S_SET_LBA )
   		   numLBA_out <= bytesToRead_or_Write[DDR_PAGE_SIZE_EXP-1:LBA_SIZE_EXP] ;	            
   		
   		if ( resetb == 1'b1 )
   		   NVMERead_out <= 1'b0 ;
   	   else if ( ( next_state == S_TRANSFER_DATA ) && ( ( state == S_GET_PAR ) || ( state == S_SET_PAGE ) || ( state == S_SET_LBA ) ) && ( read_start_latch ) )
   	      NVMERead_out <= 1'b1 ;
   	   else 
   	      NVMERead_out <= 1'b0 ;  
   	      
   	    if ( resetb == 1'b1 )
   		   NVMEWrite_out <= 1'b0 ;
   	   else if ( ( next_state == S_TRANSFER_DATA ) && ( ( state == S_GET_PAR ) || ( state == S_SET_PAGE ) || ( state == S_SET_LBA ) ) && ( write_start_latch ) )
   	      NVMEWrite_out <= 1'b1 ;
   	   else 
   	      NVMEWrite_out <= 1'b0 ;     
   		
   		if ( resetb == 1'b1 )
   		   time_cnt <= 32'd0 ;
   		else if ( time_cnt == 32'd249_999_999 )
   		   time_cnt <= 32'd0 ;
   		else 
   		   time_cnt <= time_cnt + 32'd1 ;   
   		
   		if ( resetb == 1'b1 )
   		   flag <= 1'b0 ;
   		else if ( time_cnt == 32'd249_999_999 )
   		   flag <= 1'b1 ;
   		else 
   		   flag <= 1'b0 ;
   		
   		if ( resetb == 1'b1 )
   		   speed_cnt <= 64'd0 ;
   		else if ( write_start && write_start_ack ) 
   		   speed_cnt <= 64'd0 ;
   		else if ( ( next_state == S_IDLE ) && ( state == S_DONE ) )
   		   speed_cnt <= 64'd0 ;
   		else if ( next_state != S_IDLE )
   		   speed_cnt <= speed_cnt + 64'd1 ;       
   		
   		if ( resetb == 1'b1 )
   		   speed_cnt_latch <= 32'd0 ;
   		else if ( flag == 1'b1 )
   		   speed_cnt_latch <= 32'd0 ;
   		else if ( ( next_state == S_DONE ) && ( next_state != state ) )
   		   speed_cnt_latch <= speed_cnt_latch + 32'd1 ;
   		
   		if ( resetb == 1'b1 )
   		   speed_min <= 32'hffff_ffff ;
   		else if ( ( flag ) && ( speed_min > speed_cnt_latch ) && ( speed_cnt_latch > 32'd0 ) )
   		   speed_min <= speed_cnt_latch ;
   		
   		if ( resetb == 1'b1 )
   		   speed_max <= 32'd0 ;
   		else if ( ( speed_max < speed_cnt_latch ) && ( flag ) )
   		   speed_max <= speed_cnt_latch ;
   		
   		if ( resetb == 1'b1 )
   		   wait_cnt <= 32'd0 ;
   		else if ( state == S_WAIT )
   		   wait_cnt <= wait_cnt + 32'd1 ;
   		else 
   		   wait_cnt <= 32'd0 ;
   		   
   		if ( resetb == 1'b1 )
   		   wait_cnt_latch <= 32'd0 ;
   		else if ( ( next_state == S_DONE ) && ( state == S_WAIT ) )      
   			wait_cnt_latch <= wait_cnt ;
   		
   		if ( resetb == 1'b1 )
   		   wait_max <= 32'd0 ;
   		else if ( wait_max < wait_cnt_latch )
   		   wait_max <= wait_cnt_latch ;
   		 
   		if ( resetb == 1'b1 )
   		   wait_min <= 32'hffff_ffff ;
   		else if ( ( wait_min > wait_cnt_latch ) && ( wait_cnt_latch > 32'd0 ) )
   		   wait_min <= wait_cnt_latch ; 
   			
   		if ( resetb == 1'b1 )
   		   	prp_list_head <= 64'd0 ;
   	    else if ( ( next_state == S_GET_PAR ) && ( BLOCK_SIZE_EXP > DDR_PAGE_SIZE_EXP ) )
   	        prp_list_head <= PRPLIST_HEAP + ( ( io_create_queue_cnt & IO_SIZE ) * ( ( ( 1 << BLOCK_SIZE_EXP ) >> DDR_PAGE_SIZE_EXP ) << 3 ) ) ; 

   end
    
endmodule

