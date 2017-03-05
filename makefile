
DE: iverilog

## CONFIGURE O AMBIENTE COM:
## source setup-env.sh

# simulation with isim
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx13_1/ism_r_entering_simulation_tcl_commands.htm

top = part_tester
top_tb = tb
target = xc3s1200e-fg320-4
ucf = nexsy2-1200.ucf

src = $(shell find ./src -name '*.v')

style=silent

xst      = xst      -intstyle $(style)
ngdbuild = ngdbuild -intstyle $(style)
map      = map      -intstyle $(style)
par      = par      -intstyle $(style)
bitgen   = bitgen   -intstyle $(style)

COMP_TIME = $(shell date +"%H%M")

ise: $(top).xst $(top).bit
all: ise upload serial
xst: $(top).ngc;

required:
	@ echo "Creating memories"
	@ ./scripts/memory_gen.py "$(COMP_TIME)" -f version.txt
	@ ./scripts/memory_gen.py "CSoC Test Running..." -f initial_message.txt
	@ ./scripts/state_names.sh > cmd_parser_states.conf

$(top).xst: $(src) required
	@ echo "Creating $(top).xst"
	@ echo " \
		run \
		-ifn $(top).prj \
		-top $(top) \
		-ifmt MIXED \
		-opt_mode AREA \
		-opt_level 2 \
		-ofn $(top).ngc \
		-p $(target) \
		-register_balancing yes" \
		> $(top).xst

$(top).prj: $(src)
	@ echo "Creating $(top).prj"
	@ rm -f $(top).prj
	@ for i in $(src); do \
		echo "verilog work $$i" >> $(top).prj; \
	done

$(top).ngc: $(top).prj
	@ ./scripts/color.sh $(xst) -ifn $(top).xst

$(top).ngd: $(top).ngc $(ucf)
	@ ./scripts/color.sh $(ngdbuild) -uc $(ucf) $(top).ngc

$(top).ncd: $(top).ngd
	@ ./scripts/color.sh $(map) $(top).ngd 2>&1

$(top)-routed.ncd: $(top).ncd
	@ ./scripts/color.sh $(par) -ol high -w $(top).ncd $(top)-routed.ncd

# NEW TOOL from:
# http://outputlogic.com/xcell_using_xilinx_tools/74_xperts_04.pdf
# https://www.xilinx.com/itp/xilinx10/isehelp/pta_r_standalone_tool_emulation.htm
new:
	# trce -intstyle ise -v 3 -s 4 -n 3 -fastpaths -xml $(top).twx $(top).ncd -o $(top).twr $(top).pcf
	trce -intstyle ise -v 3 -s 4 -xml $(top) $(top).ncd -o $(top).twr $(top).pcf -ucf $(ucf)
	# timingan -ucf $(ucf) -ngd $(top).ngd $(top).ncd $(top).pcf $(top).twx
	# timingan $(top).twx

# Xilinx sim example
# http://insights.sigasi.com/tech/how-run-xilinx-isimfuse-command-line-linux.html
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx13_1/ism_r_entering_simulation_tcl_commands.htm
isim: $(top).prj
	fuse -intstyle ise -incremental -o $(top) -prj $(top).prj $(top_tb)
	# ./$(top) -tclbatch <tcl_file_name> -sdfmax <<anno_point>=sdf_file>.sdf>
	./$(top) -gui


$(top).bit: $(top)-routed.ncd
	@ ./scripts/color.sh $(bitgen) -w $(top)-routed.ncd $(top).bit
	@ du -sh $(top).bit

#====

fpga_ls:
	djtgcfg enum

fpga_init:
	djtgcfg init -d DOnbUsb

GREEN   = $(shell tput setaf 2)
BOLD   = $(shell tput bold)
NORMAL = $(shell tput sgr0)

upload:
	/usr/bin/time -f "%E real, %U user, %S sys" \
		djtgcfg prog -d DOnbUsb -i 1 -f $(top).bit
	@ echo -e "\n\n $(GREEN)$(BOLD)~ DONT FORGET TO RESET THE BOARD ~$(NORMAL) \n\n"
	@ notify-send -u critical 'RESET THE FPGA BOARD' --icon=terminix

# https://wiki.openwrt.org/doc/recipes/serialbaudratespeed
dev=/dev/ttyUSB0
# baud=115200
baud=9600
# to exit screen (Ctrl-A \): screen $(dev) $(baud)
serial:
	@# stty -a
	stty sane; \
		stty -F $(dev) $(baud) raw crtscts cs8 -cstopb -parenb
		cat $(cat_flags) < $(dev)

screen:
	screen $(dev) $(baud)

#====

clean:
	@ # REQUIRED DATA
	@ rm -f initial_message.txt
	@ rm -f version.txt
	@ # ICARUS/GTKWAVE
	@ rm -f $(top)
	@ rm -f *.vcd
	@ rm -f *.vcd.fst
	@ rm -f cmd_parser_states.conf
	@ # ISE OUTPUTS
	@ rm -f *-routed*
	@ rm -f *.bgn
	@ rm -f *.bit
	@ rm -f *.bld
	@ rm -f *.drc
	@ rm -f *.log
	@ rm -f *.lso
	@ rm -f *.map
	@ rm -f *.mrp
	@ rm -f *.ncd
	@ rm -f *.ngc
	@ rm -f *.ngd
	@ rm -f *.ngm
	@ rm -f *.pcf
	@ rm -f *.prj
	@ rm -f *.srp
	@ rm -f *.svf
	@ rm -f *.twr
	@ rm -f *.twx
	@ rm -f *.xrpt
	@ rm -f *.xrpt
	@ rm -f *.xst
	@ rm -f *.xwbt
	@ rm -f *_signalbrowser.*
	@ rm -f *_summary.xml
	@ rm -f *_usage*
	@ rm -f fuse.xmsgs
	@ rm -f fuseRelaunch.cmd
	@ rm -f isim.wdb
	@ rm -f netlist.lst
	@ rm -f param.opt
	@ rm -f usage_statistics_webtalk.html
	@ rm -rf _xmsgs
	@ rm -rf isim
	@ rm -rf xlnx_auto_*_xdb
	@ rm -rf xst


