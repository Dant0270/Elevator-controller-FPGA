module elevator_top #(
    parameter integer STEP_CYCLES = 12000000,
    parameter integer DEBOUNCE_CYCLES = 240000,
    parameter integer BLINK_HALF_CYCLES = 3000000,
    parameter integer TONE_HALF_CYCLES = 3000, // 4 kHz với clock 12 MHz
    parameter bit LED_ACTIVE_LOW = 1'b0,
    parameter integer ARRIVAL_BEEP_CYCLES = 2400000 // 200 ms
)(
    input  logic clk_12m,
    input  logic emergency_n,
    input  logic [3:0] key_n, // KEY1->4, KEY2->3, KEY3->2, KEY4->1
    output wire [6:0] seg,
    output wire dig1_n, dp, dig2_n,
    output wire led1,
    output wire beeper
);
    logic [1:0] reset_sync = 2'b00;
    wire rst_n = reset_sync[1];

    always_ff @(posedge clk_12m)
        reset_sync <= {reset_sync[0], 1'b1};

    wire [3:0] press;
    wire [2:0] floor, target, state_dbg;
    wire arrival_led, emergency_active, emergency_led;

    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    logic [1:0] emergency_sync = 2'b11;

    always_ff @(posedge clk_12m or negedge rst_n) begin
        if (!rst_n)
            emergency_sync <= 2'b11;
        else
            emergency_sync <= {emergency_sync[0], emergency_n};
    end

    button_input #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) buttons (
        .clk(clk_12m),
        .rst_n(rst_n),
        .key_n(key_n),
        .press(press)
    );

    elevator_controller #(
        .STEP_CYCLES(STEP_CYCLES),
        .BLINK_HALF_CYCLES(BLINK_HALF_CYCLES)
    ) controller (
        .clk(clk_12m),
        .rst_n(rst_n),
        .emergency_n(emergency_sync[1]),
        .press(press),
        .floor(floor),
        .target(target),
        .state_dbg(state_dbg),
        .arrival_led(arrival_led),
        .emergency_active(emergency_active),
        .emergency_led(emergency_led)
    );

    sevenseg_decoder display (.floor(floor), .seg(seg));

    assign dig1_n = 1'b0;
    assign dp = 1'b0;
    assign dig2_n = 1'b1;

    // LED dùng tín hiệu nháy từ bộ điều khiển.
    wire status_led = emergency_active ? emergency_led : arrival_led;
    assign led1 = LED_ACTIVE_LOW ? ~status_led : status_led;

    // Mã trạng thái ARRIVED trong elevator_controller.sv.
    localparam logic [2:0] ARRIVED_STATE = 3'd3;
    localparam integer BEEP_W = (ARRIVAL_BEEP_CYCLES < 2)
                              ? 1 : $clog2(ARRIVAL_BEEP_CYCLES + 1);

    wire arrived = (state_dbg == ARRIVED_STATE);
    logic arrived_d;
    logic [BEEP_W-1:0] beep_left;
    wire beep_enable = emergency_active ? emergency_led : (beep_left != '0);

    always_ff @(posedge clk_12m or negedge rst_n) begin
        if (!rst_n) begin
            arrived_d <= 1'b0;
            beep_left <= '0;
        end else begin
            arrived_d <= arrived;

            if (emergency_active)
                beep_left <= '0;
            else if (arrived && !arrived_d)
                beep_left <= BEEP_W'(ARRIVAL_BEEP_CYCLES);
            else if (beep_left != '0)
                beep_left <= beep_left - 1'b1;
        end
    end

    buzzer_tone #(
        .HALF_PERIOD_CYCLES(TONE_HALF_CYCLES)
    ) buzzer (
        .clk(clk_12m),
        .rst_n(rst_n),
        .enable(beep_enable),
        .beeper(beeper)
    );
endmodule