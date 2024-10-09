`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/27 11:15:53
// Design Name: 
// Module Name: ddr3_hls_write_gmem_m_axi_fifo
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


module ddr3_hls_write_gmem_m_axi_fifo
#(parameter
    DATA_BITS  = 8,
    DEPTH      = 16,
    DEPTH_BITS = 4
)(
    input  wire                 sclk,
    input  wire                 reset,
    input  wire                 sclk_en,
    output reg                  empty_n,
    output reg                  full_n,
    input  wire                 rdreq,
    input  wire                 wrreq,
    output wire [DEPTH_BITS-1:0] data_count ,
    output reg  [DATA_BITS-1:0] q,
    input  wire [DATA_BITS-1:0] data
);
//------------------------Parameter----------------------

//------------------------Local signal-------------------
wire                  push;
wire                  pop;
wire                  full_cond;
reg                   data_vld;
reg  [DEPTH_BITS-1:0] rd_pout;
reg  [DEPTH_BITS-1:0] wr_pout;

reg  [DEPTH_BITS-1:0] pout;
reg  [DATA_BITS-1:0]  mem[0:DEPTH-1];
//------------------------Body---------------------------

assign data_count = pout ;

assign push = full_n & wrreq;
assign pop  = data_vld & (~(empty_n & ~rdreq));
generate
if (DEPTH >= 2) begin
assign full_cond = push && ~pop && pout == DEPTH - 2 && data_vld;
end else begin
assign full_cond = push && ~pop;
end
endgenerate

// q
always @(posedge sclk)
begin
    if (reset) begin
        q <= 0;  
    end
    else if (~(empty_n & ~rdreq)) begin
            q <= mem[rd_pout];
    end
end

// empty_n
always @(posedge sclk)
begin
    if (reset)
        empty_n <= 1'b0;
    else if (~(empty_n & ~rdreq))
            empty_n <= data_vld;

end


// data_vld
always @(posedge sclk)
begin
    if (reset)
        data_vld <= 1'b0;
     else if (push)
         data_vld <= 1'b1;
     else if (~push && pop && pout == 1'b0)
            data_vld <= 1'b0;
end

// full_n
always @(posedge sclk)
begin
    if (reset)
        full_n <= 1'b1;
     else if (pop)
         full_n <= 1'b1;
      else if (full_cond)
            full_n <= 1'b0;
end

always @ ( posedge sclk )
begin
    if ( reset )
        wr_pout <= 1'b0 ;
    else if ( push )
        wr_pout <= wr_pout + 1'b1 ;
end

always @ ( posedge sclk )
begin
    if ( reset )
        rd_pout <= 1'b0 ;
    else if ( pop )
        rd_pout <= rd_pout + 1'b1 ;
end
// pout
always @(posedge sclk)
begin
    if (reset)
        pout <= 1'b0;
    else  if (push & ~pop & data_vld)
         pout <= pout + 1'b1;
     else if (~push && pop && pout != 1'b0)
            pout <= pout - 1'b1;
end

integer i;
always @(posedge sclk)
begin
      if (push) begin
        mem[wr_pout] <= data;
      end
end
endmodule
