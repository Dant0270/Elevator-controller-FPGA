# ModelSim GUI: run this from elevator_basic/sim. Keep waveforms at $finish.
onerror {return -code error}
onbreak {resume}
vlib work_basic
vlog -sv -work work_basic ../rtl/button_input.sv ../rtl/elevator_controller.sv ../rtl/sevenseg_decoder.sv ../rtl/buzzer_tone.sv ../rtl/elevator_top.sv tb_elevator_top.sv
vsim -onfinish stop work_basic.tb_elevator_top
add wave sim:/tb_elevator_top/clk_12m
add wave sim:/tb_elevator_top/dut/rst_n
add wave -radix binary sim:/tb_elevator_top/key_n
add wave -radix binary sim:/tb_elevator_top/dut/press
add wave -radix unsigned sim:/tb_elevator_top/dut/state_dbg
add wave -radix unsigned sim:/tb_elevator_top/dut/floor
add wave -radix unsigned sim:/tb_elevator_top/dut/target
add wave -radix unsigned sim:/tb_elevator_top/dut/controller/count
add wave -radix binary sim:/tb_elevator_top/seg
add wave -radix binary sim:/tb_elevator_top/dut/controller/pending
add wave sim:/tb_elevator_top/led1
add wave -radix unsigned sim:/tb_elevator_top/dut/controller/blink_phase
add wave sim:/tb_elevator_top/emergency_n
add wave sim:/tb_elevator_top/dut/emergency_active
add wave -divider {Buzzer}
add wave sim:/tb_elevator_top/dut/status_led
add wave sim:/tb_elevator_top/dut/buzzer/tone
add wave sim:/tb_elevator_top/beeper
run -all
wave zoom full
