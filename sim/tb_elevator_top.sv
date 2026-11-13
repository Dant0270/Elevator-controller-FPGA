`timescale 1ns/1ps
module tb_elevator_top;
    logic passed=0,clk_12m=0,emergency_n=1;
    logic [3:0] key_n=4'b1111;
    always #5 clk_12m=~clk_12m;
    wire [6:0] seg;
    wire dig1_n,dp,dig2_n,led1,led1_inverted,beeper,beeper_inverted;
    elevator_top #(.STEP_CYCLES(80),.DEBOUNCE_CYCLES(3),
                   .BLINK_HALF_CYCLES(2),.TONE_HALF_CYCLES(1)) dut(.*);
    elevator_top #(.STEP_CYCLES(80),.DEBOUNCE_CYCLES(3),
                   .BLINK_HALF_CYCLES(2),.TONE_HALF_CYCLES(1),.LED_ACTIVE_LOW(1)) low_dut(
        .clk_12m(clk_12m),.emergency_n(emergency_n),.key_n(key_n),.seg(),.dig1_n(),.dp(),
        .dig2_n(),.led1(led1_inverted),.beeper(beeper_inverted));
    integer presses=0;
    integer arrival_tone_samples=0, emergency_tone_samples=0;
    task automatic cycle;
        @(posedge clk_12m); #2;
    endtask
    task automatic await_floor(input integer wanted);
        integer k;
        begin : bounded
            for(k=0;k<400;k=k+1) begin
                cycle();
                if(int'(dut.floor)==wanted && dut.state_dbg==0) disable bounded;
            end
            $fatal(1,"Top travel/notification timeout");
        end
    endtask
    function automatic logic [6:0] segments(input logic [2:0] f);
        case(f)
            1: segments=7'b0000110;
            2: segments=7'b1011011;
            3: segments=7'b1001111;
            4: segments=7'b1100110;
            default: segments=7'b0000000;
        endcase
    endfunction
    always @(posedge clk_12m) begin
        #1;
        if(!dut.rst_n) presses=0;
        else begin
            if(dut.press!=0) presses=presses+1;
            if($isunknown(beeper)) $fatal(1,"Unknown buzzer output");
            if(!dut.status_led && beeper!==0) $fatal(1,"Buzzer active in silent interval");
            if(beeper!==beeper_inverted) $fatal(1,"Buzzer depends on physical LED polarity");
            if(beeper && dut.arrival_led) arrival_tone_samples=arrival_tone_samples+1;
            if(beeper && dut.emergency_active) emergency_tone_samples=emergency_tone_samples+1;
            if(seg!==segments(dut.floor)) $fatal(1,"Wrong active-high display");
            if({dig1_n,dp,dig2_n}!==3'b001) $fatal(1,"Display enable/DP incorrect");
            if(led1!==dut.status_led || led1_inverted!==~led1) $fatal(1,"LED polarity adapter incorrect");
        end
    end
    initial begin
        repeat(6) cycle();
        if(dut.floor!==1 || dut.rst_n!==1) $fatal(1,"Startup reset failed");
        // Bounce shorter than debounce threshold is ignored.
        @(negedge clk_12m); key_n=4'b1110;
        @(negedge clk_12m); key_n=4'b1111;
        repeat(10) cycle();
        if(presses!=0) $fatal(1,"Bounce accepted");
        for(integer key=0;key<4;key=key+1) begin
            @(negedge clk_12m); key_n=~(4'b0001 << key);
            repeat(10) cycle();
            if(int'(dut.target)!=4-key) $fatal(1,"Reversed key mapping incorrect");
            await_floor(4-key); // includes all three arrival flashes
            repeat(20) cycle(); // held key must not trigger another request
            if(presses!=key+1) $fatal(1,"Held key generated repeated calls");
            @(negedge clk_12m); key_n=4'b1111;
            repeat(10) cycle();
        end
        // Assert raw active-low SW4, verify synchronized emergency at floor 1.
        @(negedge clk_12m); emergency_n=0;
        repeat(6) cycle();
        if(dut.state_dbg!==5 || !dut.emergency_active) $fatal(1,"SW4 low did not enter emergency");
        repeat(16) cycle();
        if(dut.floor!==1 || dut.controller.pending!==0) $fatal(1,"Emergency hold failed");
        @(negedge clk_12m); emergency_n=1;
        repeat(6) cycle();
        if(dut.state_dbg!==0 || dut.emergency_active) $fatal(1,"SW4 high did not release mode");
        if(arrival_tone_samples==0 || emergency_tone_samples==0)
            $fatal(1,"Missing arrival or emergency tone");
        if(beeper!==0) $fatal(1,"Buzzer did not stop after emergency");
        passed=1;
        $display("PASS: startup and active-low SW4, KEY1..4 -> floors 4..1, active-high digits, three-flash integration, buzzer arrival/emergency gating and LED polarity adapter");
        $finish;
    end
    initial begin #200000; $fatal(1,"Top watchdog"); end
endmodule
