module buzzer_tone #(
    parameter integer HALF_PERIOD_CYCLES=3000
)(
    input logic clk,rst_n,enable,
    output wire beeper
);
    localparam integer W=(HALF_PERIOD_CYCLES<2) ? 1 : $clog2(HALF_PERIOD_CYCLES);
    logic [W-1:0] count;
    logic tone;
    assign beeper=rst_n && enable && tone;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin count<='0; tone<=1'b0; end
        else if(!enable) begin count<='0; tone<=1'b0; end
        else if(count==W'(HALF_PERIOD_CYCLES-1)) begin
            count<='0;
            tone<=~tone;
        end else count<=count+1'b1;
    end
endmodule
