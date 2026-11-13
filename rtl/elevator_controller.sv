module elevator_controller #(
    parameter integer STEP_CYCLES = 12000000,
    parameter integer BLINK_HALF_CYCLES = 3000000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic emergency_n, // synchronized: 1 normal, 0 return to floor 1
    input  logic [3:0] press,

    output logic [2:0] floor,
    output logic [2:0] target,
    output wire  [2:0] state_dbg,
    output wire        arrival_led,
    output wire emergency_active, emergency_led
);
typedef enum logic [2:0] {
    IDLE    = 3'd0,
    UP      = 3'd1,
    DOWN    = 3'd2,
    ARRIVED = 3'd3,
    EMERGENCY_RETURN = 3'd4,
    EMERGENCY_WAIT = 3'd5
} state_t;

state_t state, next_state;

    localparam integer W =
        (STEP_CYCLES < 2) ? 1 : $clog2(STEP_CYCLES);

    logic [W-1:0] count;

    // Bộ nhớ yêu cầu:
    // bit 0 -> tầng 1
    // bit 1 -> tầng 2
    // bit 2 -> tầng 3
    // bit 3 -> tầng 4
    logic [3:0] pending;
    logic [3:0] pending_next;

    wire [3:0] new_requests;
    wire [3:0] waiting;

    logic [3:0] served_mask;
    logic [2:0] selected;

    wire valid;
    wire step_done;

    assign state_dbg = state;

    // Đảo thứ tự nút theo yêu cầu:
    // KEY1 -> tầng 4, KEY2 -> tầng 3,
    // KEY3 -> tầng 2, KEY4 -> tầng 1.
    assign new_requests = {
        press[0],
        press[1],
        press[2],
        press[3]
    };

    // Gồm yêu cầu đã nhớ và yêu cầu vừa nhận.
    assign waiting = pending | new_requests;
    assign valid = |waiting;

    assign step_done =
        (count == W'(STEP_CYCLES - 1));

    // Three flashes = six half-periods: ON OFF ON OFF ON OFF.
    localparam integer BLINK_W = (BLINK_HALF_CYCLES < 2)
                               ? 1 : $clog2(BLINK_HALF_CYCLES);
    logic [BLINK_W-1:0] blink_count;
    logic [2:0] blink_phase;
    wire blink_half_done =
        (blink_count == BLINK_W'(BLINK_HALF_CYCLES-1));
    wire blink_done = (blink_phase == 3'd5) && blink_half_done;
    assign emergency_active = rst_n && (!emergency_n ||
        state == EMERGENCY_RETURN || state == EMERGENCY_WAIT);
    assign arrival_led = (state == ARRIVED) && !emergency_active && !blink_phase[0];
    logic [BLINK_W-1:0] alarm_count;
    logic alarm_on;
    assign emergency_led = emergency_active && alarm_on;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin alarm_count <= '0; alarm_on <= 1'b1; end
        else if (!emergency_active) begin alarm_count <= '0; alarm_on <= 1'b1; end
        else if (alarm_count == BLINK_W'(BLINK_HALF_CYCLES-1)) begin
            alarm_count <= '0;
            alarm_on <= ~alarm_on;
        end else alarm_count <= alarm_count + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_count <= '0;
            blink_phase <= '0;
        end else if (state != ARRIVED || emergency_active) begin
            blink_count <= '0;
            blink_phase <= '0;
        end else if (blink_half_done) begin
            blink_count <= '0;
            if (blink_phase < 3'd5) blink_phase <= blink_phase + 1'b1;
        end else blink_count <= blink_count + 1'b1;
    end

    // =========================================
    // 1. Chọn tầng đang chờ gần nhất
    // Nếu bằng khoảng cách, ưu tiên tầng thấp.
    // =========================================
    always_comb begin
        selected = floor;

        case (floor)
            3'd1: begin
                if      (waiting[0]) selected = 3'd1;
                else if (waiting[1]) selected = 3'd2;
                else if (waiting[2]) selected = 3'd3;
                else if (waiting[3]) selected = 3'd4;
            end

            3'd2: begin
                if      (waiting[1]) selected = 3'd2;
                else if (waiting[0]) selected = 3'd1;
                else if (waiting[2]) selected = 3'd3;
                else if (waiting[3]) selected = 3'd4;
            end

            3'd3: begin
                if      (waiting[2]) selected = 3'd3;
                else if (waiting[1]) selected = 3'd2;
                else if (waiting[3]) selected = 3'd4;
                else if (waiting[0]) selected = 3'd1;
            end

            3'd4: begin
                if      (waiting[3]) selected = 3'd4;
                else if (waiting[2]) selected = 3'd3;
                else if (waiting[1]) selected = 3'd2;
                else if (waiting[0]) selected = 3'd1;
            end

            default: selected = 3'd1;
        endcase
    end

    // =========================================
    // 2. Tính trạng thái tiếp theo
    // =========================================
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (valid) begin
                    if (selected > floor)
                        next_state = UP;
                    else if (selected < floor)
                        next_state = DOWN;
                end
            end

            UP: begin
                if (step_done &&
                    floor + 3'd1 == target)
                    next_state = ARRIVED;
            end

            DOWN: begin
                if (step_done &&
                    floor - 3'd1 == target)
                    next_state = ARRIVED;
            end

            ARRIVED: if (blink_done) next_state = IDLE;

            EMERGENCY_RETURN: begin
                if (floor == 3'd1 || (step_done && floor == 3'd2))
                    next_state = EMERGENCY_WAIT;
            end
            EMERGENCY_WAIT: if (emergency_n) next_state = IDLE;
            default: next_state = IDLE;
        endcase
        // Emergency entry wins over normal movement and arrival completion.
        if (!emergency_n && state != EMERGENCY_RETURN && state != EMERGENCY_WAIT)
            next_state = (floor == 3'd1) ? EMERGENCY_WAIT : EMERGENCY_RETURN;
    end

    // =========================================
    // 3. Xác định yêu cầu đã được phục vụ
    // =========================================
    always_comb begin
        served_mask = 4'b0000;

        case (state)
            IDLE: begin
                // Gọi ngay tầng hiện tại:
                // phục vụ tại chỗ, không di chuyển.
                if (valid && selected == floor)
                    served_mask =
                        4'b0001 << (floor - 3'd1);
            end

            UP: begin
                // Hoàn thành chặng cuối đi lên.
                if (step_done &&
                    floor + 3'd1 == target)
                    served_mask =
                        4'b0001 << (target - 3'd1);
            end

            DOWN: begin
                // Hoàn thành chặng cuối đi xuống.
                if (step_done &&
                    floor - 3'd1 == target)
                    served_mask =
                        4'b0001 << (target - 3'd1);
            end

            ARRIVED: served_mask = 4'b0001 << (floor - 3'd1);

            default: served_mask = 4'b0000;
        endcase

        // Xóa yêu cầu đã phục vụ.
        // Yêu cầu mới cùng chu kỳ được ưu tiên giữ lại.
        pending_next =
            (pending & ~served_mask) | new_requests;
    end

    // =========================================
    // 4. Thanh ghi trạng thái và dữ liệu
    // =========================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            floor   <= 3'd1;
            target  <= 3'd1;
            count   <= '0;
            pending <= 4'b0000;
        end else begin
            state   <= next_state;

            // Luôn ghi nhận yêu cầu, kể cả đang đi.
            pending <= pending_next;

            if (emergency_active) begin
                pending <= '0;
                target <= 3'd1;
                if (state == EMERGENCY_RETURN && floor > 3'd1) begin
                    if (step_done) begin
                        floor <= floor - 3'd1;
                        count <= '0;
                    end else count <= count + 1'b1;
                end else count <= '0;
            end else case (state)
                IDLE: begin
                    count <= '0;

                    // Chỉ chọn đích mới khi đang chờ.
                    if (valid)
                        target <= selected;
                end

                UP, DOWN: begin
                    if (step_done) begin
                        count <= '0;

                        if (state == UP)
                            floor <= floor + 3'd1;
                        else
                            floor <= floor - 3'd1;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                default: count <= '0;
            endcase
        end
    end

endmodule
