onerror {return -code error}
onbreak {resume}
vlib work_basic
vlog -sv -work work_basic ../rtl/buzzer_tone.sv tb_buzzer_tone.sv
vsim -onfinish stop work_basic.tb_buzzer_tone
add wave sim:/tb_buzzer_tone/clk
add wave sim:/tb_buzzer_tone/rst_n
add wave sim:/tb_buzzer_tone/enable
add wave -radix unsigned sim:/tb_buzzer_tone/dut/count
add wave sim:/tb_buzzer_tone/dut/tone
add wave sim:/tb_buzzer_tone/beeper
run -all
wave zoom full
