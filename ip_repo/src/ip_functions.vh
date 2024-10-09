
// FUNCTION DECLARATIONS

// Convert one hot bus to decimal value
function integer onehot2dec(input integer oneHotVal);
  begin: ONE_HOT_2_DEC
    if ((oneHotVal & (oneHotVal -1)) != 0) begin // not-onehot check
      oneHotVal = 0;
    end else begin
      for (onehot2dec = -1; oneHotVal > 0; onehot2dec = onehot2dec + 1) begin
        oneHotVal = oneHotVal >> 1;
      end
    end
  end
endfunction

// Ceiling log base 2 address width from depth calculator
function integer clogb2(input [511:0] depth);
  reg [511:0] depth_m1;
  begin: CLOGB2_FUNC
    if (depth <= 1) begin
      clogb2 = 1;
    end else begin
      depth_m1 = depth - 1'b1;
      for (clogb2 = 0; depth_m1 > 0; clogb2 = clogb2 + 1) begin
        depth_m1 = depth_m1 >> 1;
      end
    end
  end
endfunction
