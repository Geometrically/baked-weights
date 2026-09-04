// Generated constant table for the bake_L2E40mlp2_v1 model - do not edit by hand.
module rsqrt_lut (
  input  wire [5:0] addr,
  output reg  [15:0] data
);
  always @(*) begin
    case (addr)
      6'd0: data = 16'd65535;
      6'd1: data = 16'd63579;
      6'd2: data = 16'd61788;
      6'd3: data = 16'd60140;
      6'd4: data = 16'd58617;
      6'd5: data = 16'd57205;
      6'd6: data = 16'd55889;
      6'd7: data = 16'd54661;
      6'd8: data = 16'd53510;
      6'd9: data = 16'd52429;
      6'd10: data = 16'd51411;
      6'd11: data = 16'd50450;
      6'd12: data = 16'd49541;
      6'd13: data = 16'd48679;
      6'd14: data = 16'd47861;
      6'd15: data = 16'd47082;
      6'd16: data = 16'd46341;
      6'd17: data = 16'd45633;
      6'd18: data = 16'd44957;
      6'd19: data = 16'd44310;
      6'd20: data = 16'd43691;
      6'd21: data = 16'd43096;
      6'd22: data = 16'd42525;
      6'd23: data = 16'd41977;
      6'd24: data = 16'd41449;
      6'd25: data = 16'd40940;
      6'd26: data = 16'd40450;
      6'd27: data = 16'd39977;
      6'd28: data = 16'd39520;
      6'd29: data = 16'd39078;
      6'd30: data = 16'd38651;
      6'd31: data = 16'd38238;
      6'd32: data = 16'd37837;
      6'd33: data = 16'd37449;
      6'd34: data = 16'd37073;
      6'd35: data = 16'd36708;
      6'd36: data = 16'd36353;
      6'd37: data = 16'd36008;
      6'd38: data = 16'd35673;
      6'd39: data = 16'd35347;
      6'd40: data = 16'd35030;
      6'd41: data = 16'd34722;
      6'd42: data = 16'd34421;
      6'd43: data = 16'd34128;
      6'd44: data = 16'd33843;
      6'd45: data = 16'd33564;
      6'd46: data = 16'd33292;
      6'd47: data = 16'd33027;
      default: data = 16'd0;
    endcase
  end
endmodule
