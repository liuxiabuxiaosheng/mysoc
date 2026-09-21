# AX7010 I2S external Codec template.
# Replace every <...> value from the selected Codec and AX7010 expansion-header schematic.
# Do not use this file unchanged for implementation.

# set_property PACKAGE_PIN <BCLK_PIN> [get_ports i2s_bclk]
# set_property PACKAGE_PIN <LRCLK_PIN> [get_ports i2s_lrclk]
# set_property PACKAGE_PIN <SDIN_PIN> [get_ports i2s_sdata_in]
# set_property PACKAGE_PIN <SDOUT_PIN> [get_ports i2s_sdata_out]
# set_property IOSTANDARD LVCMOS33 [get_ports {i2s_bclk i2s_lrclk i2s_sdata_in i2s_sdata_out}]

# create_clock -name i2s_bclk -period <BCLK_PERIOD_NS> [get_ports i2s_bclk]
# set_input_delay  -clock [get_clocks i2s_bclk] <SDIN_INPUT_DELAY_NS> [get_ports i2s_sdata_in]
# set_output_delay -clock [get_clocks i2s_bclk] <SDOUT_OUTPUT_DELAY_NS> [get_ports i2s_sdata_out]
