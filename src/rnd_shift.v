// RS(v, s), the only rounding mode in the design: round to nearest, ties away from zero.



module rnd_shift #(
  parameter integer W  = 18,
  parameter integer SW = 7,
  parameter integer OW = W
) (
  input  wire signed [W-1:0]  v,
  input  wire signed [SW-1:0] s,
  output wire signed [OW-1:0] y
);
  wire [SW-1:0]       mag  = s[SW-1] ? (~s + {{(SW-1){1'b0}}, 1'b1}) : s;
  wire signed [W-1:0] one  = {{(W-1){1'b0}}, 1'b1};
  wire                rnd  = !s[SW-1] && (mag != {SW{1'b0}});
  wire signed [W-1:0] bias = rnd ? ((one <<< (mag - {{(SW-1){1'b0}}, 1'b1}))
                                    - {{(W-1){1'b0}}, v[W-1]}) : {W{1'b0}};
  wire signed [W-1:0] full = s[SW-1] ? (v <<< mag) : ((v + bias) >>> mag);
  assign y = full[OW-1:0];
  wire _unused = &{1'b0, full[W-1:(OW < W) ? OW : W-1], 1'b0};
endmodule
