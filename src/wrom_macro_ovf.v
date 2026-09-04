`default_nettype wire

// Weight ROM: one 4096x8 hard macro plus a synthesised 384-word tail; outside the image reads pad 0x79.







module wrom #(
  parameter integer N_BANKS   = 1,
  parameter integer ROM_AW    = 13,
  parameter integer OVF_WORDS = 384
) (
  input  wire [N_BANKS*ROM_AW-1:0] addr,
  output wire [N_BANKS*8-1:0]      data
);
  localparam [7:0] PAD = 8'h79;

  wire [ROM_AW-1:0] a = addr[0 +: ROM_AW];
  wire [7:0] q_macro, q_ovf;

  wrom_b0  u_macro (.addr(a[11:0]), .q(q_macro));
  wrom_ovf u_ovf   (.addr(a[8:0]),  .q(q_ovf));

  wire        ovf_sel = a[ROM_AW-1];
  wire [11:0] rel     = a[11:0];
  wire        ovf_ok  = rel < OVF_WORDS[11:0];
  assign data[0 +: 8] = ovf_sel ? (ovf_ok ? q_ovf : PAD) : q_macro;
endmodule
