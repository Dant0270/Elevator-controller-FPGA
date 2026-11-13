// Actual floor numbers 1..4. Active-high seg[6:0]={g,f,e,d,c,b,a}.
// FPGA pins: a=E1 b=D2 c=K2 d=J2 e=G2 f=F5 g=G5.
module sevenseg_decoder (
    input  logic [2:0] floor,
    output logic [6:0] seg
);
    always_comb begin
        case (floor)
            3'd1: seg=7'b0000110; // 1
            3'd2: seg=7'b1011011; // 2
            3'd3: seg=7'b1001111; // 3
            3'd4: seg=7'b1100110; // 4
            default: seg=7'b0000000;
        endcase
    end
endmodule
