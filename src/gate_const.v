// Generated constant table for the bake_L2E40mlp2_v1 model - do not edit by hand.
module gate_bias (
  input  wire [1:0] sel_oh,
  input  wire [5:0] idx,
  output reg  signed [7:0] data
);
  reg signed [7:0] d0;
  reg signed [7:0] d1;
  always @(*) begin
    case (idx)
      6'd0: d0 = 8'sd22;
      6'd1: d0 = 8'sd9;
      6'd2: d0 = -8'sd63;
      6'd3: d0 = -8'sd17;
      6'd4: d0 = -8'sd17;
      6'd5: d0 = 8'sd1;
      6'd6: d0 = 8'sd8;
      6'd7: d0 = 8'sd13;
      6'd8: d0 = 8'sd28;
      6'd9: d0 = 8'sd18;
      6'd10: d0 = 8'sd11;
      6'd11: d0 = 8'sd105;
      6'd12: d0 = 8'sd12;
      6'd13: d0 = 8'sd7;
      6'd14: d0 = -8'sd2;
      6'd15: d0 = -8'sd7;
      6'd16: d0 = 8'sd2;
      6'd17: d0 = 8'sd22;
      6'd18: d0 = 8'sd18;
      6'd19: d0 = 8'sd37;
      6'd20: d0 = 8'sd22;
      6'd21: d0 = 8'sd7;
      6'd22: d0 = 8'sd13;
      6'd23: d0 = -8'sd2;
      6'd24: d0 = -8'sd4;
      6'd25: d0 = 8'sd24;
      6'd26: d0 = 8'sd66;
      6'd27: d0 = 8'sd39;
      6'd28: d0 = -8'sd7;
      6'd29: d0 = 8'sd5;
      6'd30: d0 = 8'sd27;
      6'd31: d0 = 8'sd22;
      6'd32: d0 = -8'sd1;
      6'd33: d0 = 8'sd1;
      6'd34: d0 = 8'sd11;
      6'd35: d0 = 8'sd12;
      6'd36: d0 = -8'sd10;
      6'd37: d0 = 8'sd13;
      6'd38: d0 = 8'sd1;
      6'd39: d0 = 8'sd25;
      default: d0 = 8'sd0;
    endcase
  end
  always @(*) begin
    case (idx)
      6'd0: d1 = -8'sd39;
      6'd1: d1 = 8'sd12;
      6'd2: d1 = -8'sd33;
      6'd3: d1 = -8'sd15;
      6'd4: d1 = 8'sd33;
      6'd5: d1 = 8'sd98;
      6'd6: d1 = 8'sd51;
      6'd7: d1 = 8'sd29;
      6'd8: d1 = 8'sd82;
      6'd9: d1 = 8'sd31;
      6'd10: d1 = 8'sd0;
      6'd11: d1 = 8'sd9;
      6'd12: d1 = 8'sd28;
      6'd13: d1 = 8'sd94;
      6'd14: d1 = 8'sd27;
      6'd15: d1 = -8'sd35;
      6'd16: d1 = 8'sd95;
      6'd17: d1 = 8'sd39;
      6'd18: d1 = 8'sd16;
      6'd19: d1 = -8'sd29;
      6'd20: d1 = -8'sd2;
      6'd21: d1 = 8'sd32;
      6'd22: d1 = -8'sd25;
      6'd23: d1 = -8'sd44;
      6'd24: d1 = 8'sd49;
      6'd25: d1 = -8'sd3;
      6'd26: d1 = 8'sd16;
      6'd27: d1 = -8'sd2;
      6'd28: d1 = 8'sd12;
      6'd29: d1 = 8'sd9;
      6'd30: d1 = 8'sd29;
      6'd31: d1 = -8'sd12;
      6'd32: d1 = -8'sd8;
      6'd33: d1 = 8'sd42;
      6'd34: d1 = 8'sd2;
      6'd35: d1 = 8'sd4;
      6'd36: d1 = 8'sd27;
      6'd37: d1 = 8'sd43;
      6'd38: d1 = -8'sd9;
      6'd39: d1 = -8'sd39;
      default: d1 = 8'sd0;
    endcase
  end
  always @(*)
    data = ({8{sel_oh[0]}} & d0) |
           ({8{sel_oh[1]}} & d1);
endmodule
