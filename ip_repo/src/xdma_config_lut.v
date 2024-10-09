`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/10 13:25:08
// Design Name: 
// Module Name: xdma_config_lut
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


module xdma_config_lut # ( 
	parameter BASE_ADDR_BRAM = 32'ha0100000 ,
	parameter BASE_ADDR_BAR = 32'ha0000000 ,
	parameter ASQ_ADDR = 32'ha0100000 ,
	parameter ACQ_ADDR = 32'ha0101000 
) (
	input [31:0] lut_index ,
	output reg [68:0] lut_data ,
	input [7:0] CAPPtr ,
	input [7:0] CAPPtr_dev ,
	input [2:0] MPSS ,
	input [7:0] PXCAP ,
	input [7:0] PXCAP_dev ,
	input [31:0] PXDC_Data 
     );
     //localparam integer declarations
     localparam integer XDMAPCIE_IM_OFFSET = 32'h0000013c ;
     localparam integer XDMAPCIE_ID_OFFSET = 32'h00000138 ;
     localparam integer PCIE_CFG_CMD_STATUS_REG = 32'h00000004 ;
     localparam integer PCIE_CFG_PRI_SEC_BUS_REG = 32'h00000018 ;
     
     localparam integer XDMAPCIE_IM_ENABLE_ALL_MASK = 32'hffffffff ;
	 localparam integer XDMAPCIE_ID_CLEAR_ALL_MASK = 32'hffffffff ;
	 localparam integer PCIE_CFG_CMD_BUSM_EN = 32'h00000004 ;
	 localparam integer PCIE_CFG_CMD_MEM_EN = 32'h00000002 ;
	 localparam integer PCIE_CFG_CMD_IO_EN = 32'h00000001 ;
	 localparam integer PCIE_CFG_CMD_PARITY = 32'h00000040 ;
	 localparam integer PCIE_CFG_CMD_SERR_EN = 32'h00000100 ;
	 localparam integer PCIE_CFG_PRIM_SEC_BUS = 32'h00070100 ;
     
     localparam integer XDMAPCIE_CFG_CMD_BUSM_EN = 32'h00000004 ;
     localparam integer XDMAPCIE_CFG_CMD_MEM_EN = 32'h00000002 ;
     
     //regs
     
     //wires
     
     //main codes
     always @ ( * )
     begin
     	case ( lut_index )
     			32'd0 : lut_data = { 2'b00,3'b001 , XDMAPCIE_IM_OFFSET , 32'h00000000 } ;
     			32'd1 : lut_data = { 2'b01,3'b000 , XDMAPCIE_IM_OFFSET , ( ~ XDMAPCIE_IM_ENABLE_ALL_MASK ) } ;
     			32'd2 : lut_data = { 2'b00,3'b001 , XDMAPCIE_ID_OFFSET , 32'h00000000 } ;
     			32'd3 : lut_data = { 2'b01,3'b000 , XDMAPCIE_ID_OFFSET , XDMAPCIE_ID_CLEAR_ALL_MASK } ;
     			32'd4 : lut_data = { 2'b00,3'b001 , PCIE_CFG_CMD_STATUS_REG , 32'h00000000 } ;
     			32'd5 : lut_data = { 2'b00,3'b100 , 32'h00000000 , 32'h00000000 } ;
     			32'd6 : lut_data = { 2'b10,3'b000 , PCIE_CFG_CMD_STATUS_REG, PCIE_CFG_CMD_BUSM_EN | PCIE_CFG_CMD_MEM_EN | PCIE_CFG_CMD_IO_EN | PCIE_CFG_CMD_PARITY | PCIE_CFG_CMD_SERR_EN } ;
     			32'd7 : lut_data = { 2'b00,3'b000 , PCIE_CFG_PRI_SEC_BUS_REG , PCIE_CFG_PRIM_SEC_BUS } ;
     			32'd8 : lut_data = { 2'b00,3'b000 , 32'h00000018 , 32'h00ff0100 } ;
     		    32'd9 : lut_data = { 2'b00,3'b000 , 32'h00000020 , 32'h00000000 } ;
     		    32'd10 : lut_data = { 2'b00,3'b000 , 32'h00000024 , 32'h0000a000 } ;
     		    32'd11 : lut_data = { 2'b00,3'b000 , 32'h00000028 , 32'h00000000 } ;
     		    32'd12 : lut_data = { 2'b00,3'b000 , 32'h00100004 , 32'h00000007 } ;   //CTRL_EP_BRIDGE_EN
     		    32'd13 : lut_data = { 2'b00,3'b001 , 32'h00100034 , 32'h00000000 } ;   //CTRL_DEV_CAP_POINTER
     		    32'd14 : lut_data = { 2'b00,3'b001 , 32'h00100000 + CAPPtr_dev , 32'h00000000 } ;   //CTRL_DEV_CAP_PARSE
     		    32'd15 : lut_data = { 2'b00,3'b001 , 32'h00100034 , 32'h00000000 } ;   //CTRL_CAP_POINTER
     		    32'd16 : lut_data = { 2'b00,3'b001 , 32'h00000000 + CAPPtr , 32'h00000000 } ;//CTRL_CAP_PARSE
     		    32'd17 : lut_data = { 2'b00,3'b001 , 32'h00000000 + PXCAP_dev + 32'h4 , 32'h00000000 } ;//CTRL_DEV_PXDCAP_READ
     		    32'd18 : lut_data = { 2'b00,3'b001 , 32'h00000000 + PXCAP + 32'h4 , 32'h00000000 } ;//CTRL_PXDCAP_READ
     		    32'd19 : lut_data = { 2'b00,3'b001 , 32'h00100000 + PXCAP_dev + 32'h8 , 32'h00000000 } ;//CTRL_DEV_PXDC_READ
     		    32'd20 : lut_data = { 2'b00,3'b000 , 32'h00100000 + PXCAP_dev + 32'h8 , { PXDC_Data[31:8] , MPSS , PXDC_Data[4:0] } } ;//CTRL_DEV_PXDC_WRITE
     		    32'd21 : lut_data = { 2'b00,3'b001 , 32'h00000000 + PXCAP + 32'h8 , 32'h00000000 } ;//CTRL_PXDC_READ
     		    32'd22 : lut_data = { 2'b00,3'b000 , 32'h00000000 + PXCAP + 32'h8 , { PXDC_Data[31:8] , MPSS , PXDC_Data[4:0] } } ;//CTRL_PXDC_WRITE
     		    32'd23 : lut_data = { 2'b00,3'b000 , 32'h00100010 , 32'ha0000000 } ;
     		    32'd24 : lut_data = { 2'b00,3'b000 , 32'h00100014 , 32'h00000000 } ;
     		    32'd25 : lut_data = { 2'b00,3'b001 , 32'h00100004 , 32'h00000000 } ;
     		    32'd26 : lut_data = { 2'b10,3'b000 , 32'h00100004 , 32'h00000006 } ;
     		    32'd27 : lut_data = { 2'b00,3'b000 , 32'h00000018 , 32'h00010100 } ;
     		    32'd28 : lut_data = { 2'b00,3'b000 , 32'h00000020 , 32'h00200000 } ;
     		    32'd29 : lut_data = { 2'b00,3'b000 , 32'h00000024 , 32'ha020a000 } ;
     		    32'd30 : lut_data = { 2'b00,3'b000 , 32'h0000002c , 32'h00000000 } ;
     		    32'd31 : lut_data = { 2'b00,3'b001 , 32'h00000004 , 32'h00000000 } ;
     		    32'd32 : lut_data = { 2'b10,3'b000 , 32'h00000004 , 32'h00000006 } ;
     		    32'd33 : lut_data = { 2'b00,3'b001 , 32'h00000148 , 32'h00000000 } ;
     		    32'd34 : lut_data = { 2'b10,3'b000 , 32'h00000148 , 32'h00000001 } ;
				32'd35 : lut_data = { 2'b00,3'b010 , 32'h00000024 , 32'h000f000f } ;
				32'd36 : lut_data = { 2'b00,3'b010 , 32'h00000028 , ASQ_ADDR } ;
				32'd37 : lut_data = { 2'b00,3'b010 , 32'h00000030 , ACQ_ADDR } ;
				32'd38 : lut_data = { 2'b00,3'b011 , 32'h00000000 , 32'h00000000 } ;
				32'd39 : lut_data = { 2'b00,3'b011 , 32'h00000004 , 32'h00000000 } ;
				32'd40 : lut_data = { 2'b00,3'b010 , 32'h00000014 , 32'h00460001 } ;
      		    32'd41 : lut_data = { 2'b00,3'b100 , 32'h00000000 ,  32'h00000000 } ;	
     	endcase
     end
endmodule
