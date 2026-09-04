// minGRU cell, contract 4.3, one lane per cycle: h = SAT8(RS((c<<8) + a*(h_prev-c), 8)).





module mingru #(
  parameter integer PIPE = 1
) (
  input  wire               clk,
  input  wire signed [15:0] tmac_gate,
  input  wire signed [15:0] tmac_cand,
  input  wire signed [7:0]  h_prev,
  input  wire signed [7:0]  bias,
  input  wire [7:0]         a_ovr,
  input  wire               a_ovr_en,
  input  wire [1:0]         shb,
  input  wire [5:0]         z_sh,
  input  wire [5:0]         c_sh,
  output wire signed [17:0] z,
  output wire [7:0]         sig_idx,
  output wire [7:0]         a,
  output wire signed [7:0]  c,
  output wire signed [17:0] h_acc,
  output wire signed [7:0]  h
);
  assign z = {{2{tmac_gate[15]}}, tmac_gate}
           + $signed({{10{bias[7]}}, bias} <<< shb);

  wire signed [17:0] zs;
  rnd_shift #(.W(18), .SW(7)) u_rz (.v(z), .s({1'b0, z_sh}), .y(zs));
  wire signed [17:0] zc = (zs > 18'sd127)  ? 18'sd127 :
                          (zs < -18'sd128) ? -18'sd128 : zs;
  assign sig_idx = zc[7:0] + 8'd128;
  wire _unused = &{1'b0, zc[17:8], 1'b0};
  sigmoid_lut u_sig (.addr(sig_idx), .data(a));

  wire signed [17:0] cs;
  rnd_shift #(.W(18), .SW(7)) u_rc (.v({{2{tmac_cand[15]}}, tmac_cand}),
                                    .s({1'b0, c_sh}), .y(cs));
  assign c = (cs > 18'sd127)  ? 8'sd127 :
             (cs < -18'sd127) ? -8'sd127 : cs[7:0];

  wire [7:0]         a_use = a_ovr_en ? a_ovr : a;
  wire [7:0]         a_s;
  wire signed [7:0]  c_s;
  wire signed [7:0]  hp_s;
  generate
    if (PIPE != 0) begin : g_pipe
      reg [7:0] a_q; reg signed [7:0] c_q, hp_q;
      always @(posedge clk) begin a_q <= a_use; c_q <= c; hp_q <= h_prev; end
      assign a_s = a_q; assign c_s = c_q; assign hp_s = hp_q;
    end
  endgenerate

  wire signed [8:0]  hmc = {hp_s[7], hp_s} - {c_s[7], c_s};
  wire signed [17:0] amul = $signed({1'b0, a_s}) * hmc;
  assign h_acc = $signed({{2{c_s[7]}}, c_s, 8'd0}) + amul;

  wire signed [17:0] hs;
  rnd_shift #(.W(18), .SW(7)) u_rh (.v(h_acc), .s(7'sd8), .y(hs));
  assign h = (hs > 18'sd127)  ? 8'sd127 :
             (hs < -18'sd127) ? -8'sd127 : hs[7:0];
endmodule
