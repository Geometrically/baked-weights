// Fetch sequencer for y[M] = scale * (W[M][N] * x[N]): one incrementing ROM address per cycle.







module sequencer #(
  parameter integer N_BANKS     = 1,
  parameter integer LANES       = 5,
  parameter integer ROM_AW      = 13,
  parameter integer X_W         = 8,
  parameter integer ACC_W       = 16,
  parameter integer M_W         = 8,
  parameter integer CH_W        = 4,
  parameter integer SH_W        = 2,
  parameter integer SCALE_TERMS = 1,
  parameter integer ROUND       = 1,
  parameter integer ROM_LAT     = 2,
  parameter integer CSA_CUT     = 2,
  parameter integer DOT_REG     = 1
) (
  input  wire                      clk,
  input  wire                      rst_n,
  input  wire                      start,
  input  wire [ROM_AW-1:0]         base,
  input  wire [M_W-1:0]            m_last,
  input  wire [CH_W-1:0]           ch_last,
  input  wire [SH_W-1:0]           shift,
  input  wire [SH_W-1:0]           shift2,
  output wire [N_BANKS*ROM_AW-1:0] rom_addr,
  input  wire [N_BANKS*8-1:0]      rom_data,
  output wire [CH_W-1:0]           x_chunk,
  input  wire [LANES*X_W-1:0]      x_flat,
  output reg  signed [ACC_W-1:0]   y,
  output reg  [M_W-1:0]            y_idx,
  output reg                       y_valid,
  output wire                      busy,
  output wire                      active
);

  localparam integer LAT = ROM_LAT + ((CSA_CUT > 0) ? 1 : 0)
                        + ((DOT_REG != 0) ? 1 : 0) + 1;

  initial begin
    if (LANES != 5 * N_BANKS)
      $fatal(1, "sequencer: LANES (%0d) must equal 5*N_BANKS (%0d)", LANES, 5 * N_BANKS);
    if (SCALE_TERMS != 1 && SCALE_TERMS != 2)
      $fatal(1, "sequencer: SCALE_TERMS must be 1 or 2, not %0d", SCALE_TERMS);
  end

  reg                run;
  reg [M_W-1:0]      m_cnt;
  reg [CH_W-1:0]     ch_cnt;
  reg [ROM_AW-1:0]   addr;
  reg [LAT-1:0]      vd;
  reg [LAT*M_W-1:0]  idq;

  wire last_chunk = run && (ch_cnt == ch_last);

  assign x_chunk = ch_cnt;
  assign busy    = run | (|vd) | y_valid;
  assign active  = run;

  genvar b;
  generate
    for (b = 0; b < N_BANKS; b = b + 1) begin : g_addr
      assign rom_addr[b*ROM_AW +: ROM_AW] = addr;
    end
  endgenerate

  integer i;
  always @(posedge clk) begin
    if (!rst_n) begin
      run <= 1'b0; m_cnt <= {M_W{1'b0}}; ch_cnt <= {CH_W{1'b0}};
      addr <= {ROM_AW{1'b0}};
    end else if (!run) begin
      if (start) begin
        run <= 1'b1; m_cnt <= {M_W{1'b0}}; ch_cnt <= {CH_W{1'b0}}; addr <= base;
      end
    end else begin
      addr <= addr + {{(ROM_AW-1){1'b0}}, 1'b1};
      if (ch_cnt == ch_last) begin
        ch_cnt <= {CH_W{1'b0}};
        if (m_cnt == m_last) run <= 1'b0;
        else                 m_cnt <= m_cnt + {{(M_W-1){1'b0}}, 1'b1};
      end else begin
        ch_cnt <= ch_cnt + {{(CH_W-1){1'b0}}, 1'b1};
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      vd <= {LAT{1'b0}}; idq <= {(LAT*M_W){1'b0}};
    end else begin
      vd[0] <= last_chunk;
      idq[0 +: M_W] <= m_cnt;
      for (i = 1; i < LAT; i = i + 1) begin
        vd[i] <= vd[i-1];
        idq[i*M_W +: M_W] <= idq[(i-1)*M_W +: M_W];
      end
    end
  end

  wire signed [ACC_W-1:0] acc;
  wire en_now  = run;
  wire clr_now = run && (ch_cnt == {CH_W{1'b0}});

  wire [N_BANKS*8-1:0]  w_pack;
  wire [LANES*X_W-1:0]  x_pack;
  wire                  en_t, clr_t;
  // The ROM register cuts addr -> ROM decode off the trit decoders; the chunk is registered with it.


  generate
    if (ROM_LAT != 0) begin : g_rom_reg
      reg [N_BANKS*8*ROM_LAT-1:0] rd_q;
      reg [LANES*X_W*ROM_LAT-1:0] x_q;
      reg [ROM_LAT-1:0]           en_q, clr_q;
      integer r;
      always @(posedge clk) begin
        rd_q[0 +: N_BANKS*8]  <= rom_data;
        x_q[0 +: LANES*X_W]   <= x_flat;
        if (!rst_n) begin en_q[0] <= 1'b0; clr_q[0] <= 1'b0; end
        else        begin en_q[0] <= en_now; clr_q[0] <= clr_now; end
        for (r = 1; r < ROM_LAT; r = r + 1) begin
          rd_q[r*N_BANKS*8 +: N_BANKS*8] <= rd_q[(r-1)*N_BANKS*8 +: N_BANKS*8];
          x_q[r*LANES*X_W +: LANES*X_W]  <= x_q[(r-1)*LANES*X_W +: LANES*X_W];
          if (!rst_n) begin en_q[r] <= 1'b0; clr_q[r] <= 1'b0; end
          else        begin en_q[r] <= en_q[r-1]; clr_q[r] <= clr_q[r-1]; end
        end
      end
      assign w_pack = rd_q[(ROM_LAT-1)*N_BANKS*8 +: N_BANKS*8];
      assign x_pack = x_q[(ROM_LAT-1)*LANES*X_W +: LANES*X_W];
      assign en_t = en_q[ROM_LAT-1];  assign clr_t = clr_q[ROM_LAT-1];
    end
  endgenerate

  tmac #(
    .LANES   (LANES),
    .X_W     (X_W),
    .ACC_W   (ACC_W),
    .CSA_CUT (CSA_CUT),
    .DOT_REG (DOT_REG)
  ) u_tmac (
    .clk    (clk),
    .rst_n  (rst_n),
    .en     (en_t),
    .clr    (clr_t),
    .wpack  (w_pack),
    .x_flat (x_pack),
    .acc    (acc)
  );

  // Rounding bias: one LSB of the field being shifted out, less one for a negative accumulator.

  function signed [ACC_W-1:0] scale_term;
    input signed [ACC_W-1:0] a;
    input [SH_W-1:0] s;
    reg [ACC_W-1:0] bias;
    reg signed [ACC_W:0] wide;
    begin
      if ((ROUND != 0) && (s != {SH_W{1'b0}}))
        bias = ({{(ACC_W-1){1'b0}}, 1'b1} << (s - 1'b1))
             - {{(ACC_W-1){1'b0}}, a[ACC_W-1]};
      else
        bias = {ACC_W{1'b0}};
      wide = $signed({a[ACC_W-1], a}) + $signed({1'b0, bias});
      wide = wide >>> s;
      scale_term = wide[ACC_W-1:0];
    end
  endfunction

  wire signed [ACC_W-1:0] y_scaled;
  generate
    if (SCALE_TERMS != 2) begin : g_scale1
      assign y_scaled = scale_term(acc, shift);
      wire _unused_shift2 = &{1'b0, shift2, 1'b0};
    end
  endgenerate

  always @(posedge clk) begin
    if (!rst_n) begin
      y <= {ACC_W{1'b0}}; y_idx <= {M_W{1'b0}}; y_valid <= 1'b0;
    end else begin
      y_valid <= vd[LAT-1];
      if (vd[LAT-1]) begin
        y     <= y_scaled;
        y_idx <= idq[(LAT-1)*M_W +: M_W];
      end
    end
  end
endmodule
