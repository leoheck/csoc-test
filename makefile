
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

xst      = xst      -intstyle silent
ngdbuild = ngdbuild -intstyle silent
map      = map      -intstyle silent
par      = par      -intstyle silent
bitgen   = bitgen   -intstyle silent

COMP_TIME = $(shell date +"%H%M")

ise: $(top).xst $(top).bit
all: ise upload serial
xst: $(top).ngc;

required:
	@ echo "Creating memories"
	@ ./scripts/memory_gen.py "$(COMP_TIME)" -f version.txt
	@ ./scripts/memory_gen.py "CSoC Test Running..." -f initial_message.txt
	@ ./scripts/state_names.sh > gtkwave/parser_states.conf

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
		stty -F $(dev) $(baud) crtscts
		cat < $(dev)

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
	@ rm -f gtkwave/parser_states.conf
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
	iverilog -o $(top) \
		src/baudgen_rx.v \
		src/baudgen_tx.v \
		src/uart_rx.v \
		src/uart_tx.v \
		src/sevenseg.v \
		src/cmd_parser.v \
		src/part_tester.v \
		src/tb.v

run:
	@# pgrep vvp | killall -q vvp
	vvp $(top)
	@ notify-send -u critical 'Simulation done! Reload gtkwave' --icon=gtkwave


# Warning! File size is 370 MB.  This might fail in recoding.
# Consider converting it to the FST database format instead.  (See the
# vcd2fst(1) manpage for more information.)
# To disable this warning, set rc variable vcd_warning_filesize to zero.
# Alternatively, use the -o, --optimize command line option to convert to FST
# or the -g, --giga command line option to use dynamically compressed memory.


sim: iverilog run

wave:
	gtkwave --slider-zoom --optimize uart.vcd -a gtkwave/waveform.gtkw
