// Residual accumulate, contracts 4.3 and 4.4: the sum saturates symmetrically, and sh is signed.


module resid_add #(
  parameter integer RESID_W = 14
) (
  input  wire signed [RESID_W-1:0] x,
  input  wire signed [15:0] tmac_out,
  input  wire signed [6:0]  sh,
  output wire signed [23:0] delta,
  output wire signed [23:0] presat,
  output wire signed [RESID_W-1:0] y
);
  rnd_shift #(.W(24), .SW(7)) u_rs (.v({{8{tmac_out[15]}}, tmac_out}), .s(sh), .y(delta));
  assign presat = {{(24-RESID_W){x[RESID_W-1]}}, x} + delta;
  localparam signed [23:0] LIM = (24'sd1 <<< (RESID_W-1)) - 24'sd1;
  assign y = (presat > LIM)  ? LIM[RESID_W-1:0] :
             (presat < -LIM) ? (-LIM[RESID_W-1:0]) : presat[RESID_W-1:0];
endmodule
