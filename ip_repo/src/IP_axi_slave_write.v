`timescale 1ns/1ps

`ifndef IP_axi_slave_write
  `define IP_axi_slave_write


  // INTERNAL FILE
  // SECURE_PLACEHOLDER_CONFIG
  // SECURE_PLACEHOLDER_NETLIST


module IP_axi_slave_write #(
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


// Write ADDR Pipeline

output reg                 awready,
input                      awvalid,
input[ADDR_WIDTH-1:0]      awaddr,
input[7:0]                 awlen,
input[2:0]                 awsize,
input[UNIQUE_ID_SZ-1:0]    awid,

//Write DATA Pipe
input[(DATA_WIDTH/8)-1:0]  wstrb,
output                     wready,
input                      wvalid,
input                      wlast,
input[(DATA_WIDTH-1):0]    wdata,


//Write RESP Pipe
output reg[1:0]            bresp,
output                     bvalid,
input                      bready,
output[UNIQUE_ID_SZ-1:0]   bid,

//FIFO interface

input                                 fifo_full,
input                                 fifo_overflow,
output wire [(DATA_WIDTH-1):0]        data_to_fifo,
output wire                           fifo_push,
//output wire [(DATA_WIDTH/8-1):0]      fifo_wstrb,
output reg  [FIFO_ADDR_WIDTH-1:0]     write_addr,
output reg  [MEM_ADDR_WIDTH-1:0]      write_addr_mem,
output reg  [12:0]                    write_byte_sz,
output reg                            write_req

);

reg[1:0] cstate_aw, nstate_aw, cstate_w, nstate_w, cstate_b, nstate_b;
reg[UNIQUE_ID_SZ-1:0] IDreg;
//reg[UNIQUE_ID_SZ-1:0] bid_r;



localparam[1:0] WRITE_ADDR_IDLE = 2'b00,
                WRITE_ADDR_WAIT = 2'b01;


localparam[1:0] WRITE_DATA_IDLE = 2'b00,
                WRITE_DATA_WAIT = 2'b01,
                WRITE_DATA_CHECK = 2'b10;


localparam[1:0] WRITE_RESP_IDLE = 2'b00,
                WRITE_RESP_WAIT = 2'b01,
                WRITE_RESP_VALID = 2'b10;

reg  [ 8:0] BytesPerTransfer;
reg  [12:0] DataCnt;
wire [12:0] BeatByteCnt;
reg  [ 2:0] Size;
wire [ 8:0] Length;

assign Length = (awready) ? awlen + 1 : 8'h01;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    BytesPerTransfer <= 'b0;
  else if (awready & awvalid)
    BytesPerTransfer <= (awsize == 3'b000) ? 1:
                        (awsize == 3'b001) ? 2:
                        (awsize == 3'b010) ? 4:
                        (awsize == 3'b011) ? 8:
                        (awsize == 3'b100) ? 16:
                        (awsize == 3'b101) ? 32:
                        (awsize == 3'b110) ? 64:
                        (awsize == 3'b111) ? 128: 0;
  else
    BytesPerTransfer <= BytesPerTransfer;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    cstate_aw <= WRITE_ADDR_IDLE;
  else
    cstate_aw <= nstate_aw;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    cstate_w <= WRITE_DATA_IDLE;
  else
    cstate_w <= nstate_w;


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    cstate_b <= WRITE_RESP_IDLE;
  else
    cstate_b <= nstate_b;

/*-- Begin Write Addr Pipeline --*/


always@(posedge clock or negedge reset_n)
  if (!reset_n)
    Size <= 'b0;
  else if (awready & awvalid)
    Size <= awsize;
  else
    Size <= Size;



//register transfer size

/*always@(posedge clock or negedge reset_n)
*  if (!reset_n | !awready)
*    Length <= 'b1;
*  else if (|awlen)
*    Length <= awlen+1;
*  else
*    Length <= Length;
*/


// FIXED: never goes ready if awvalid is asserted, this prevents DataCnt from obtaining correct data amount

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    awready <= 1'b1;
  else if (awvalid & awready)
      awready <= 1'b0;
  else if (cstate_aw == WRITE_ADDR_WAIT)
      awready <= 1'b0;
  else
      awready <= 1'b1;

always@(posedge clock) begin
    if (awvalid & awready)
        write_req <= 1'b1;
    else
        write_req <= 1'b0;
end

always@(posedge clock) begin
    if (!reset_n)
        write_byte_sz <= 8'b0;
    else if (awvalid & awready)
        write_byte_sz <= BeatByteCnt;
    else
        write_byte_sz <= write_byte_sz;
end

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    IDreg <= 8'b00;
  else if (awvalid & awready)
    IDreg <= awid;
  else
    IDreg <= IDreg;

always@(posedge clock or negedge reset_n) begin
  if (!reset_n)
    write_addr <= 'b0;
  else if (awvalid & awready)
    write_addr <= awaddr >> FIFO_ADDR_SHIFT;
  else
    write_addr <= write_addr;
end

always@(posedge clock or negedge reset_n) begin
  if (!reset_n)
    write_addr_mem <= 'b0;
  else if (awvalid & awready)
    write_addr_mem <= awaddr >> MEM_ADDR_SHIFT;
  else if (wvalid & wready)
    write_addr_mem <= write_addr_mem + 1;
  else
    write_addr_mem <= write_addr_mem;
end


//Write Addr State Transfers
always@(*)
  case(cstate_aw)
    WRITE_ADDR_IDLE:
      if (awvalid & awready)
        nstate_aw = WRITE_ADDR_WAIT;
      else
        nstate_aw = WRITE_ADDR_IDLE;
    WRITE_ADDR_WAIT:
      if (|DataCnt | (cstate_b == WRITE_RESP_IDLE)) // Don't accept new reqs until all data has moved
                                                    // and write response has been sent
        nstate_aw = WRITE_ADDR_WAIT;
      else
        nstate_aw = WRITE_ADDR_IDLE;
    default:
        nstate_aw = cstate_aw;
  endcase


//Data counter
assign BeatByteCnt = Length << awsize;

always@(posedge clock or negedge reset_n)
  if (!reset_n)
    DataCnt <= 'h0;
  else if (awvalid & awready)
    DataCnt <= BeatByteCnt;
  else if (wvalid & wready)
    DataCnt <= (DataCnt - BytesPerTransfer);
  else if (cstate_aw == WRITE_ADDR_IDLE & cstate_w == WRITE_DATA_IDLE)
    DataCnt <= 'h0;
  else
    DataCnt <= DataCnt;


/*--Begin  Write Data Pipe --*/

//These need to be reg'd 1-clk cycle delay should not break these signals 12/29 JR
// CB - added wstrb. Make sure the master is actually writing to the FIFO
// Wstrb can be low from an AXI downsizer but wvalid still asserts
assign fifo_push  = (wvalid & wready) & !fifo_full & (|wstrb);
//assign fifo_wstrb = (wvalid & wready) ? wstrb : {DATA_WIDTH/8{1'b0}};
assign data_to_fifo = wdata;


/*
*always @(posedge clock or negedge reset_n)
* if (!reset_n)
*  fifo_push <= 1'b0;
* else if ((wvalid & wready) & !fifo_full)
*  fifo_push <= 1'b1;
* else
*  fifo_push <=1'b0;
*
*
*always @(posedge clock or negedge reset_n)
* if (!reset_n)
*  data_to_fifo <= 'h0;
* else if (wvalid & !fifo_full)
*  data_to_fifo <= wdata;
* else
*  data_to_fifo <= data_to_fifo;
*/


//always@(posedge clock or negedge reset_n)
//  if (!reset_n) begin
//    data_to_fifo <= 32'h0;
//    end
//  else if (wvalid & !fifo_full) begin
//    data_to_fifo <= wdata;
//    end
//  else begin
//    data_to_fifo <= data_to_fifo;
//  end

assign wready = ((cstate_w == WRITE_DATA_WAIT) & (|DataCnt)) ? (!fifo_full) : 1'b0;


//try only asserting after wvalid and deasserting when !wvalid

/*always@(posedge clock or negedge reset_n)
*  if (!reset_n)
*    wready <= 1'b0;
*  else if (cstate_w == WRITE_DATA_IDLE && !wvalid)
*    wready <= 1'b0;
*  else if (wvalid & !fifo_full)
*    wready <= 1'b1;
*  else if ((cstate_w == WRITE_DATA_WAIT) && (!wlast))
*    wready <= 1'b1;
*  else
*    wready <= 1'b0;
*/


//Write Data SM state transfers

always@(*)
  case(cstate_w)
    WRITE_DATA_IDLE:
      if (/*wvalid & */!fifo_full &
          (cstate_aw == WRITE_ADDR_WAIT) &
          (cstate_b == WRITE_RESP_IDLE)) //  Don't receive data until addr provided
                                         //  Don't try to receive data if we're IDLE but
                                         //  still waiting to send a write response
         nstate_w = WRITE_DATA_WAIT;
      else
         nstate_w = WRITE_DATA_IDLE;
    WRITE_DATA_WAIT:
      if (|DataCnt)
         nstate_w = WRITE_DATA_WAIT;
      else
         nstate_w = WRITE_DATA_IDLE;
    default:
        nstate_w = cstate_w;
  endcase





/*-- Write Resp Pipe --*/

wire BValidReady;

assign BValidReady = (cstate_w == WRITE_DATA_WAIT) ? 1'b1 : 1'b0;

/*always@(posedge clock or negedge reset_n)
*  if (!reset_n)
*    BValidReady <= 1'b0;
*  else if ((cstate_aw == WRITE_ADDR_IDLE) | (cstate_w == WRITE_DATA_IDLE))
*    BValidReady <= 1'b0;
*  else if (cstate_w == WRITE_DATA_WAIT)
*    BValidReady <= 1'b1;
*  else
*    BValidReady <= 1'b0;
*/
always@(posedge clock or negedge reset_n)
  if (!reset_n)
    bresp <= 2'b00;
  else if (cstate_b == WRITE_RESP_WAIT)
    bresp <= (!fifo_overflow) ? 2'b00 : 2'b11;
  else
    bresp <= bresp;

//always@(posedge clock or negedge reset_n)
//  if (!reset_n)
//    bid_r <= {UNIQUE_ID_SZ{1'b0}};
//  else if (cstate_b == WRITE_RESP_VALID)
//    bid_r <= IDreg;
//  else
//    bid_r <= bid_r;

assign bid = /*(cstate_b == WRITE_RESP_VALID) ?*/ IDreg /*: {UNIQUE_ID_SZ{1'b0}}*/;

//Jr 12/29 fix this latch to be clocked reg or wire
/*
*always@(*)
*  if (!reset_n)
*    bvalid = 1'b0;
*  else begin
*   case(cstate_b)
*    WRITE_RESP_IDLE:
*      bvalid = 1'b0;
*    WRITE_RESP_WAIT:
*      bvalid = 1'b0;
*    WRITE_RESP_VALID:
*      bvalid = 1'b1;
*    default:
*      bvalid = bvalid;
*  endcase
*  end
*/

assign bvalid = (cstate_b == WRITE_RESP_VALID);

always@(*)
  case(cstate_b)
    WRITE_RESP_IDLE:
      if (BValidReady & wlast & wvalid & wready) //check for single transfer
        nstate_b = WRITE_RESP_VALID;
      else if (BValidReady)
        nstate_b = WRITE_RESP_WAIT;
      else
        nstate_b = WRITE_RESP_IDLE;
    WRITE_RESP_WAIT:    //wait for burst to complete
      if (wlast & wvalid & wready)
        nstate_b = WRITE_RESP_VALID;
      else
        nstate_b = WRITE_RESP_WAIT;
    WRITE_RESP_VALID:
      if (bready)
       nstate_b = WRITE_RESP_IDLE;
      else
       nstate_b = WRITE_RESP_VALID;
    default:
      nstate_b = cstate_b;
  endcase
//add & wvalid in case of non-valid data @ wlast

`include "ip_functions.vh"

endmodule


`endif





