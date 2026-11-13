`timescale 1ns/1ps
module tb_emergency_return;
    logic passed=0,clk=0,rst_n=0,emergency_n=1;
    always #5 clk=~clk;
    logic [3:0] press=0;
    wire [2:0] floor,target,state_dbg;
    wire arrival_led,emergency_active,emergency_led;
    elevator_controller #(.STEP_CYCLES(4),.BLINK_HALF_CYCLES(2)) dut(.*);
    task automatic cycle;
        @(posedge clk); #2;
    endtask
    task automatic request(input logic [3:0] mask);
        @(negedge clk); press=mask;
        cycle();
        @(negedge clk); press=0;
    endtask
    task automatic await_state(input integer wanted);
        integer k;
        begin : bounded
            if(state_dbg==wanted) disable bounded;
            for(k=0;k<200;k=k+1) begin cycle(); if(state_dbg==wanted) disable bounded; end
            $fatal(1,"Emergency state timeout %0d",wanted);
        end
    endtask
    logic [2:0] prev_floor=1;
    integer toggles=0;
    logic last_led=0;
    always @(posedge clk) begin
        #1;
        if(!rst_n) prev_floor=1;
        else begin
            if($isunknown({floor,state_dbg,emergency_active,emergency_led})) $fatal(1,"Unknown");
            if(emergency_active) begin
                if(floor>prev_floor) $fatal(1,"Emergency allowed upward movement");
                if(arrival_led) $fatal(1,"Normal notification overrode emergency");
            end
            if(state_dbg==5 && (floor!==1 || dut.pending!==0)) $fatal(1,"Emergency hold invariant");
            prev_floor=floor;
        end
    end
    initial begin
        repeat(3) cycle();
        @(negedge clk); rst_n=1;
        request(4'b0001); // floor 4
        // Assert emergency exactly when a normal upward step would complete.
        while(!(floor==2 && dut.count==3)) cycle();
        @(negedge clk); emergency_n=0; press=4'b0010;
        cycle();
        if(floor!==2 || state_dbg!==4 || target!==1 || dut.pending!==0)
            $fatal(1,"Emergency did not win movement/request collision");
        @(negedge clk); press=0;
        await_state(5);
        if(floor!==1) $fatal(1,"Did not return to floor 1");
        last_led=emergency_led;
        repeat(32) begin
            cycle();
            if(emergency_led!=last_led) toggles=toggles+1;
            last_led=emergency_led;
        end
        if(toggles<12) $fatal(1,"Alarm did not blink continuously beyond three pulses");
        request(4'b0001); repeat(8) cycle();
        if(state_dbg!==5 || dut.pending!==0) $fatal(1,"Accepted normal call during emergency");
        @(negedge clk); emergency_n=1;
        await_state(0);
        if(emergency_active) $fatal(1,"Did not release emergency");
        request(4'b0001); await_state(3);
        if(floor!==4) $fatal(1,"Normal operation did not recover");
        await_state(0);
        // Release the switch early: still finish return to floor 1.
        @(negedge clk); emergency_n=0;
        cycle();
        @(negedge clk); emergency_n=1;
        await_state(0);
        if(floor!==1 || emergency_active) $fatal(1,"Early release cancelled return");
        // Interrupt the normal 3-flash arrival notification.
        request(4'b0010); await_state(3); // floor 3
        @(negedge clk); emergency_n=0;
        cycle();
        if(state_dbg!==4 || arrival_led) $fatal(1,"Arrival notification delayed emergency");
        await_state(5);
        repeat(12) cycle();
        if(floor!==1 || !emergency_active) $fatal(1,"Lost emergency mode");
        passed=1;
        $display("PASS: active-low emergency, return to floor 1, continuous alarm, input priority, ignored calls, early release and normal recovery");
        $finish;
    end
    initial begin #100000; $fatal(1,"Emergency watchdog"); end
endmodule
