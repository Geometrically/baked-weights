// Shared ternary MAC: LANES trits against LANES int8 per cycle, 3:2 CSA tree cut at CSA_CUT.







module tmac #(
  parameter integer LANES   = 5,
  parameter integer X_W     = 8,
  parameter integer ACC_W   = 16,
  parameter integer CSA_CUT = 2,
  parameter integer DOT_REG = 1
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     en,
  input  wire                     clr,
  input  wire [(LANES/5)*8-1:0]   wpack,
  input  wire [LANES*X_W-1:0]     x_flat,
  output reg  signed [ACC_W-1:0]  acc
);

  function integer csa_n;
    input integer n0;
    input integer lev;
    integer n, i;
    begin
      n = n0;
      for (i = 0; i < 64; i = i + 1)
        if (i < lev) n = 2 * (n / 3) + (n % 3);
      csa_n = n;
    end
  endfunction

  function integer csa_levels;
    input integer n0;
    integer n, l, i;
    begin
      n = n0; l = 0;
      for (i = 0; i < 64; i = i + 1)
        if (n > 2) begin n = 2 * (n / 3) + (n % 3); l = l + 1; end
      csa_levels = l;
    end
  endfunction

  function integer csa_off;
    input integer n0;
    input integer lev;
    integer s, i;
    begin
      s = 0;
      for (i = 0; i < 64; i = i + 1)
        if (i < lev) s = s + csa_n(n0, i);
      csa_off = s;
    end
  endfunction

  localparam integer W_BYTES = LANES / 5;
  localparam integer NT0     = LANES + 1;
  localparam integer NLEV    = csa_levels(NT0);
  localparam integer NSLOT   = csa_off(NT0, NLEV + 1);
  localparam integer PIPE    = ((CSA_CUT > 0) ? 1 : 0) + ((DOT_REG != 0) ? 1 : 0);

  initial begin
    if (LANES % 5 != 0)
      $fatal(1, "tmac: LANES must be a multiple of 5 (one ROM byte = 5 trits)");
    if (CSA_CUT > NLEV)
      $fatal(1, "tmac: CSA_CUT exceeds the %0d reduction levels at LANES=%0d", NLEV, LANES);
  end

  wire [10*W_BYTES-1:0] trits;
  genvar b, j, l, k;
  generate
    for (b = 0; b < W_BYTES; b = b + 1) begin : g_dec
      trit_dec5 u_dec (.b(wpack[b*8 +: 8]), .t(trits[b*10 +: 10]));
    end
  endgenerate

  wire [NSLOT*ACC_W-1:0] cmb;
  wire [NSLOT*ACC_W-1:0] lin;

  generate
    for (j = 0; j < LANES; j = j + 1) begin : g_term
      wire signed [X_W-1:0] xj = x_flat[j*X_W +: X_W];
      wire [ACC_W-1:0] sx = {{(ACC_W-X_W){xj[X_W-1]}}, xj};
      assign cmb[j*ACC_W +: ACC_W] =
        trits[2*j] ? (trits[2*j+1] ? ~sx : sx) : {ACC_W{1'b0}};
    end
  endgenerate

  // -x == ~x + 1; the +1s are collected here as the tree's extra term.
  reg [ACC_W-1:0] negcnt;
  integer n;
  always @(*) begin
    negcnt = {ACC_W{1'b0}};
    for (n = 0; n < LANES; n = n + 1)
      negcnt = negcnt + {{(ACC_W-1){1'b0}}, (trits[2*n] & trits[2*n+1])};
  end
  assign cmb[LANES*ACC_W +: ACC_W] = negcnt;

  generate
    for (l = 0; l < NLEV; l = l + 1) begin : g_lev
      localparam integer NIN  = csa_n(NT0, l);
      localparam integer OI   = csa_off(NT0, l);
      localparam integer OO   = csa_off(NT0, l + 1);
      localparam integer NTRI = NIN / 3;
      localparam integer NREM = NIN % 3;
      for (k = 0; k < NTRI; k = k + 1) begin : g_csa
        wire [ACC_W-1:0] a  = lin[(OI + 3*k + 0)*ACC_W +: ACC_W];
        wire [ACC_W-1:0] bb = lin[(OI + 3*k + 1)*ACC_W +: ACC_W];
        wire [ACC_W-1:0] c  = lin[(OI + 3*k + 2)*ACC_W +: ACC_W];
        wire [ACC_W-2:0] mj = (a[ACC_W-2:0] & bb[ACC_W-2:0])
                            | (a[ACC_W-2:0] & c[ACC_W-2:0])
                            | (bb[ACC_W-2:0] & c[ACC_W-2:0]);
        assign cmb[(OO + 2*k + 0)*ACC_W +: ACC_W] = a ^ bb ^ c;
        assign cmb[(OO + 2*k + 1)*ACC_W +: ACC_W] = {mj, 1'b0};
      end
      for (k = 0; k < NREM; k = k + 1) begin : g_rem
        assign cmb[(OO + 2*NTRI + k)*ACC_W +: ACC_W] =
               lin[(OI + 3*NTRI + k)*ACC_W +: ACC_W];
      end
    end
    for (l = 0; l <= NLEV; l = l + 1) begin : g_stage
      localparam integer NC = csa_n(NT0, l);
      localparam integer OC = csa_off(NT0, l);
      if ((CSA_CUT > 0) && (l == CSA_CUT)) begin : g_cut
        reg [NC*ACC_W-1:0] q;
        always @(posedge clk) q <= cmb[OC*ACC_W +: NC*ACC_W];
        assign lin[OC*ACC_W +: NC*ACC_W] = q;
      end else begin : g_thru
        assign lin[OC*ACC_W +: NC*ACC_W] = cmb[OC*ACC_W +: NC*ACC_W];
      end
    end
  endgenerate

  localparam integer OF = csa_off(NT0, NLEV);
  wire signed [ACC_W-1:0] dot = $signed(lin[(OF + 0)*ACC_W +: ACC_W])
                              + $signed(lin[(OF + 1)*ACC_W +: ACC_W]);

  wire signed [ACC_W-1:0] dot_s;
  generate
    if (DOT_REG != 0) begin : g_dot_reg
      reg signed [ACC_W-1:0] dot_q;
      always @(posedge clk) dot_q <= dot;
      assign dot_s = dot_q;
    end
  endgenerate

  wire en_s, clr_s;
  generate
    if (PIPE != 0) begin : g_ctl_reg
      reg [PIPE-1:0] en_q, clr_q;
      integer p;
      always @(posedge clk) begin
        en_q[0]  <= en;
        clr_q[0] <= clr;
        for (p = 1; p < PIPE; p = p + 1) begin
          en_q[p]  <= en_q[p-1];
          clr_q[p] <= clr_q[p-1];
        end
      end
      assign en_s  = en_q[PIPE-1];
      assign clr_s = clr_q[PIPE-1];
    end
  endgenerate

  always @(posedge clk) begin
    if (!rst_n)        acc <= {ACC_W{1'b0}};
    else if (clr_s)    acc <= en_s ? dot_s : {ACC_W{1'b0}};
    else if (en_s)     acc <= acc + dot_s;
  end
endmodule
