# ALINX AX7010 board constraints for the current rtl/top/soc_top.sv top level.
#
# Evidence source:
# - AX7010 official example XDC files: pll.xdc, rs232.xdc, led.xdc, and key.xdc.
# - AX7010/AX7020 development-board schematic V2.0.
#
# Active constraints below use only ports that exist on the current soc_top.
# Do not add example XDC files to the same Vivado project: their sys_clk/clk
# and led/key port names either do not exist here or conflict with this file.

# 50 MHz PL global clock. U18 is an MRCC input in bank 34.
create_clock -name clk_50m -period 20.000 -waveform {0.000 10.000} [get_ports {clk_50m}]
set_property PACKAGE_PIN U18 [get_ports {clk_50m}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_50m}]

# Active-low reset. The official examples use the PL key at N15 as rst_n.
set_property PACKAGE_PIN N15 [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]

# UART signals on the J11 expansion-header route used by the official RS232 example.
set_property PACKAGE_PIN J19 [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]

set_property PACKAGE_PIN K19 [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]

# LED1 shows board-top reset and clock readiness.
set_property PACKAGE_PIN M14 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

# Optional user LEDs. Uncomment only after the physical top-level exposes
# led[3:0]; these cannot be applied to the current soc_top.
# set_property PACKAGE_PIN M14 [get_ports {led[0]}]
# set_property PACKAGE_PIN M15 [get_ports {led[1]}]
# set_property PACKAGE_PIN K16 [get_ports {led[2]}]
# set_property PACKAGE_PIN J16 [get_ports {led[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# Optional PL keys. N15 is already allocated to rst_n, so do not enable
# key[0] together with this reset mapping. Uncomment only after a board wrapper
# exposes the corresponding key ports.
# set_property PACKAGE_PIN N16 [get_ports {key[1]}]
# set_property PACKAGE_PIN T17 [get_ports {key[2]}]
# set_property PACKAGE_PIN R17 [get_ports {key[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {key[*]}]

# I2S remains intentionally unconstrained. Its J10/J11 pin assignment, codec
# electrical standard, BCLK frequency, and input/output delays must come from
# the selected external audio module. Start from ax7010_i2s_template.xdc after
# those facts are known.
