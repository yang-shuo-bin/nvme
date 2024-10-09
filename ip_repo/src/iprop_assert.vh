`ifndef iprop_assert

// synthesis read_comments_as_HDL on
//`define iprop_assert(enable_check, assertion, message)
// synthesis read_comments_as_HDL off

// synthesis translate_off
`define iprop_assert(enable_check, assertion, message) \
generate                                               \
  if (1) begin /*-- Start new namespace/scope --*/     \
    /*-- Declare variables for interrogation --*/      \
    reg test;                                          \
    reg enable;                                        \
                                                       \
    /*-- Initialize the variables */                   \
    initial test   = ((assertion) === 1'b0) ?          \
                       1'b0:                           \
                       1'b1;                           \
    initial enable = ((enable_check) === 1'b1) ?       \
                       1'b1:                           \
                       1'b0;                           \
                                                       \
    /*-- Load value at any edge --*/                   \
    always@(*) test   = (assertion);                   \
    /*-- Load value at any edge --*/                   \
    always@(*) enable = (enable_check);                \
                                                       \
    /*-- Run the assert check --*/                     \
    always@(*) begin                                   \
      if ((enable === 1'b1) && (test !== 1'b1)) begin  \
        $display("INTELLIPROP ASSERTION::%m");         \
        $display("  Sim Time: %t", $time);             \
        $display("  %s", message);                     \
        $display();                                    \
        #100 $finish;                                  \
      end                                              \
    end                                                \
  end                                                  \
endgenerate
// synthesis translate_on

`endif // iprop_assert
