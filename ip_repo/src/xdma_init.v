`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/09 17:29:34
// Design Name: 
// Module Name: xdma_init
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


module xdma_init # ( 
	parameter BASE_ADDR_BRAM = 64'ha0100000 ,
	parameter BASE_ADDR_XDMA = 64'h4_0000_0000 ,
	parameter BASE_ADDR_BAR = 64'ha0000000 ,
    parameter ASQ_ADDR = 32'ha0100000 ,
	parameter ACQ_ADDR = 32'ha0101000 
) (
	input aclk ,
	input rst ,

	input link_up ,

	input ap_start ,
	output reg ap_done ,

	output reg write_start ,
	output reg read_start ,
	input write_start_ack ,
	input read_start_ack ,
	
	input sys_write_master_done ,
	input sys_read_master_done ,

	input [31:0] reg_in_data ,
	output reg [63:0] reg_out_addr ,
	output reg [31:0] reg_out_data  ,
	
	output reg [15:0] MaxNumTags ,
	output reg [3:0] PageSize 
    );
    //localparam integer declarations
   
	//regs
	reg ap_start_d0 ;
	reg ap_start_d1 ;
	
	reg ap_start_pulse ;
	
	reg en ;

    reg [31:0] counter ;

	reg [31:0] lut_index ;
	
    reg [7:0] CAPPtr ;
	reg [7:0] CAPPtr_dev ;
	reg [2:0] MPSS ;
	reg [7:0] PXCAP ;
	reg [7:0] PXCAP_dev ;
	reg [31:0] PXDC_Data ;
	
    //wires
    wire [68:0] lut_data ;
    //main codes
    
    xdma_config_lut #( 
		.BASE_ADDR_BRAM ( BASE_ADDR_BRAM ) ,
		.BASE_ADDR_BAR ( BASE_ADDR_BAR ) ,
		.ASQ_ADDR ( ASQ_ADDR ) ,
		.ACQ_ADDR ( ACQ_ADDR )
	) xdma_config_lut (
        .lut_index ( lut_index ) ,
        .lut_data ( lut_data ) ,
        .CAPPtr ( CAPPtr ) ,
        .CAPPtr_dev ( CAPPtr_dev ) ,
        .MPSS ( MPSS ) ,
        .PXCAP ( PXCAP ) ,
        .PXCAP_dev ( PXCAP_dev ) ,
        .PXDC_Data ( PXDC_Data )
    ) ;
    
	always @ ( posedge aclk )
	begin
		if ( rst == 1'b1 ) begin
			ap_start_d0 <= 1'b0 ;
			ap_start_d1 <= 1'b0 ;
		end
		else begin
			ap_start_d0 <= ap_start ;
			ap_start_d1 <= ap_start_d0 ;
		end
	end

    always @ ( posedge aclk )
    begin
    
		if ( rst == 1'b1 )
			ap_start_pulse <= 1'b0 ;
		else if ( ap_start_d0 && ( ~ ap_start_d1 ) )
			ap_start_pulse <= 1'b1 ;
		else	
			ap_start_pulse <= 1'b0 ;

    	if ( rst == 1'b1 )
    		en <= 1'b0 ;
    	else if ( ap_start_pulse ) 
    		en <= 1'b1 ;	
        else if ( read_start || write_start ) 
            en <= 1'b0 ;
        else if ( sys_write_master_done || sys_read_master_done )
            en <= 1'b1 ; 
    	
		if ( rst == 1'b1 )
			read_start <= 1'b0 ;
		else if ( ( lut_data[64] == 1'b1 ) && ( lut_data[66] == 1'b0 ) && ( en ) ) 
			read_start <= 1'b1 ;
		else if ( read_start_ack )
			read_start <= 1'b0 ;

		if ( rst == 1'b1 )
			write_start <= 1'b0 ;
		else if ( ( ( lut_data[64] == 1'b0 ) && ( lut_data[66] == 1'b0 ) ) && ( en ) ) 
			write_start <= 1'b1 ;
		else if ( write_start_ack )
			write_start <= 1'b0 ;	
    
    	if ( rst == 1'b1 )
    		lut_index <= 32'd0 ;
    	else if ( sys_write_master_done || sys_read_master_done )
    		lut_index <= lut_index + 32'd1 ;
        else if ( ( lut_index == 32'd5 ) && ( link_up ) )
            lut_index <= lut_index + 32'd1 ;
    			
    	if ( rst == 1'b1 )
    		reg_out_addr <= 32'd0 ;
    	else if ( lut_data[65] == 1'b0 )
    		reg_out_addr <= BASE_ADDR_XDMA + { 32'd0 , lut_data[63:32] } ;
		else if ( lut_data[65] == 1'b1 )
			reg_out_addr <= BASE_ADDR_BAR + { 32'd0 , lut_data[63:32] } ;
    	
    	if ( rst == 1'b1 )
    		reg_out_data <= 32'd0 ;
    	else if ( lut_data[68:67] == 2'b00 )
    		reg_out_data <= lut_data[31:0] ;
        else if ( lut_data[68:67] == 2'b01 )
            reg_out_data <= reg_in_data & lut_data[31:0] ;
        else if ( lut_data[68:67] == 2'b10 )
            reg_out_data <= reg_in_data | lut_data[31:0] ;    
        
        if ( rst == 1'b1 )
            CAPPtr <= 8'd0 ;
        else if ( lut_index == 32'd15 )
            CAPPtr <= reg_in_data[7:0] ;
        
        if ( rst == 1'b1 )
            PXCAP <= 8'd0 ;
        else if ( ( lut_index == 32'd16 ) && ( reg_in_data[7:0] == 8'h10 ) )
            PXCAP <= reg_in_data[15:8] ;
        
        if ( rst == 1'b1 )
            CAPPtr_dev <= 8'd0 ;
        else if ( lut_index == 32'd13 ) 
            CAPPtr_dev <= reg_in_data[7:0] ;
         
         if ( rst === 1'b1 )
            PXCAP_dev <= 8'd0 ;
         else if ( ( lut_index == 32'd14 ) && ( reg_in_data[7:0] == 8'h10 ) )
            PXCAP_dev <= reg_in_data[15:8] ;
            
        if ( rst == 1'b1 )
            MPSS <= 3'b111 ;
        else if ( lut_index == 32'd15 ) 
            MPSS <= reg_in_data[2:0] ;
        else if ( ( lut_index == 32'd16 ) && ( MPSS > reg_in_data[2:0] ) )
            MPSS <= reg_in_data[2:0] ;
            
        if ( rst == 1'b1 )
            PXDC_Data <= 32'd0 ;
        else if ( ( lut_index == 32'd17 ) || ( lut_index == 32'd19 ) )
            PXDC_Data <= reg_in_data ;
        
        if ( rst == 1'b1 ) 
            MaxNumTags <= 16'd0 ;
        else if ( lut_index == 32'd38 )
            MaxNumTags <= reg_in_data[15:0] ;
        
        if ( rst == 1'b1 )
            PageSize <= 4'h0 ;
        else if ( lut_index == 32'd39 )
            PageSize <= reg_in_data[19:16] ;
        
		if ( rst == 1'b1 )
			counter <= 32'd0 ;
		else if ( ( lut_index == 32'd41 ) && ( counter < 32'd250_999_999 ) )
			counter <= counter + 32'd1 ;	
			
		if ( rst == 1'b1 )
		   ap_done <= 1'b0 ;
	    else if ( counter == 32'd249_999_999 )
	       ap_done <= 1'b1 ;	
    end	
endmodule
