`timescale 1ns/1ps
module tb_buzzer_tone;
    logic passed=0,clk=0,rst_n=0,enable=0;
    wire beeper;
    always #5 clk=~clk;
    buzzer_tone #(.HALF_PERIOD_CYCLES(3)) dut(.*);
    task automatic cycle;
        @(posedge clk); #1;
    endtask
    initial begin
        repeat(2) cycle();
        @(negedge clk); rst_n=1;
        repeat(4) begin cycle(); if(beeper!==0) $fatal(1,"Idle not silent"); end
        @(negedge clk); enable=1;
        for(integer k=1;k<=18;k=k+1) begin
            cycle();
            if(beeper!==((k/3)%2==1)) $fatal(1,"Wrong carrier half-period at %0d",k);
        end
        // Stop while the carrier is high: output must be gated immediately.
        repeat(3) cycle();
        @(negedge clk); enable=0;
        #1; if(beeper!==0) $fatal(1,"Enable did not silence output");
        repeat(3) cycle();
        @(negedge clk); enable=1;
        repeat(3) cycle();
        if(beeper!==1) $fatal(1,"Carrier restart failed");
        @(negedge clk); rst_n=0;
        #1; if(beeper!==0) $fatal(1,"Reset did not silence output");
        passed=1;
        $display("PASS: buzzer carrier period, idle silence, enable gating, restart and reset");
        $finish;
    end
    initial begin #10000; $fatal(1,"Buzzer watchdog"); end
endmodule
