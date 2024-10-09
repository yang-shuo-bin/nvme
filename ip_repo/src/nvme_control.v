`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/28 13:18:19
// Design Name: 
// Module Name: nvme_control
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


module nvme_control # ( 
	parameter IDENTIFY_CONTROLLER = 32'd1 ,
	parameter IDENTIFY_NAMESPACE_0 = 32'd2 ,
	parameter IDENTIFY_NAMESPACE_1 = 32'd3 ,
	parameter CREATE_IO_QUEUES_0 = 32'd4 ,
	parameter CREATE_IO_QUEUES_1 = 32'd5 ,
	
	parameter IO_SIZE = 16'h003f ,
	parameter IOSQ_ADDR = 32'ha010_2000 ,
	parameter IOCQ_ADDR = 32'ha010_3000 ,
	parameter idController_ADDR = 32'ha010_4000 ,
	parameter idNamespace_ADDR = 32'ha010_5000 
) (
	input clk_in ,
	input resetb ,
	
	input [31:0] nsid_in ,
	input  IsTrim_in ,
	output reg IsTrim_ack ,
	input  GetSMARTHealth_in ,
	output reg GetSMARTHealth_ack ,
	input  IsFlush_in ,
	output reg IsFlush_ack ,
	input  NVMERead ,
	input  NVMEWrite ,
	input  [63:0]numLBA ,
	
	input is_io_queue ,
	
	output reg [7:0] admin_opc ,
	output  [7:0] PSDT_FUSE ,
	output reg [15:0] cid ,
	output reg [31:0] nsid ,
	output  [63:0] MPTR ,
	output reg [63:0] PRP1 ,
	output reg [63:0] PRP2 ,
	output reg [31:0] CDW10 ,
	output reg [31:0] CDW11 ,
	output reg [31:0] CDW12 ,
	output  [31:0] CDW13 ,
	output  [31:0] CDW14 ,
	output  [31:0] CDW15 ,
	
	input [63:0]WRITE_ADDR ,
	input [63:0]READ_ADDR ,
	input [63:0]PRP_LIST ,
	
	input [63:0]ReadsrcLBA ,
	input [63:0]WritedestLBA ,
	
	input [15:0]admin_create_queue_cnt ,
	input [15:0]admin_complete_queue_cnt ,
	input [15:0]io_create_queue_cnt ,
	input [15:0]io_complete_queue_cnt ,
	
	input write_start_ack ,
	output reg write_start ,
	
	input read_start_ack ,
	output reg read_start ,
	
	input init_finish ,
	input [31:0] config_data ,

	input  seq_tail_done_ack ,
	input seq_tail_done ,
	input acq_head_done_ack ,
	input acq_head_done ,
	
	input iosq_tail_done_ack ,
	input iosq_tail_done ,
	input iocq_head_done_ack ,
	input iocq_head_done
    );
    //localparam integer declarations 
    localparam S_IDLE = 12'b0000_0000_0001 ;
    localparam S_NVME_INIT_WRITE = 12'b0000_0000_0010 ;
    localparam S_NVME_INIT_READ = 12'b0000_0000_0100 ;
    localparam S_WAIT = 12'b0000_0000_1000 ;
    localparam S_IsTrim = 12'b0000_0001_0000 ;
    localparam S_GetSMARTHealth = 12'b0000_0010_0000 ;
    localparam S_IsFlush = 12'b0000_0100_0000 ;
    localparam S_NVME_READ = 12'b0000_1000_0000 ;
    localparam S_NVME_WRITE = 12'b0001_0000_0000 ;
    localparam S_READ_STATUS = 12'b0010_0000_0000 ;
    localparam S_READ_GetSMARTHealth = 12'b0100_0000_0000 ;
    localparam S_BLOCK_STATUS = 12'b1000_0000_0000 ;
    
    localparam iosq = IOSQ_ADDR ;
    localparam iocq = IOCQ_ADDR ;
    localparam idController = idController_ADDR ;
    localparam idNamespace = idNamespace_ADDR ;
    localparam logSMARTHealth = 32'ha0106000 ;
    localparam dsmRange = 32'h10008000 ;
    
    
    //regs
    reg [11:0] next_state ;
    reg [11:0] state ;
    
    reg [31:0] config_data_d0 ;
    reg [31:0] config_data_d1 ;
    reg config_data_pulse ;
    
    reg IsTrim_d0 ;
    reg IsTrim_d1 ;
    reg IsTrim_pulse ;
    
    reg GetSMARTHealth_d0 ;
    reg GetSMARTHealth_d1 ;
    reg GetSMARTHealth_pulse ;
    
    reg IsFlush_d0 ;
    reg IsFlush_d1 ;
    reg IsFlush_pulse ;
    
    reg NVMERead_d0 ;
    reg NVMERead_d1 ;
    reg NVMERead_pulse ;
    
    reg NVMEWrite_d0 ;
    reg NVMEWrite_d1 ;
    reg NVMEWrite_pulse ;
    //wires
    
    //main codes
    
    assign PSDT_FUSE = 8'd0 ;
    assign MPTR = 64'd0 ;
    assign CDW13 = 32'd0 ;
    assign CDW14 = 32'd0 ;
    assign CDW15 = 32'd0 ;
    
    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 ) begin
    		config_data_d0 <= 32'd0 ;
    		config_data_d1 <= 32'd0 ;
    	end
    	else begin 
    		config_data_d0 <= config_data ;
    		config_data_d1 <= config_data_d0 ;	
    	end
    	
    	if ( resetb == 1'b1 ) begin
    		NVMERead_d0 <= 1'b0 ;
    		NVMERead_d1 <= 1'b0 ;
    	end
    	else begin
    		NVMERead_d0 <= NVMERead ;
    		NVMERead_d1 <= NVMERead_d0 ;
    	end
    	
        if ( resetb == 1'b1 ) begin
    		NVMEWrite_d0 <= 1'b0 ;
    		NVMEWrite_d1 <= 1'b0 ;
    	end
    	else begin
    		NVMEWrite_d0 <= NVMEWrite ;
    		NVMEWrite_d1 <= NVMEWrite_d0 ;
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
    					if ( init_finish )
    						next_state = S_WAIT ;
    					else if ( config_data_pulse )
    						next_state = S_NVME_INIT_WRITE ;
    					else 
    						next_state = S_IDLE ;
    				end
    			S_NVME_INIT_WRITE :	
    				begin
    					if ( seq_tail_done_ack && seq_tail_done )
    						next_state = S_NVME_INIT_READ ;
    					else
    						next_state = S_NVME_INIT_WRITE ;
    				end
    			S_NVME_INIT_READ :
    				begin
    					if ( acq_head_done_ack && acq_head_done )
    						next_state = S_IDLE ;
    					else 
    						next_state = S_NVME_INIT_READ ;
    				end
    			S_WAIT :
    				begin
    					if ( IsTrim_pulse ) 
    						next_state = S_IsTrim ;
    					else if ( GetSMARTHealth_pulse )
    						next_state = S_GetSMARTHealth ;
    					else if ( IsFlush_pulse )
    						next_state = S_IsFlush ;
    					else if ( NVMERead_pulse )
    						next_state = S_NVME_READ ;
    					else if ( NVMEWrite_pulse )
    						next_state = S_NVME_WRITE ;
    					else
    						next_state = S_WAIT ;
    				end
    			S_IsTrim :
    				begin
    					if ( iosq_tail_done_ack && iosq_tail_done )
    						next_state = S_READ_STATUS ;
    					else
    						next_state = S_IsTrim ;
    				end
    			S_GetSMARTHealth :
    				begin
    					if ( seq_tail_done_ack && seq_tail_done )
    						next_state = S_READ_GetSMARTHealth ;
    					else 
    						next_state = S_GetSMARTHealth ;
    				end	
    			S_READ_GetSMARTHealth :
    		        begin
    					if ( acq_head_done_ack && acq_head_done )
    						next_state = S_WAIT ;
    					else
    						next_state = S_READ_GetSMARTHealth ;
    				end
    			 S_IsFlush :
    				begin
    					if ( iosq_tail_done_ack && iosq_tail_done )
    						next_state = S_READ_STATUS ;
    					else 
    						next_state = S_IsFlush ;
    				end
    			 S_NVME_READ :
    				begin
    					if ( iosq_tail_done && iosq_tail_done_ack )
    					   next_state = S_BLOCK_STATUS ;	
    					else 
    						next_state = S_NVME_READ ;
    				end
    			  S_NVME_WRITE :
    				begin
    					if ( iosq_tail_done && iosq_tail_done_ack )
    					   next_state = S_BLOCK_STATUS ;		
    					else 
    						next_state = S_NVME_WRITE ;
    				end	
    			S_BLOCK_STATUS :
    			     begin
    			         if ( iocq_head_done_ack && iocq_head_done )
    			             next_state = S_WAIT ;
    			         else if ( NVMERead_pulse )
    			             next_state = S_NVME_READ ;
    			         else if ( NVMEWrite_pulse )
    			             next_state = S_NVME_WRITE ;
    			         else
    			             next_state = S_BLOCK_STATUS ;
    			     end	
    			S_READ_STATUS :
    				begin
    					if ( iocq_head_done_ack && iocq_head_done )
    						next_state = S_WAIT ;
    					else
    						next_state = S_READ_STATUS ;
    				end
    			default : next_state = S_IDLE ;
    		endcase
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 )
    		config_data_pulse <= 1'b0 ;
    	else if ( config_data_d0 != config_data_d1 )
    		config_data_pulse <= 1'b1 ;
    	else
    		config_data_pulse <= 1'b0 ;
    	
    	if ( resetb == 1'b1 )
    	   IsTrim_ack <= 1'b0 ;
       else if ( ( IsTrim_in == 1'b1 ) && ( next_state == S_WAIT ) )
    	   IsTrim_ack <= 1'b1 ;
       else if ( IsTrim_in == 1'b0 )
          IsTrim_ack <= 1'b0 ; 
    	
    	if ( resetb == 1'b1 )
    		IsTrim_pulse <= 1'b0 ;
    	else if ( ( IsTrim_in == 1'b1 ) && ( IsTrim_ack == 1'b1 ) )
    		IsTrim_pulse <= 1'b1 ;
    	else
    		IsTrim_pulse <= 1'b0 ;
    		
      if ( resetb == 1'b1 )
    	   GetSMARTHealth_ack <= 1'b0 ;
       else if ( ( GetSMARTHealth_in == 1'b1 ) && ( next_state == S_WAIT ) )
    	   GetSMARTHealth_ack <= 1'b1 ;
       else if ( GetSMARTHealth_in == 1'b0 )
          GetSMARTHealth_ack <= 1'b0 ; 	
    		
    	if ( resetb == 1'b1 )
    		GetSMARTHealth_pulse <= 1'b0 ;
    	else if ( ( GetSMARTHealth_in == 1'b1 ) && ( GetSMARTHealth_ack == 1'b1 ) )
    		GetSMARTHealth_pulse <= 1'b1 ;
    	else
    		GetSMARTHealth_pulse <= 1'b0 ;
    	
    	if ( resetb == 1'b1 )
    	   IsFlush_ack <= 1'b0 ;
       else if ( ( IsFlush_in == 1'b1 ) && ( next_state == S_WAIT ) )
    	   IsFlush_ack <= 1'b1 ;
       else if ( IsFlush_in == 1'b0 )
          IsFlush_ack <= 1'b0 ; 	
    	
    	if ( resetb == 1'b1 )
    		IsFlush_pulse <= 1'b0 ;
    	else if ( ( IsFlush_in == 1'b1 ) && ( IsFlush_ack == 1'b1 ) )
    		IsFlush_pulse <= 1'b1 ;
    	else 
    		IsFlush_pulse <= 1'b0 ;
    	
    	if ( resetb == 1'b1 )
    		NVMERead_pulse <= 1'b0 ;
    	else if ( ( NVMERead_d0 == 1'b1 ) && ( NVMERead_d1 == 1'b0 ) )
    		NVMERead_pulse <= 1'b1 ;
    	else
    		NVMERead_pulse <= 1'b0 ;
    			
    	if ( resetb == 1'b1 )
    		NVMEWrite_pulse <= 1'b0 ;
    	else if ( ( NVMEWrite_d0 == 1'b1 ) && ( NVMEWrite_d1 == 1'b0 ) )
    		NVMEWrite_pulse <= 1'b1 ;
    	else
    		NVMEWrite_pulse <= 1'b0 ;				
    end
    
    always @ ( posedge clk_in )
    begin
    	if ( resetb == 1'b1 )
    		admin_opc <= 8'd0 ;
    	else if ( ( ( config_data == IDENTIFY_CONTROLLER ) || ( config_data == IDENTIFY_NAMESPACE_0 ) || ( config_data == IDENTIFY_NAMESPACE_1 ) ) && ( next_state == S_NVME_INIT_WRITE ) ) 
    		admin_opc <= 8'h06 ;
    	else if ( ( config_data == CREATE_IO_QUEUES_0 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		admin_opc <= 8'h05 ;
    	else if ( ( config_data == CREATE_IO_QUEUES_1 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		admin_opc <= 8'h01 ;
        else if ( next_state == S_GetSMARTHealth ) 
    		admin_opc <= 8'h02 ;
    	else if ( next_state == S_IsFlush ) 
    		admin_opc <= 8'h00 ;	
    	else if ( next_state == S_IsTrim )
    		admin_opc <= 8'h09 ;	
    	else if ( next_state == S_NVME_WRITE ) 
    		admin_opc <= 8'h01 ;
    	else if ( next_state == S_NVME_READ )
    		admin_opc <= 8'h02 ;		
    	else
    		admin_opc <= 8'h00 ;
    		
    	if ( resetb == 1'b1 )
    		cid <= 16'd0 ;
    	else if ( is_io_queue )
    		cid <= io_create_queue_cnt ;
        else
            cid <= admin_create_queue_cnt ;
    		
    	if ( resetb == 1'b1 )
    		PRP1 <= 64'd0 ;
    	else if ( ( config_data == IDENTIFY_CONTROLLER ) && ( next_state == S_NVME_INIT_WRITE ) )
    		PRP1 <= idController ;
    	else if ( ( ( config_data == IDENTIFY_NAMESPACE_0 ) || ( config_data == IDENTIFY_NAMESPACE_1 ) ) && ( next_state == S_NVME_INIT_WRITE ) ) 
    		PRP1 <= idNamespace ;
    	else if ( ( config_data == CREATE_IO_QUEUES_0 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		PRP1 <= iocq ;
    	else if ( ( config_data == CREATE_IO_QUEUES_1 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		PRP1 <= iosq ;	
    	else if ( next_state == S_GetSMARTHealth ) 
    	 	PRP1 <= logSMARTHealth ;
    	else if ( next_state == S_IsTrim ) 
    		PRP1 <= dsmRange ;
    	else if ( next_state == S_NVME_WRITE ) 
    		PRP1 <= WRITE_ADDR ;
    	else if ( next_state == S_NVME_READ ) 
    		PRP1 <= READ_ADDR ; 
    	else
    		PRP1 <= 64'd0 ;
    	
    	if ( resetb == 1'b1 )
    		PRP2 <= 64'd0 ;
    	else if ( ( next_state == S_NVME_WRITE ) || ( next_state == S_NVME_READ ) )
    		PRP2 <= PRP_LIST ;
    	else
    		PRP2 <= 64'd0 ;	
    			
    	if ( resetb == 1'b1 )
    		CDW10 <= 32'd0 ;
    	else if ( ( config_data == IDENTIFY_CONTROLLER ) && ( next_state == S_NVME_INIT_WRITE ) )
    		CDW10 <= 32'd1 ;
    	else if ( ( config_data == IDENTIFY_NAMESPACE_0 ) && ( next_state == S_NVME_INIT_WRITE ) ) 
    		CDW10 <= 32'd2 ; 
    	else if ( ( config_data == IDENTIFY_NAMESPACE_1 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		CDW10 <= 32'd0 ;
    	else if ( ( ( config_data == CREATE_IO_QUEUES_0 ) || ( config_data == CREATE_IO_QUEUES_1 ) ) && ( next_state == S_NVME_INIT_WRITE ) )
    		CDW10 <= ( IO_SIZE << 16) | 32'h0000_0001; 	
    	else if ( next_state == S_GetSMARTHealth ) 
    		CDW10 <= 32'h007F0002 ;
    	else if ( next_state == S_IsTrim ) 
    		CDW10 <= 32'h00000000 ;
    	else if ( next_state == S_NVME_WRITE ) 
    		CDW10 <= WritedestLBA[31:0] ;
    	else if ( next_state == S_NVME_READ ) 
    		CDW10 <= ReadsrcLBA[31:0] ;
    	else 
    		CDW10 <= 32'd0 ;
    		
    	if ( resetb == 1'b1 )
    		CDW11 <= 32'd0 ;
    	else if ( ( config_data == CREATE_IO_QUEUES_0 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		CDW11 <= 32'h00000001 ;
    	else if ( ( config_data == CREATE_IO_QUEUES_1 ) && ( next_state == S_NVME_INIT_WRITE ) )	
    		CDW11 <= 32'h00010001 ;
    	else if ( next_state == S_IsTrim ) 
    		CDW11 <= 32'h00000004 ;
    	else if ( next_state == S_NVME_WRITE )
    		CDW11 <= WritedestLBA[63:32] ;
    	else if ( next_state == S_NVME_READ ) 
    		CDW11 <= ReadsrcLBA[63:32] ;
    	else
    		CDW11 <= 32'd0 ;
    	
    	if ( resetb == 1'b1 )
    		CDW12 <= 32'd0 ;
    	else if ( ( next_state == S_NVME_WRITE ) || ( next_state == S_NVME_READ ) )
    		CDW12 <= numLBA - 32'd1 ;
    	else
    		CDW12 <= 32'd0 ;
    		
    	if ( resetb == 1'b1 )
    		nsid <= 32'd0 ;
    	else if ( ( config_data == IDENTIFY_NAMESPACE_1 ) && ( next_state == S_NVME_INIT_WRITE ) )
    		nsid <= nsid_in ;    		
    	else if ( next_state == S_GetSMARTHealth )
    		nsid <= 32'hffff_ffff ;
    	else if ( next_state == S_IsTrim ) 
    		nsid <= nsid_in ;
    	else if ( next_state == S_IsFlush )
    		nsid <= nsid_in ;
    	else if ( next_state == S_NVME_WRITE ) 
    		nsid <= nsid_in ;
    	else if ( next_state == S_NVME_READ )
    		nsid <= nsid_in ;
    	else 
    		nsid <= 32'd0 ;
    end
    
    always @ ( posedge clk_in )	
    begin
    	if ( resetb == 1'b1 )
    		read_start <= 1'b0 ;
    	else if ( ( ( next_state == S_READ_STATUS ) || ( next_state == S_NVME_INIT_READ ) ) && ( next_state != state ) )	
    		read_start <= 1'b1 ;	
    	else if ( read_start_ack )
    		read_start <= 1'b0 ;
    		
    	if ( resetb == 1'b1 )
    		write_start <= 1'b0 ;
    	else if ( ( ( next_state != S_READ_STATUS ) && ( next_state != S_NVME_INIT_READ ) && ( next_state != S_BLOCK_STATUS ) && ( next_state != S_WAIT ) && ( next_state != S_IDLE ) ) && ( next_state != state ) )		
    		write_start <= 1'b1 ;
    	else if ( write_start_ack )
    		write_start <= 1'b0 ;
   end
   
endmodule
