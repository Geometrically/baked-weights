// Generated constant table for the bake_L2E40mlp2_v1 model - do not edit by hand.
module mat_desc #(parameter integer AW = 13, parameter integer CW = 4,
                  parameter integer NL = 2) (
  input  wire [NL-1:0] layer_oh,
  input  wire [2:0] mat_idx,
  output reg  [AW-1:0] base,
  output reg  [7:0] m_last,
  output reg  [CW-1:0] ch_last,
  output reg  [1:0] shift
);
`ifndef SYNTHESIS
  // The descriptors are emitted for the MANIFEST's geometry.  An instantiation that
  // narrows AW/CW silently truncates every base/ch_last (the literals are unsized so
  // they widen safely but cannot shrink), and one that changes NL indexes rows that
  // were never generated.  Catch both at elaboration rather than in silicon.
  initial begin
    if (AW < 13) $fatal(1, "mat_desc: AW=%0d narrower than manifest 13", AW);
    if (CW < 4) $fatal(1, "mat_desc: CW=%0d narrower than manifest 4", CW);
    if (NL != 2) $fatal(1, "mat_desc: NL=%0d but tables hold 2 layers", NL);
  end
`endif
  reg [AW-1:0] base0;
  reg [7:0] m_last0;
  reg [CW-1:0] ch_last0;
  reg [1:0] shift0;
  always @(*) begin
    case (mat_idx)
      3'd0: begin base0 = 0; m_last0 = 8'd39; ch_last0 = 7; shift0 = 2'd0; end   // blocks.0.mix.gate
      3'd1: begin base0 = 320; m_last0 = 8'd39; ch_last0 = 7; shift0 = 2'd2; end   // blocks.0.mix.cand
      3'd2: begin base0 = 640; m_last0 = 8'd39; ch_last0 = 7; shift0 = 2'd1; end   // blocks.0.mix.proj
      3'd3: begin base0 = 960; m_last0 = 8'd79; ch_last0 = 7; shift0 = 2'd0; end   // blocks.0.mlp.fc
      3'd4: begin base0 = 1600; m_last0 = 8'd39; ch_last0 = 15; shift0 = 2'd0; end   // blocks.0.mlp.proj
      default: begin base0 = 0; m_last0 = 0; ch_last0 = 0; shift0 = 0; end
    endcase
  end
  reg [AW-1:0] base1;
  reg [7:0] m_last1;
  reg [CW-1:0] ch_last1;
  reg [1:0] shift1;
  always @(*) begin
    case (mat_idx)
      3'd0: begin base1 = 2240; m_last1 = 8'd39; ch_last1 = 7; shift1 = 2'd0; end   // blocks.1.mix.gate
      3'd1: begin base1 = 2560; m_last1 = 8'd39; ch_last1 = 7; shift1 = 2'd1; end   // blocks.1.mix.cand
      3'd2: begin base1 = 2880; m_last1 = 8'd39; ch_last1 = 7; shift1 = 2'd0; end   // blocks.1.mix.proj
      3'd3: begin base1 = 3200; m_last1 = 8'd79; ch_last1 = 7; shift1 = 2'd0; end   // blocks.1.mlp.fc
      3'd4: begin base1 = 3840; m_last1 = 8'd39; ch_last1 = 15; shift1 = 2'd1; end   // blocks.1.mlp.proj
      default: begin base1 = 0; m_last1 = 0; ch_last1 = 0; shift1 = 0; end
    endcase
  end
  always @(*) begin
    base = ({AW{layer_oh[0]}} & base0) | ({AW{layer_oh[1]}} & base1);
    m_last = ({8{layer_oh[0]}} & m_last0) | ({8{layer_oh[1]}} & m_last1);
    ch_last = ({CW{layer_oh[0]}} & ch_last0) | ({CW{layer_oh[1]}} & ch_last1);
    shift = ({2{layer_oh[0]}} & shift0) | ({2{layer_oh[1]}} & shift1);
  end
endmodule
