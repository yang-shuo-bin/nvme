`ifndef iprop_clocked_assert

// synthesis read_comments_as_HDL on
//`define iprop_clocked_assert(clock, enable_check, assertion, message)
// synthesis read_comments_as_HDL off

// synthesis translate_off
// TODO: Allow display of current value??
`define iprop_clocked_assert(clock, enable_check, assertion, message) \
generate                                               \
  if (1) begin /*-- Start new namespace/scope --*/     \
    /*-- Declare variables interrogation --*/          \
    reg enable;                                        \
    reg test;                                          \
    reg assert_hit;                                    \
                                                       \
    /*-- Initialize the variables as disabled --*/     \
    initial begin                                      \
      enable <= ((enable_check) === 1'b1) ?            \
                  1'b1:                                \
                  1'b0;                                \
      test   <= ((assertion) === 1'b0) ?               \
                  1'b0:                                \
                  1'b1;                                \
      assert_hit <= 1'b0;                              \
    end                                                \
                                                       \
    /*-- Load value at any edge --*/                   \
    always@(*) enable = (enable_check);                \
    /*-- Load value at any edge --*/                   \
    always@(*) test   = (assertion);                   \
                                                       \
    /*-- Run the assert check --*/                     \
    always@(posedge clock) begin                       \
      if ((enable === 1'b1) && (test !== 1'b1)) begin  \
        assert_hit <= 1'b1;                            \
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

`endif // iprop_clocked_assert
