`default_nettype none

// One token: NL x (RMSNorm, minGRU, RMSNorm, squared-ReLU MLP, each added into the residual), then the final norm.










module chip_core #(
  parameter integer E       = 40,
  parameter integer NL      = 2,
  parameter integer LANES   = 5,
  parameter integer N_BANKS = 1,
  parameter integer ROM_AW  = 13,
  parameter integer RESID_W = 14,
  parameter integer CH_W    = 4,
  parameter integer HM      = 2,
  parameter integer ACC_W   = 16,
  parameter integer BW      = 9,
  parameter integer ROM_LAT = 2,
  parameter integer MG_PIPE = 1,
  parameter integer RES_PIPE = 1,
  parameter integer CSA_CUT = 2,
  parameter integer DOT_REG = 1
) (
  input  wire                      clk,
  input  wire                      rst_n,
  input  wire                      start,
  input  wire                      clr_state,
  output reg                       done,
  input  wire [BW-1:0]             ld_idx,
  input  wire signed [RESID_W-1:0] ld_data,
  input  wire                      ld_we,
  input  wire                      gf_rot,
  output wire signed [7:0]         gf_data,
  output wire [N_BANKS*ROM_AW-1:0] rom_addr,
  input  wire [N_BANKS*8-1:0]      rom_data
);
  localparam integer HN = HM*E;
  localparam integer IE = $clog2(E);
  localparam integer NRM_NF_I = 2*NL;
  localparam [3:0] P_IDLE=4'd0, P_N1=4'd1, P_GATE=4'd2, P_CAND=4'd3, P_PROJ=4'd4,
                   P_N2=4'd5, P_FC=4'd6, P_DOWN=4'd7, P_NF=4'd8, P_DONE=4'd9;

  localparam integer LAST_L_I = NL - 1;
  reg [3:0]  ph;
  reg [1:0]  layer;
  // Five one-hot replicas of the layer decode; merging them changes the netlist.

  (* keep = "true" *) reg [NL-1:0] loh_h, loh_w, loh_site, loh_mat, loh_gb;

  reg        go;

  // resid and abuf are addressable; gbuf/hbuf/vbuf are rings the MAC reads LANES at a time.




  localparam integer GN = ((E  + LANES - 1) / LANES) * LANES;
  localparam integer VN = ((HN + LANES - 1) / LANES) * LANES;

  reg signed [RESID_W-1:0] resid [0:E-1];
  reg [7:0]                abuf  [0:E-1];
  reg [GN*8-1:0]           gring;
  reg [VN*8-1:0]           vring;
  reg [NL*GN*8-1:0]        hring;
  reg [GN*8-1:0]           hcur, hnext;
  // The layer selects must be exactly one-hot.

`ifndef SYNTHESIS
  always @(posedge clk) if (rst_n) begin
    if (loh_h !== (({{(NL-1){1'b0}}, 1'b1}) << layer))
      $fatal(1, "loh_h %b != onehot(layer=%0d)", loh_h, layer);
    if (loh_w !== loh_h)    $fatal(1, "loh_w %b != loh_h %b", loh_w, loh_h);
    if (loh_site !== loh_h) $fatal(1, "loh_site %b != loh_h %b", loh_site, loh_h);
    if (loh_mat  !== loh_h) $fatal(1, "loh_mat %b != loh_h %b", loh_mat, loh_h);
    if (loh_gb   !== loh_h) $fatal(1, "loh_gb %b != loh_h %b", loh_gb, loh_h);
  end
`endif
  integer lh2, lw;

  wire [2:0] nrm_sel = (ph == P_N1) ? {layer, 1'b0} :
                       (ph == P_N2) ? {layer, 1'b1} : NRM_NF_I[2:0];
  wire [5:0] nrm_sh;
  norm_sh u_nsh (.sel(nrm_sel), .sh(nrm_sh));

  wire [5:0] z_sh, c_sh, u_sh, v_sh;
  wire signed [6:0] dmix_sh, dmlp_sh;
  wire [1:0] shb;
  site_const #(.NL(NL)) u_site (.layer_oh(loh_site), .z_sh(z_sh), .c_sh(c_sh), .dmix_sh(dmix_sh),
                     .u_sh(u_sh), .v_sh(v_sh), .dmlp_sh(dmlp_sh), .shb(shb));

  wire [2:0] mat_idx = (ph == P_GATE) ? 3'd0 : (ph == P_CAND) ? 3'd1 :
                       (ph == P_PROJ) ? 3'd2 : (ph == P_FC)   ? 3'd3 : 3'd4;
  wire [ROM_AW-1:0] mt_base;
  wire [7:0]        mt_mlast;
  wire [CH_W-1:0]   mt_chlast;
  wire [1:0]        mt_shift;
  mat_desc #(.AW(ROM_AW), .CW(CH_W), .NL(NL)) u_mat (.layer_oh(loh_mat), .mat_idx(mat_idx), .base(mt_base), .m_last(mt_mlast),
                                 .ch_last(mt_chlast), .shift(mt_shift));

  wire              rn_busy, rn_done, rn_we;
  wire [BW-1:0]     rn_xidx, rn_gidx;
  wire signed [7:0] rn_g;
  wire [35:0]       rn_ss;
  wire is_norm = (ph == P_N1) || (ph == P_N2) || (ph == P_NF);

  reg signed [RESID_W-1:0] resid_rd;
  rmsnorm #(.E(E), .XW(RESID_W), .AW(BW)) u_rn (
    .clk(clk), .rst_n(rst_n), .start(go && is_norm), .norm_sel(nrm_sel), .out_sh(nrm_sh),
    .x_idx(rn_xidx), .x_data(resid_rd), .g_idx(rn_gidx), .g_data(rn_g), .g_we(rn_we),
    .ss(rn_ss), .busy(rn_busy), .done(rn_done));

  wire [1:0] src = (ph == P_PROJ) ? 2'd1 : (ph == P_DOWN) ? 2'd2 : 2'd0;
  wire [CH_W-1:0] x_chunk;
  wire [LANES*8-1:0] x_flat;
  wire signed [ACC_W-1:0] y;
  wire [7:0] y_idx;
  wire y_valid, sq_busy, sq_active;
  wire is_mm = (ph >= P_GATE) && (ph <= P_PROJ) || (ph == P_FC) || (ph == P_DOWN);

  reg [LANES*8-1:0] hwin_r;
  integer lh;
  always @(*) begin
    hwin_r = {(LANES*8){1'b0}};
    for (lh = 0; lh < NL; lh = lh + 1)
      hwin_r = hwin_r |
               ({(LANES*8){loh_h[lh]}} & hring[lh*(GN*8) +: LANES*8]);
  end
  wire [LANES*8-1:0] hwin = hwin_r;
  assign x_flat = (src == 2'd0) ? gring[LANES*8-1:0]
                : (src == 2'd1) ? hwin
                                : vring[LANES*8-1:0];

  sequencer #(.N_BANKS(N_BANKS), .LANES(LANES), .ROM_AW(ROM_AW), .ACC_W(ACC_W),
              .M_W(8), .CH_W(CH_W), .SH_W(2), .SCALE_TERMS(1), .ROUND(1),
              .ROM_LAT(ROM_LAT), .CSA_CUT(CSA_CUT), .DOT_REG(DOT_REG)) u_sq (
    .clk(clk), .rst_n(rst_n), .start(go && is_mm), .base(mt_base), .m_last(mt_mlast),
    .ch_last(mt_chlast), .shift(mt_shift), .shift2(2'd0),
    .rom_addr(rom_addr), .rom_data(rom_data), .x_chunk(x_chunk), .x_flat(x_flat),
    .y(y), .y_idx(y_idx), .y_valid(y_valid), .busy(sq_busy), .active(sq_active));

  wire signed [7:0] h_prev = hcur[7:0];
  wire [7:0] a_o, si_o;
  wire signed [7:0] c_o, h_o;
  wire signed [17:0] z_o, ha_o;
  wire signed [7:0] bias_v;
  gate_bias u_gb (.sel_oh(loh_gb), .idx(y_idx[5:0]), .data(bias_v));

  mingru #(.PIPE(MG_PIPE)) u_mg (
    .clk(clk), .tmac_gate(y), .tmac_cand(y), .h_prev(h_prev), .bias(bias_v),
    .a_ovr(abuf[y_idx[IE-1:0]]), .a_ovr_en(ph == P_CAND),
    .shb(shb), .z_sh(z_sh), .c_sh(c_sh),
    .z(z_o), .sig_idx(si_o), .a(a_o), .c(c_o), .h_acc(ha_o), .h(h_o));

  wire signed [7:0] u_o, v_o;
  wire [15:0] usq_o;
  sqrelu u_sr (.tmac_fc(y), .u_sh(u_sh), .v_sh(v_sh), .u(u_o), .usq(usq_o), .v(v_o));

  wire signed [6:0] d_sh = (ph == P_PROJ) ? dmix_sh : dmlp_sh;
  wire signed [23:0] ra_d, ra_p;
  wire signed [RESID_W-1:0] ra_y;
  resid_add #(.RESID_W(RESID_W)) u_ra (
    .x(resid_rd), .tmac_out(y), .sh(d_sh), .delta(ra_d), .presat(ra_p), .y(ra_y));

  localparam integer WBD = (MG_PIPE > RES_PIPE) ? MG_PIPE : RES_PIPE;
  reg [WBD:0]        wb_v;
  reg [(WBD+1)*8-1:0] wb_i;
  integer w;
  always @(posedge clk) begin
    if (!rst_n) begin wb_v <= 0; wb_i <= 0; end
    else begin
      wb_v[0] <= y_valid;
      wb_i[0 +: 8] <= y_idx;
      for (w = 1; w <= WBD; w = w + 1) begin
        wb_v[w] <= wb_v[w-1];
        wb_i[w*8 +: 8] <= wb_i[(w-1)*8 +: 8];
      end
    end
  end
  wire       mg_v  = (MG_PIPE == 0) ? y_valid : wb_v[MG_PIPE-1];
  wire [7:0] mg_i  = (MG_PIPE == 0) ? y_idx   : wb_i[(MG_PIPE-1)*8 +: 8];
  wire       rs_v  = (RES_PIPE == 0) ? y_valid : wb_v[RES_PIPE-1];
  wire [7:0] rs_i  = (RES_PIPE == 0) ? y_idx   : wb_i[(RES_PIPE-1)*8 +: 8];

  wire [IE-1:0] resid_ra = is_norm ? rn_xidx[IE-1:0] : y_idx[IE-1:0];
  always @(*) resid_rd = resid[resid_ra];

  reg signed [RESID_W-1:0] ra_y_q;
  always @(posedge clk) ra_y_q <= ra_y;
  wire signed [RESID_W-1:0] ra_wr = (RES_PIPE == 0) ? ra_y : ra_y_q;

  wire signed [7:0] h_wr = h_o;

  wire g_push = rn_we;
  wire g_rotl = (ph == P_GATE || ph == P_CAND || ph == P_FC) && sq_active;
  wire v_push = y_valid && (ph == P_FC);
  wire v_rotl = (ph == P_DOWN) && sq_active;
  wire h_push = (ph == P_CAND) && mg_v;
  wire h_rotl = (ph == P_PROJ) && sq_active;

  wire [GN*8-1:0] g_r1 = {gring[7:0], gring[GN*8-1:8]};
  wire [GN*8-1:0] g_rl = {gring[LANES*8-1:0], gring[GN*8-1:LANES*8]};
  wire [VN*8-1:0] v_r1 = {vring[7:0], vring[VN*8-1:8]};
  wire [VN*8-1:0] v_rl = {vring[LANES*8-1:0], vring[VN*8-1:LANES*8]};

  always @(*) begin
    hcur = {(GN*8){1'b0}};
    for (lh2 = 0; lh2 < NL; lh2 = lh2 + 1)
      hcur = hcur | ({(GN*8){loh_h[lh2]}} & hring[lh2*(GN*8) +: GN*8]);
    if (h_rotl)      hnext = {hcur[LANES*8-1:0], hcur[GN*8-1:LANES*8]};
    else if (h_push) hnext = {h_wr, hcur[GN*8-1:8]};
    else             hnext = hcur;
  end

  always @(posedge clk) begin
    if (ld_we) resid[ld_idx[IE-1:0]] <= ld_data;
    if (y_valid && ph == P_GATE) abuf[y_idx[IE-1:0]] <= a_o;
    if (rs_v && (ph == P_PROJ || ph == P_DOWN)) resid[rs_i[IE-1:0]] <= ra_wr;

    if (g_push)      gring <= {rn_g, gring[GN*8-1:8]};
    else if (g_rotl) gring <= g_rl;
    else if (gf_rot) gring <= g_r1;

    if (v_push)      vring <= {v_o, vring[VN*8-1:8]};
    else if (v_rotl) vring <= v_rl;

    if (clr_state)   hring <= {(NL*GN*8){1'b0}};
    else if (h_rotl || h_push)
      for (lw = 0; lw < NL; lw = lw + 1)
        if (loh_w[lw]) hring[lw*(GN*8) +: GN*8] <= hnext;
  end

  assign gf_data = gring[7:0];

  wire drained   = !sq_busy && !(|wb_v);
  wire ph_done   = is_norm ? rn_done : (is_mm ? (drained && !go) : 1'b1);


  always @(posedge clk) begin
    if (!rst_n) begin
      ph <= P_IDLE; layer <= 2'd0; go <= 1'b0; done <= 1'b0;
      loh_h <= {{(NL-1){1'b0}}, 1'b1}; loh_w <= {{(NL-1){1'b0}}, 1'b1};
      loh_site <= {{(NL-1){1'b0}}, 1'b1}; loh_mat <= {{(NL-1){1'b0}}, 1'b1};
      loh_gb <= {{(NL-1){1'b0}}, 1'b1};
    end
    else begin
      done <= 1'b0;
      go   <= 1'b0;
      case (ph)
        P_IDLE: if (start) begin
                  ph <= P_N1; layer <= 2'd0; go <= 1'b1;
                  loh_h <= {{(NL-1){1'b0}}, 1'b1}; loh_w <= {{(NL-1){1'b0}}, 1'b1};
                  loh_site <= {{(NL-1){1'b0}}, 1'b1}; loh_mat <= {{(NL-1){1'b0}}, 1'b1};
                  loh_gb <= {{(NL-1){1'b0}}, 1'b1};
                end
        P_DONE: begin ph <= P_IDLE; done <= 1'b1; end
        default: if (ph_done && !go) begin
          case (ph)
            P_N1:   begin ph <= P_GATE; go <= 1'b1; end
            P_GATE: begin ph <= P_CAND; go <= 1'b1; end
            P_CAND: begin ph <= P_PROJ; go <= 1'b1; end
            P_PROJ: begin ph <= P_N2;   go <= 1'b1; end
            P_N2:   begin ph <= P_FC;   go <= 1'b1; end
            P_FC:   begin ph <= P_DOWN; go <= 1'b1; end
            P_DOWN: if (layer == LAST_L_I[1:0]) begin ph <= P_NF; go <= 1'b1; end
                    else begin
                      layer <= layer + 2'd1; ph <= P_N1; go <= 1'b1;
                      loh_h <= {loh_h[NL-2:0], 1'b0};   loh_w <= {loh_w[NL-2:0], 1'b0};
                      loh_site <= {loh_site[NL-2:0], 1'b0};
                      loh_mat <= {loh_mat[NL-2:0], 1'b0};
                      loh_gb <= {loh_gb[NL-2:0], 1'b0};
                    end
            P_NF:   ph <= P_DONE;
            default: ph <= P_IDLE;
          endcase
        end
      endcase
    end
  end

  // Lint sinks.  They are part of the hardened netlist: deleting them changes synthesis.
  wire gf_idx_unused = 1'b0;
  wire _unused = &{1'b0, rn_ss, z_o, si_o, c_o, ha_o, u_o, usq_o, ra_d, ra_p,
                   rn_gidx, v_r1, x_chunk,
                   rn_busy, ld_idx[BW-1:IE], rn_gidx[BW-1:IE],
                   rn_xidx[BW-1:IE], rs_i, mg_i, gf_idx_unused, 1'b0};
endmodule
`default_nettype wire
