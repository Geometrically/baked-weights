// Squared-ReLU MLP nonlinearity, contract 4.4: u = SAT8(RS(max(fc,0), u_sh)), v = SAT8(RS(u*u, v_sh)).

module sqrelu (
  input  wire signed [15:0] tmac_fc,
  input  wire [5:0]         u_sh,
  input  wire [5:0]         v_sh,
  output wire signed [7:0]  u,
  output wire [15:0]        usq,
  output wire signed [7:0]  v
);
  wire signed [16:0] relu = tmac_fc[15] ? 17'sd0 : {1'b0, tmac_fc};
  wire signed [16:0] us;
  rnd_shift #(.W(17), .SW(7)) u_ru (.v(relu), .s({1'b0, u_sh}), .y(us));
  assign u = (us > 17'sd127) ? 8'sd127 : us[7:0];

  assign usq = u * u;

  wire signed [17:0] vs;
  rnd_shift #(.W(18), .SW(7)) u_rv (.v({2'b0, usq}), .s({1'b0, v_sh}), .y(vs));
  assign v = (vs > 18'sd127) ? 8'sd127 : vs[7:0];
endmodule
