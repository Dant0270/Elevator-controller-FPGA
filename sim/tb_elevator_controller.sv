`timescale 1ns/1ps
module tb_elevator_controller;
    logic passed=0,clk=0,rst_n=0,emergency_n=1;
    always #5 clk=~clk;
    logic [3:0] press=0;
    wire [2:0] floor,target;
    wire [2:0] state_dbg;
    wire arrival_led,emergency_active,emergency_led;
    elevator_controller #(.STEP_CYCLES(4),.BLINK_HALF_CYCLES(2)) dut(.*);
    logic [3:0] edge_press=0;
    wire [2:0] edge_floor,edge_target;
    wire [2:0] edge_state;
    wire edge_led;
    elevator_controller #(.STEP_CYCLES(1),.BLINK_HALF_CYCLES(1)) edge_dut(
        .clk(clk),.rst_n(rst_n),.emergency_n(1'b1),.press(edge_press),.floor(edge_floor),
        .target(edge_target),.state_dbg(edge_state),.arrival_led(edge_led),.emergency_active(),.emergency_led());
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
            for(k=0;k<300;k=k+1) begin cycle(); if(state_dbg==wanted) disable bounded; end
            $fatal(1,"State timeout %0d",wanted);
        end
    endtask
    integer clocks=0,entry_clock=0,rises=0,arrivals=0;
    logic [2:0] previous_state=0;
    logic previous_led=0;
    logic [2:0] stopped_floor;
    // Independent temporal assertions: exact six half-periods and three pulses.
    always @(posedge clk) begin
        #1;
        if(!rst_n) begin clocks=0; previous_state=0; previous_led=0; arrivals=0; end
        else begin
            clocks=clocks+1;
            if($isunknown({floor,target,state_dbg,arrival_led,dut.pending})) $fatal(1,"Unknown output");
            if(floor<1 || floor>4) $fatal(1,"Floor out of range");
            if(state_dbg==3) begin
                if(previous_state!=3) begin
                    entry_clock=clocks; rises=0; stopped_floor=floor; arrivals=arrivals+1;
                end
                if(floor!==stopped_floor) $fatal(1,"Moved during arrival notification");
                if(arrival_led!==(((clocks-entry_clock)/2)%2==0))
                    $fatal(1,"Incorrect ON/OFF duration");
                if(arrival_led && !previous_led) rises=rises+1;
            end else begin
                if(arrival_led) $fatal(1,"LED lit outside ARRIVED");
                if(previous_state==3 && (clocks-entry_clock!=12 || rises!=3))
                    $fatal(1,"Must finish exactly three complete flashes before leaving");
            end
            previous_state=state_dbg; previous_led=arrival_led;
        end
    end
    initial begin
        repeat(3) cycle();
        @(negedge clk); rst_n=1;
        cycle();
        if(floor!==1 || dut.pending!==0) $fatal(1,"Startup failed");
        request(4'b0001); // KEY1 -> floor 4
        if(target!==4 || state_dbg!==1) $fatal(1,"KEY1 mapping failed");
        request(4'b0010); // KEY2 -> floor 3, queue while moving
        if(target!==4) $fatal(1,"Active destination changed");
        await_state(3);
        if(floor!==4) $fatal(1,"First arrival wrong");
        request(4'b0100); // KEY3 -> floor 2, queue during flashes
        await_state(2); await_state(3);
        if(floor!==3) $fatal(1,"Nearest queued floor should be 3");
        await_state(2); await_state(3);
        if(floor!==2) $fatal(1,"Request during flashing was lost");
        await_state(0);
        repeat(10) cycle();
        if(arrivals!=3 || dut.pending!==0) $fatal(1,"Wrong service count/queue");
        request(4'b0100); // already at floor 2: consume without another trip
        repeat(10) cycle();
        if(arrivals!=3 || state_dbg!==0) $fatal(1,"Same-floor call retriggered travel");
        request(4'b1010); // floors 1 and 3 tie: choose 1 first
        await_state(3); if(floor!==1) $fatal(1,"Tie priority failed");
        await_state(1); await_state(3);
        if(floor!==3) $fatal(1,"Other simultaneous call lost");
        await_state(0);
        // Counter boundary: one clock per movement step/half-blink.
        @(negedge clk); edge_press=4'b0001;
        cycle();
        @(negedge clk); edge_press=0;
        repeat(3) cycle();
        if(edge_floor!==4 || edge_state!==3 || edge_led!==1) $fatal(1,"Unit timing arrival failed");
        for(integer k=1;k<=6;k=k+1) begin
            cycle();
            if(k<6 && (edge_state!==3 || edge_led!==(k%2==0))) $fatal(1,"Unit blink phase failed");
        end
        if(edge_state!==0 || edge_led!==0) $fatal(1,"Unit timing did not finish");
        passed=1;
        $display("PASS: three exact flashes, no motion while blinking, queued calls during motion/blink, reverse KEY mapping and timing boundary");
        $finish;
    end
    initial begin #100000; $fatal(1,"Controller watchdog"); end
endmodule
