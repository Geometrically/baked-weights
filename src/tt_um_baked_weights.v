`default_nettype none

// Tiny Tapeout top: one clock domain, a byte stream with valid/ready on uio, no CDC.







module tt_um_baked_weights (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  // The ship configuration L2/E40-mlp2, fixed here as localparams so nothing can override it.

  localparam integer E        = 40;
  localparam integer NL       = 2;
  localparam integer LANES    = 5;
  localparam integer N_BANKS  = 1;
  localparam integer ROM_AW   = 13;
  localparam integer RESID_W  = 14;
  localparam integer CH_W     = 4;
  localparam integer HM       = 2;
  localparam integer ROM_LAT  = 2;
  localparam integer MG_PIPE  = 1;
  localparam integer RES_PIPE = 1;
  localparam [1:0] S_RX = 2'd0, S_RUN = 2'd1, S_TX = 2'd2;
  localparam integer BW = 9;
  localparam integer RXLAST_I = 2*E - 1;
  localparam integer TXLAST_I = E - 1;

  reg [1:0]      st;
  reg [BW:0]     cnt;
  reg [7:0]      hi;
  reg            sot_l;

  wire in_valid  = uio_in[0];
  wire out_ready = uio_in[3];
  wire sot_in    = uio_in[4];

  wire signed [15:0] rx_word = {hi, ui_in};
  wire in_ready  = (st == S_RX);
  wire out_valid = (st == S_TX);

  reg  [BW-1:0]            ld_idx;
  reg  signed [RESID_W-1:0] ld_data;
  reg                      ld_we;
  reg                      start;
  reg                      clr_state;
  wire                     done;
  wire signed [7:0]        gf_data;
  wire [N_BANKS*ROM_AW-1:0] rom_addr;
  wire [N_BANKS*8-1:0]      rom_data;

  wrom #(.N_BANKS(N_BANKS), .ROM_AW(ROM_AW)) u_rom (.addr(rom_addr), .data(rom_data));

  chip_core #(.E(E), .NL(NL), .LANES(LANES), .N_BANKS(N_BANKS), .ROM_AW(ROM_AW),
              .RESID_W(RESID_W), .CH_W(CH_W), .HM(HM), .BW(BW), .ROM_LAT(ROM_LAT), .MG_PIPE(MG_PIPE),
              .RES_PIPE(RES_PIPE)) u_core (
    .clk(clk), .rst_n(rst_n), .start(start), .clr_state(clr_state), .done(done),
    .ld_idx(ld_idx), .ld_data(ld_data), .ld_we(ld_we),
    .gf_rot(out_valid && out_ready && ena), .gf_data(gf_data),
    .rom_addr(rom_addr), .rom_data(rom_data));

  always @(posedge clk) begin
    if (!rst_n) begin
      st <= S_RX; cnt <= 0; hi <= 8'd0; ld_we <= 1'b0; start <= 1'b0;
      clr_state <= 1'b0; sot_l <= 1'b0; ld_idx <= 0; ld_data <= 0;
    end else begin
      ld_we     <= 1'b0;
      start     <= 1'b0;
      clr_state <= 1'b0;
      case (st)
        S_RX: if (in_valid && ena) begin
          if (cnt[0] == 1'b0) begin
            hi <= ui_in;
            if (cnt == 0) sot_l <= sot_in;
          end else begin
            ld_idx  <= cnt[BW:1];
            ld_data <= rx_word[RESID_W-1:0];
            ld_we   <= 1'b1;
          end
          if (cnt == RXLAST_I[BW:0]) begin
            st <= S_RUN; start <= 1'b1; clr_state <= sot_l;
            cnt <= 0;
          end else cnt <= cnt + 1'b1;
        end
        S_RUN: if (done) begin st <= S_TX; cnt <= 0; end
        default: if (out_ready && ena) begin
          if (cnt == TXLAST_I[BW:0]) begin st <= S_RX; cnt <= 0; end
          else cnt <= cnt + 1'b1;
        end
      endcase
    end
  end

  assign uo_out  = gf_data;
  assign uio_out = {(st == S_TX), (st == S_RX), (st == S_RUN), 2'b00,
                    out_valid, in_ready, 1'b0};
  assign uio_oe  = 8'b1110_0110;

  wire _unused = &{1'b0, uio_in[7:5], uio_in[2:1], rx_word, 1'b0};
endmodule
`default_nettype wire
