create_clock -name clk_12m -period 83.333 [get_ports {clk_12m}]
derive_clock_uncertainty
# Board I/O and asynchronous paths still need review before full timing sign-off.
