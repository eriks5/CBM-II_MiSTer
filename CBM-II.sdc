derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

set_multicycle_path -from {emu|main|*} -to {emu|sdram|*} -setup 3
set_multicycle_path -from {emu|main|*} -to {emu|sdram|*} -hold 1

set_false_path -to   {emu|sdram|*}
set_false_path -from {emu|sdram|*}
set_false_path -from {emu|main|cpu|cpu|MCycle*}
# set_false_path -from {emu|main|cpu|cpu|*} -to {emu|main|acia|*}

set_multicycle_path -to {*Hq2x*} -setup 2
set_multicycle_path -to {*Hq2x*} -hold 1
set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -setup 2
set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -hold 1
