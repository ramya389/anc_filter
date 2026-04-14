## ================================
## CLOCK CONSTRAINT (50 MHz)
## ================================

create_clock -period 20.000 -name sys_clk [get_ports clk]


## ================================
## INPUT DELAY
## ================================

set_input_delay -clock sys_clk 2.0 [all_inputs]


## ================================
## OUTPUT DELAY
## ================================

set_output_delay -clock sys_clk 2.0 [all_outputs]


## ================================
## RESET FALSE PATH (if exists)
## ================================

set_false_path -from [get_ports rst]


## ================================
## CLOCK UNCERTAINTY
## ================================

set_clock_uncertainty 0.2 [get_clocks sys_clk]