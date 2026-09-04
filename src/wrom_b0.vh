// Black-box declaration of the wrom_b0 hard ROM macro.
// Timing comes from macro/wrom_b0.*.lib, layout from macro/wrom_b0.lef and .gds.
// Used as the "vh" (black-box) view of the macro in the hardening config, which is
// what Verilator.Lint and Yosys.Synthesis use to resolve the instance.
(* blackbox *)
module wrom_b0 (
`ifdef USE_POWER_PINS
    inout wire VPWR,
    inout wire VGND,
`endif
    input  wire [11:0] addr,
    output wire [7:0]  q
);
endmodule
