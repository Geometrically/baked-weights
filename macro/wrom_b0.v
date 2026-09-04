`ifndef WROM_B0_VMEM_PATH
`define WROM_B0_VMEM_PATH "wrom_b0.hex"
`endif

// Behavioural model of wrom_b0 - a re-programmed tnt sky130 ROM macro.
// The layout is derived from rom_tvbgone_32k (Apache-2.0, see docs/spikes/tntrom-re.md).
//
// The array is 4096 words but the image is usually shorter, so the model fills the
// tail with the same pad byte the silicon carries (0x79) *before* $readmemh.
// Without that a read above the image returns X here and the pad byte on the die.
`default_nettype none

module wrom_b0 (
`ifdef GL_TEST
    inout wire VPWR,
    inout wire VGND,
`endif
    input  wire [11:0] addr,
    output wire [7:0] q
);
  reg [7:0] rom_data[4095:0];
  integer i;
  initial begin
    for (i = 0; i <= 4095; i = i + 1) rom_data[i] = 8'h79;
    $readmemh(`WROM_B0_VMEM_PATH, rom_data);
  end
  assign q = rom_data[addr];
endmodule
