// RMSNorm, contracts 4.1 and 4.2: one shared 20x20 signed multiplier does every product.













module rmsnorm #(
  parameter integer E   = 48,
  parameter integer XW  = 16,
  parameter integer AW  = 6,
  parameter integer SSW = 36     // contract 4.1: 48 * 32767^2 needs 36 unsigned bits
) (
  input  wire                 clk,
  input  wire                 rst_n,
  input  wire                 start,
  input  wire [2:0]           norm_sel,
  input  wire [5:0]           out_sh,
  output reg  [AW-1:0]        x_idx,
  input  wire signed [XW-1:0] x_data,
  output reg  [AW-1:0]        g_idx,
  output reg  signed [7:0]    g_data,
  output reg                  g_we,
  output reg  [SSW-1:0]       ss,
  output wire                 busy,
  output reg                  done
);
  localparam integer P_NORM = 12;
  localparam [2:0] S_IDLE = 3'd0, S_ACC = 3'd1, S_RSQ = 3'd2, S_SCALE = 3'd3, S_END = 3'd4;

  reg [2:0]  st;
  reg [AW:0] lane;
  reg [3:0]  rstep;
  reg [1:0]  ph;        // scale sub-phase

  assign busy = (st != S_IDLE);

  // ---- shared 20x20 signed multiplier -------------------------------------------
  reg  signed [19:0] ma, mb;
  wire signed [19:0] x_ext = {{(20-XW){x_data[XW-1]}}, x_data};   // XW may be 14 or 16
  wire signed [39:0] mprod = ma * mb;

  // ---- exponent path (contract 4.2) ---------------------------------------------
  reg [5:0] lz;
  integer   b;
  always @(*) begin
    lz = 6'd0;
    for (b = 0; b < SSW; b = b + 1)
      if (ss[b]) lz = b[5:0] + 6'd1;             // bit_length(ss)
  end
  wire [5:0] e2  = lz + {5'd0, lz[0]};           // round up to even
  wire [5:0] shx = 6'd15 + {1'b0, e2[5:1]};      // sh = 15 + E2/2

  // mn is ss aligned so its MSB sits at bit 29, and m6 is mn's top 6 bits: one shifter, not three.




  wire [71:0] ssx  = {6'd0, ss, 30'd0};
  wire [71:0] ssh  = ssx >> e2;
  wire [29:0] mn   = ssh[29:0];                  // Q30 mantissa
  wire [5:0]  m6   = mn[29:24];                  // top 6 bits, in [16,64)

  wire [15:0] r0;
  rsqrt_lut u_rl (.addr(m6 - 6'd16), .data(r0));

  reg [31:0] pr;
  reg [63:0] acc64;
  reg [31:0] tw;
  reg [17:0] rr;
  wire [63:0] acc64_r = acc64 + {32'd0, mprod[31:0]};
  reg [5:0]  shr;

  // ---- output rounds -------------------------------------------------------------
  wire signed [7:0] kgain;
  norm_gain u_ng (.sel(norm_sel), .idx(lane[5:0]), .data(kgain));

  // One rounding shifter serves both output rounds; only the shift amount is muxed.

  wire signed [6:0]  n_shift = {1'b0, shr} - P_NORM[6:0];
  wire signed [6:0]  r_shift = (ph == 2'd1) ? n_shift : {1'b0, out_sh};
  // both rounds are bounded by the contract: |n| <= 2^12 and |n*K| >> out_sh <= 2^11
  wire signed [15:0] rsh;
  rnd_shift #(.W(40), .SW(7), .OW(16)) u_rs (.v(mprod), .s(r_shift), .y(rsh));
  wire signed [15:0] nsh = rsh;
  wire signed [15:0] gsh = rsh;
  wire signed [7:0] gsat = (gsh > 16'sd127)  ? 8'sd127 :
                           (gsh < -16'sd127) ? -8'sd127 : gsh[7:0];

  always @(posedge clk) begin
    if (!rst_n) begin
      st <= S_IDLE; lane <= 0; ss <= {SSW{1'b0}}; done <= 1'b0; g_we <= 1'b0;
      x_idx <= {AW{1'b0}}; g_idx <= {AW{1'b0}}; rstep <= 4'd0; ph <= 2'd0;
      ma <= 20'sd0; mb <= 20'sd0; g_data <= 8'sd0;
      pr <= 32'd0; acc64 <= 64'd0; tw <= 32'd0; rr <= 18'd0; shr <= 6'd0;
    end else begin
      done <= 1'b0;
      g_we <= 1'b0;
      case (st)
        S_IDLE: if (start) begin
          st <= S_ACC; lane <= 0; ss <= {SSW{1'b0}}; x_idx <= {AW{1'b0}};
        end

        // x[i]^2, one per cycle; the product lands one cycle behind the read
        S_ACC: begin
          ma <= x_ext;
          mb <= x_ext;
          if (lane != 0) ss <= ss + mprod[SSW-1:0];
          if (lane == E[AW:0]) begin
            st <= S_RSQ; rstep <= 4'd0;
          end else begin
            lane  <= lane + 1'b1;
            x_idx <= x_idx + 1'b1;
          end
        end

        // p = r0*r0; t = (mn*p) >> 30 in four 15x16 partials; r = (r0*tw) >> 31
        S_RSQ: begin
          rstep <= rstep + 4'd1;
          case (rstep)
            4'd0: begin ma <= {4'd0, r0};        mb <= {4'd0, r0};        shr <= shx; end
            4'd1: begin pr <= mprod[31:0];                                            end
            4'd2: begin ma <= {5'd0, mn[29:15]}; mb <= {4'd0, pr[31:16]};             end
            4'd3: begin ma <= {5'd0, mn[29:15]}; mb <= {4'd0, pr[15:0]};
                        acc64 <= {32'd0, mprod[31:0]} << 31;        // (mn_h*p_h)<<31
                  end
            4'd4: begin ma <= {5'd0, mn[14:0]};  mb <= {4'd0, pr[31:16]};
                        acc64 <= acc64 + ({32'd0, mprod[31:0]} << 15);
                  end
            4'd5: begin ma <= {5'd0, mn[14:0]};  mb <= {4'd0, pr[15:0]};
                        acc64 <= acc64 + ({32'd0, mprod[31:0]} << 16);
                  end
            4'd6: begin acc64 <= acc64 + {32'd0, mprod[31:0]};                        end
            4'd7: begin tw <= 32'hC000_0000 - acc64[61:30];                           end
            4'd8: begin ma <= {4'd0, r0};        mb <= {4'd0, tw[31:16]};             end
            4'd9: begin ma <= {4'd0, r0};        mb <= {4'd0, tw[15:0]};
                        acc64 <= {32'd0, mprod[31:0]} << 16;
                  end
            default: begin
              rr    <= acc64_r[48:31];
              st    <= S_SCALE;
              lane  <= 0; ph <= 2'd0;
              x_idx <= {AW{1'b0}}; g_idx <= {AW{1'b0}};
            end
          endcase
        end

        // three cycles per lane: issue x*r, take n and issue n*K, take g
        S_SCALE: begin
          case (ph)
            2'd0: begin
              ma <= x_ext;
              mb <= {2'd0, rr};
              ph <= 2'd1;
            end
            2'd1: begin
              ma   <= {{4{nsh[15]}}, nsh};
              mb   <= {{12{kgain[7]}}, kgain};
              ph   <= 2'd2;
            end
            default: begin
              g_we   <= 1'b1;
              g_data <= gsat;
              g_idx  <= lane[AW-1:0];      // registered with the data it belongs to
              ph     <= 2'd0;
              if (lane == E[AW:0] - 1'b1) begin
                st <= S_END;
              end else begin
                lane  <= lane + 1'b1;
                x_idx <= x_idx + 1'b1;
              end
            end
          endcase
        end

        S_END: begin st <= S_IDLE; done <= 1'b1; end
        default: st <= S_IDLE;
      endcase
    end
  end

  wire _unused = &{1'b0, ssh[71:30], mprod[39:24],
                   acc64_r[63:49], acc64_r[30:0], 1'b0};
endmodule
