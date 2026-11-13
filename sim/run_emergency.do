onerror {return -code error}
onbreak {resume}
vlib work_basic
vlog -sv -work work_basic ../rtl/elevator_controller.sv tb_emergency_return.sv
vsim -onfinish stop work_basic.tb_emergency_return
add wave sim:/tb_emergency_return/clk
add wave sim:/tb_emergency_return/emergency_n
add wave sim:/tb_emergency_return/emergency_active
add wave -radix unsigned sim:/tb_emergency_return/state_dbg
add wave -radix unsigned sim:/tb_emergency_return/floor
add wave -radix unsigned sim:/tb_emergency_return/target
add wave -radix binary sim:/tb_emergency_return/dut/pending
add wave sim:/tb_emergency_return/arrival_led
add wave sim:/tb_emergency_return/emergency_led
run -all
wave zoom full
