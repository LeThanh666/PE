# 1.Clock (sys_clk) Duty Cycle 50%
create_clock -name sys_clk -period 1.81 -waveform {0 0.905} [get_ports sys_clk]

set_clock_transition -rise 0.1 [get_clocks sys_clk]
set_clock_transition -fall 0.1 [get_clocks sys_clk]
set_clock_uncertainty 0.05 [get_clocks sys_clk]


set_input_delay -max 0.35 -clock sys_clk [remove_from_collection [all_inputs] [get_ports sys_clk]]
set_input_delay -min 0.1 -clock sys_clk [remove_from_collection [all_inputs] [get_ports sys_clk]]

set_output_delay -max 0.35 -clock sys_clk [all_outputs]
set_output_delay -min 0.1 -clock sys_clk [all_outputs]

#  (Driving cell / Load)
set_input_transition 0.1 [all_inputs]
set_load 0.05 [all_outputs]
