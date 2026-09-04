// Generated constant table for the bake_L2E40mlp2_v1 model - do not edit by hand.
module norm_sh (
  input  wire [2:0] sel,
  output reg [5:0] sh
);
  always @(*) begin
    case (sel)
      3'd0: sh = 6'd10;
      3'd1: sh = 6'd11;
      3'd2: sh = 6'd11;
      3'd3: sh = 6'd10;
      3'd4: sh = 6'd10;
      default: sh = 6'd0;
    endcase
  end
endmodule
