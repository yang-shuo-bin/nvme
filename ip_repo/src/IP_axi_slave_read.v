`timescale 1ns/1ps

`ifndef IP_axi_slave_read
  `define IP_axi_slave_read



  // INTERNAL FILE
  // SECURE_PLACEHOLDER_CONFIG
  // SECURE_PLACEHOLDER_NETLIST


module IP_axi_slave_read #(
parameter UNIQUE_ID_SZ    = 3,
parameter BUS_MULTIPLIER  = 1,
parameter ADDR_WIDTH      = 64,
parameter DATA_WIDTH      = 64,
//parameter FIFO_ADDR_TYPE  = "BYTE",// "BYTE"        : read_addr/write_addr are byte addresses
//                                   // "DOUBLE_WORD" : "" are shifted to double word addresses
//                                   // "BUS_WORD"    : "" are shifted to address data_width sized blocks
parameter    FIFO_ADDR_SHIFT = 7 ,
////                            (FIFO_ADDR_TYPE == "DOUBLE_WORD") ? 2                    :
//                                                                0,
  parameter        FIFO_ADDR_WIDTH = 25,
  parameter        MEM_ADDR_SHIFT  = 7,
  parameter        MEM_ADDR_WIDTH  = 25
)
(

input clock,
input reset_n,


// Read ADDR Pipeline

output reg                 arready,
input                      arvalid,
input[ADDR_WIDTH-1:0]      araddr,
input[7:0]                 arlen,
input[2:0]                 arsize,
input[UNIQUE_ID_SZ-1:0]    arid,




//Read DATA Pipeline

input                      rready,
output                     rvalid,
output                     rlast,
output[(DATA_WIDTH-1):0]   rdata,
output[1:0]                rresp,
output[UNIQUE_ID_SZ-1:0]   rid,

//FIFO Interface
output   wire [8:0]  Length,

input [(DATA_WIDTH-1):0]    data_from_fifo,
input                       fifo_empty,
input                       fifo_underflow,
output                      fifo_pop,
output reg [FIFO_ADDR_WIDTH-1:0] read_addr,
output reg [MEM_ADDR_WIDTH-1 :0] read_addr_mem,
output reg [12:0]           read_byte_sz,
output reg                  read_req

);

//localparam           FIFO_ADDR_SHIFT = (FIFO_ADDR_TYPE == "BUS_WORD")    ? clogb2(DATA_WIDTH/8) :
//                            (FIFO_ADDR_TYPE == "DOUBLE_WORD") ? 2                    :
//                                                                0,
//          FIFO_ADDR_WIDTH = ADDR_WIDTH - FIFO_ADDR_SHIFT,
//          MEM_ADDR_SHIFT  = clogb2(DATA_WIDTH/8),
//          MEM_ADDR_WIDTH  = ADDR_WIDTH - MEM_ADDR_SHIFT ;

reg[1:0] cstate_ar, nstate_ar, cstate_r, nstate_r;
reg[UNIQUE_ID_SZ-1:0] IDreg;


localparam[1:0] READ_ADDR_IDLE = 2'b00,
                READ_ADDR_WAIT = 2'b10;

localparam[1:0] READ_DATA_IDLE = 2'b00,
                READ_DATA_WAIT = 2'b01,
                READ_DATA_CHECK = 2'b10;


wire RValidReady;




reg  [8:0]  BytesPerTransfer;
reg  [12:0] DataCnt;
wire [12:0] BeatByteCnt;
reg  [2:0]  Size;


assign rresp = fifo_underflow ? 2'b10 : 2'b00;

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    BytesPerTransfer <= 'b0;
  else if (arready & arvalid)
    BytesPerTransfer <= (arsize == 3'b000) ? 1:
                        (arsize == 3'b001) ? 2:
                        (arsize == 3'b010) ? 4:
                        (arsize == 3'b011) ? 8:
                        (arsize == 3'b100) ? 16:
                        (arsize == 3'b101) ? 32:
                        (arsize == 3'b110) ? 64:
                        (arsize == 3'b111) ? 128: 0;
  else
    BytesPerTransfer <= BytesPerTransfer;





always@(posedge clock or negedge reset_n)
  if (!reset_n)
    cstate_ar <= READ_ADDR_IDLE;
  else
    cstate_ar <= nstate_ar;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    cstate_r <= READ_DATA_IDLE;
  else
    cstate_r <= nstate_r;



/*-- Read Addr Pipe --*/

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    Size <= 'b0;
  else if (arready & arvalid)
    Size <= arsize;
  else
    Size <= Size;

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    IDreg <= 8'b00;
  else if (arvalid & arready)
    IDreg <= arid;
  else
    IDreg <= IDreg;


/*always@(posedge clock or negedge reset_n)
*  if (!reset_n | !arready)
*    Length <= 'b1;
*  else if (|arlen)
*    Length <= arlen+1;
*  else
*    Length <= Length;
*/

assign Length = arlen + 1;
assign transfer_done =  (cstate_r != READ_DATA_IDLE) ? (DataCnt == BytesPerTransfer) : 1'b0;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    arready <= 1'b1;
  else if (arvalid & arready)
    arready <= 1'b0;
  else if (cstate_ar == READ_ADDR_IDLE)
    arready <= 1'b1;
  else
    arready <= arready;
    
always@(posedge clock or negedge reset_n) begin
  if (!reset_n)
    read_addr <= 'b0;
  else if (arvalid & arready)
    read_addr <= araddr >> FIFO_ADDR_SHIFT;
  else
    read_addr <= read_addr;
end

always@(posedge clock or negedge reset_n) begin
  if (!reset_n)
    read_addr_mem <= 'b0;
  else if (arvalid & arready)
    read_addr_mem <= araddr >> MEM_ADDR_SHIFT;
  else if (rvalid & rready)
    read_addr_mem <= read_addr_mem + 1;
  else
    read_addr_mem <= read_addr_mem;
end

always @(posedge clock) begin
    if (!reset_n)
        read_byte_sz <= 13'b0;
    else if (arvalid & arready)
        read_byte_sz <= BeatByteCnt;
    else
        read_byte_sz <= read_byte_sz;
end

always @(posedge clock) begin
    if (arvalid & arready)
        read_req <= 1'b1;
    else
        read_req <= 1'b0;
end

always@(*)
  case(cstate_ar)
    READ_ADDR_IDLE:
      if (arvalid & arready)
        nstate_ar = READ_ADDR_WAIT;
      else
        nstate_ar = READ_ADDR_IDLE;
    READ_ADDR_WAIT:
      if (|DataCnt)
        nstate_ar = READ_ADDR_WAIT;
      else
        nstate_ar = READ_ADDR_IDLE;
    default:
        nstate_ar = cstate_ar;
  endcase



//Data counter
assign BeatByteCnt = Length << arsize;

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    DataCnt <= 'h0;
  else if (arvalid & arready)
    DataCnt <= (Length << arsize);
  else if (rvalid & rready)
    DataCnt <= (DataCnt - BytesPerTransfer);
  else if (cstate_ar == READ_ADDR_IDLE & cstate_r == READ_DATA_IDLE)
    DataCnt <= 'h0;
  else
    DataCnt <= DataCnt;



/*-- Read Data Pipeline --*/


// Make sure read addr has completed


//always@(posedge clock or negedge reset_n)
//  if (!reset_n)
//    RValidReady <= 0;
//  else if (cstate_ar == READ_ADDR_IDLE)
//    RValidReady <= 0;
//  else if ((cstate_ar == READ_ADDR_WAIT) & (!rlast))
//    RValidReady <= 1;
//  else if (rlast)
//    RValidReady <= 0;
//  else
 //   RValidReady <= RValidReady;



//rdata gets fifo data
assign rdata = data_from_fifo;
//fifo pop

assign fifo_pop = (rvalid & rready) & !fifo_empty;

//set rlast
assign rlast = (cstate_r != READ_DATA_IDLE) ? (DataCnt == BytesPerTransfer) : 1'b0;

assign rvalid = (cstate_r == READ_DATA_WAIT)? ( !fifo_empty ) : 1'b0;

assign RValidReady = (cstate_ar == READ_ADDR_WAIT) ? !rlast : 1'b0;

assign rid = IDreg;



//NEED ANOTHER STATE HERE TO DROP rvalid and wait for rready again.

always@(*)
  case(cstate_r)
    READ_DATA_IDLE:
      if (RValidReady & !fifo_empty)
        nstate_r = READ_DATA_WAIT;
      else
        nstate_r = READ_DATA_IDLE;
    READ_DATA_WAIT:
      if (rlast & rvalid & rready)
        nstate_r = READ_DATA_CHECK;
      else
        nstate_r = READ_DATA_WAIT;
    READ_DATA_CHECK:
      if (!(|DataCnt))
        nstate_r = READ_DATA_IDLE;
      else
        nstate_r = READ_DATA_WAIT;
    default:
      nstate_r = cstate_r;
  endcase

`include "ip_functions.vh"

endmodule


`endif //IP_axi_slave_read




