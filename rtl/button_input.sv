// Four active-low buttons: synchronize, debounce, then pulse once per press.
module button_input #(
    parameter integer DEBOUNCE_CYCLES = 240000 // 20 ms at 12 MHz
)(
    input  logic clk, rst_n,
    input  logic [3:0] key_n,
    output logic [3:0] press
);
    localparam integer W = (DEBOUNCE_CYCLES < 2) ? 1 : $clog2(DEBOUNCE_CYCLES);
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    logic [3:0] sync1, sync2;
    logic [3:0] stable;
    logic [W-1:0] count [0:3];
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= '0;
            sync2 <= '0;
            stable <= '0;
            press <= '0;
            for (i=0; i<4; i=i+1) count[i] <= '0;
        end else begin
            sync1 <= ~key_n;
            sync2 <= sync1;
            press <= '0;
            for (i=0; i<4; i=i+1) begin
                if (sync2[i] == stable[i]) count[i] <= '0;
                else if (count[i] == W'(DEBOUNCE_CYCLES-1)) begin
                    count[i] <= '0;
                    stable[i] <= sync2[i];
                    if (sync2[i]) press[i] <= 1'b1;
                end else count[i] <= count[i] + 1'b1;
            end
        end
    end
endmodule
