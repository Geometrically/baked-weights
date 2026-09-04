// Generated constant table for the bake_L2E40mlp2_v1 model - do not edit by hand.
module site_const #(parameter integer NL = 2) (
  input  wire [NL-1:0] layer_oh,
  output reg  [5:0] z_sh,
  output reg  [5:0] c_sh,
  output reg  signed [6:0] dmix_sh,
  output reg  [5:0] u_sh,
  output reg  [5:0] v_sh,
  output reg  signed [6:0] dmlp_sh,
  output reg  [1:0] shb
);
`ifndef SYNTHESIS
  // NL is overridable but the constants below are emitted for the manifest's layer
  // count; a mismatch selects rows that do not exist.
  initial if (NL != 2) $fatal(1, "site_const: NL=%0d but tables hold 2 layers", NL);
`endif
  localparam [5:0] Z_SH0 = 6'h4;
  localparam [5:0] C_SH0 = 6'h0;
  localparam [6:0] DMIX_SH0 = 7'h2;
  localparam [5:0] U_SH0 = 6'h3;
  localparam [5:0] V_SH0 = 6'h6;
  localparam [6:0] DMLP_SH0 = 7'h7d;
  localparam [1:0] SHB0 = 2'h1;
  localparam [5:0] Z_SH1 = 6'h2;
  localparam [5:0] C_SH1 = 6'h2;
  localparam [6:0] DMIX_SH1 = 7'h7e;
  localparam [5:0] U_SH1 = 6'h3;
  localparam [5:0] V_SH1 = 6'h6;
  localparam [6:0] DMLP_SH1 = 7'h7b;
  localparam [1:0] SHB1 = 2'h0;
  always @(*) begin
    z_sh = ({6{layer_oh[0]}} & Z_SH0) | ({6{layer_oh[1]}} & Z_SH1);
    c_sh = ({6{layer_oh[0]}} & C_SH0) | ({6{layer_oh[1]}} & C_SH1);
    dmix_sh = ({7{layer_oh[0]}} & DMIX_SH0) | ({7{layer_oh[1]}} & DMIX_SH1);
    u_sh = ({6{layer_oh[0]}} & U_SH0) | ({6{layer_oh[1]}} & U_SH1);
    v_sh = ({6{layer_oh[0]}} & V_SH0) | ({6{layer_oh[1]}} & V_SH1);
    dmlp_sh = ({7{layer_oh[0]}} & DMLP_SH0) | ({7{layer_oh[1]}} & DMLP_SH1);
    shb = ({2{layer_oh[0]}} & SHB0) | ({2{layer_oh[1]}} & SHB1);
  end
endmodule
