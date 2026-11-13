# Batch mode: vsim -c -do test_all.do
onerror {quit -code 1}
onbreak {resume}
vlib work_basic
vlog -sv -work work_basic ../rtl/button_input.sv ../rtl/elevator_controller.sv ../rtl/sevenseg_decoder.sv ../rtl/buzzer_tone.sv ../rtl/elevator_top.sv tb_elevator_controller.sv tb_elevator_top.sv tb_emergency_return.sv tb_buzzer_tone.sv
vsim -onfinish stop work_basic.tb_elevator_controller
run -all
if {[examine -radix unsigned sim:/tb_elevator_controller/passed] != 1} {quit -code 1}
quit -sim
vsim -onfinish stop work_basic.tb_elevator_top
run -all
if {[examine -radix unsigned sim:/tb_elevator_top/passed] != 1} {quit -code 1}
quit -sim
vsim -onfinish stop work_basic.tb_emergency_return
run -all
if {[examine -radix unsigned sim:/tb_emergency_return/passed] != 1} {quit -code 1}
quit -sim
vsim -onfinish stop work_basic.tb_buzzer_tone
run -all
if {[examine -radix unsigned sim:/tb_buzzer_tone/passed] != 1} {quit -code 1}
quit -code 0