#=================================================================
# FOSS tools: icarus verilog, gtkwave

iverilog: required
	iverilog \
		-o $(top) \
		src/baudgen_rx.v \
		src/baudgen_tx.v \
		src/uart_rx.v \
		src/uart_tx.v \
		src/sevenseg.v \
		src/cmd_parser.v \
		src/part_tester.v \
		src/csoc.v \
		src/tb.v

kill_vvp:
	@ pgrep vvp | killall -q vvp

notify-send = notify-send

run:
	vvp -n $(top)
	@ $(notify-send) -u critical 'Simulation done! Reload gtkwave' --icon=gtkwave

sim: iverilog run

wave:
	@ ./scripts/state_names.sh > cmd_parser_states.conf
	gtkwave --wish --slider-zoom --optimize part_tester.vcd -a gtkwave/waveform.gtkw





# EXCHANGE DATA (BASIC TESTS)
#============================

RESET_CMD = r
EXECUTE_CMD = e
FREE_RUN_CMD = f
PAUSE_CMD = p
GET_STATE_CMD = g
GET_OUTPUTS_CMD = o
SET_STATE_CMD = s
SET_INPUTS_CMD = i

cycles = 4
nregs = 1919
npis = 4
npos = 7

cycles_hex = $(shell printf "%04x" $(cycles))
cycles_hex_hi = \x$(shell echo $(cycles_hex) | cut -c 1-2)
cycles_hex_lo = \x$(shell echo $(cycles_hex) | cut -c 3-4)

nregs_hex = $(shell printf "%04x" $(nregs))
nregs_hex_hi = \x$(shell echo $(nregs_hex) | cut -c 1-2)
nregs_hex_lo = \x$(shell echo $(nregs_hex) | cut -c 3-4)

npis_hex = $(shell printf "%04x" $(npis))
npis_hex_hi = \x$(shell echo $(npis_hex) | cut -c 1-2)
npis_hex_lo = \x$(shell echo $(npis_hex) | cut -c 3-4)

npos_hex = $(shell printf "%04x" $(npos))
npos_hex_hi = \x$(shell echo $(npos_hex) | cut -c 1-2)
npos_hex_lo = \x$(shell echo $(npos_hex) | cut -c 3-4)

vars:
	@ echo "cycles: $(cycles)"
	@ echo "cycles_hex: $(cycles_hex)"
	@ echo "cycles_hex_hi: $(cycles_hex_hi)"
	@ echo "cycles_hex_lo: $(cycles_hex_lo)"
	@ echo
	@ echo "nregs: $(nregs)"
	@ echo "nregs_hex: $(nregs_hex)"
	@ echo "nregs_hex_hi: $(nregs_hex_hi)"
	@ echo "nregs_hex_lo: $(nregs_hex_lo)"
	@ echo
	@ echo "npis: $(npis)"
	@ echo "npis_hex: $(npis_hex)"
	@ echo "npis_hex_hi: $(npis_hex_hi)"
	@ echo "npis_hex_lo: $(npis_hex_lo)"
	@ echo
	@ echo "npos: $(npos)"
	@ echo "npos_hex: $(npos_hex)"
	@ echo "npos_hex_hi: $(npos_hex_hi)"
	@ echo "npos_hex_lo: $(npos_hex_lo)"

reset_csoc_test:
	printf '%s' '$(RESET_CMD)' > $(dev)

execute_dut:
	printf '%s' '$(EXECUTE_CMD)' > $(dev)
	printf '%b' '$(cycles_hex_hi)' > $(dev)
	printf '%b' '$(cycles_hex_lo)' > $(dev)

free_run_dut:
	printf '%s' '$(FREE_RUN_CMD)' > $(dev)

stop_free_run:
	printf '%s' '$(PAUSE_CMD)' > $(dev)

get_state:
	printf '%s' '$(GET_STATE_CMD)' > $(dev)
	printf '%b' '$(cycles_hex_hi)' > $(dev)
	printf '%b' '$(cycles_hex_lo)' > $(dev)

get_outputs:
	printf '%s' '$(GET_OUTPUTS_CMD)' > $(dev)
	printf '%b' '$(npos_hex_hi)' > $(dev)
	printf '%b' '$(npos_hex_lo)' > $(dev)

set_state:
	printf '%s' '$(SET_STATE_CMD)' > $(dev)
	printf '%b' '$(nregs_hex_hi)' > $(dev)
	printf '%b' '$(nregs_hex_lo)' > $(dev)
	for i in $(shell seq 1 $(cycles)); do printf '%b' '\x01' > $(dev); done

set_inputs:
	printf '%s' '$(SET_INPUTS_CMD)' > $(dev)
	printf '%b' '$(npis_hex_hi)' > $(dev)
	printf '%b' '$(npis_hex_lo)' > $(dev)
	for i in $(shell seq 1 $(npis)); do printf '%b' '\x01' > $(dev); done

