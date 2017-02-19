
#sublime_text: sim

## CONFIGURE O AMBIENTE COM:
## source setup-env.sh

# simulation with isim
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx13_1/ism_r_entering_simulation_tcl_commands.htm

top = csoc_test
top_tb = tb
target = xc3s1200e-fg320-4
ucf = nexsy2-1200.ucf

src = $(shell find ./src -name '*.v')

compile: $(top).xst $(top).bit
all: compile upload serial

xst      = xst      -intstyle silent
ngdbuild = ngdbuild -intstyle silent
map      = map      -intstyle silent
par      = par      -intstyle silent
bitgen   = bitgen   -intstyle silent

xst: $(top).ngc;
ngdbuild: $(top).ngd
map: $(top).ncd
par: $(top)-routed.ncd
bitgen: $(top).bit

TIME_TO_DISPLAY = $(shell date +"%Y-%m-%d %H_%M")

required:
	@ echo "Creating memories"
	@ ./scripts/banner_rom.py > banner.txt
	@ ./scripts/memory_gen.py > initial_message.txt
	@#./scripts/memory_gen.py "CSoC $(TIME_TO_DISPLAY) GAPH LHEC " > banner.txt
	@#./scripts/memory_gen.py "Help! I'm trapped in an FPGA\n" > initial_message.txt

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

upload:
	/usr/bin/time -f "%E real, %U user, %S sys" \
		djtgcfg prog -d DOnbUsb -i 1 -f $(top).bit
	@ echo -e "\n\n ~ DONT FORGET TO RESET THE BOARD (Version: $(TIME_TO_DISPLAY)) ~ \n\n"


# https://wiki.openwrt.org/doc/recipes/serialbaudratespeed
dev=/dev/ttyUSB0
# baud=115200
baud=9600
# to exit screen (Ctrl-A \): screen $(dev) $(baud)
serial:
	stty sane
	# stty -F $(dev) $(baud) clocal cread cs8 -cstopb -parenb
	stty -F $(dev) $(baud)
	cat < $(dev)

screen:
	screen $(dev) $(baud)

#====

clean:
	@ rm -f *.xrpt
	@ rm -f *-routed*
	@ rm -f *-routed_pad.tx
	@ rm -f *.bgn
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
	@ rm -f *.xrpt
	@ rm -f *.xwbt
	@ rm -f *_signalbrowser.*
	@ rm -f *_summary.xml
	@ rm -f *_usage*
	@ rm -f netlist.lst
	@ rm -f param.opt
	@ rm -f smartpreview.twr
	@ rm -f timing.twr
	@ rm -rf xlnx_auto_*_xdb
	@ rm -rf _xmsgs
	@ rm -rf xst
	@ rm -f *.xst
	@ rm -f *.bit
	@ rm -f $(top)
	@ rm -f *.vcd
	@ rm -rf isim
	@ rm -f fuseRelaunch.cmd
	@ rm -f fuse.xmsgs
	@ rm -f isim.wdb
	@ rm -f csoc_test.twx
	@ rm -f csoc_test.twr
	@ rm -f usage_statistics_webtalk.html
	@ rm -f banner.txt
	@ rm -f initial_message.txt
	@ rm -f uart.vcd.fst


#=================================================================
# FOSS tools

iverilog: required
	iverilog -o $(top) \
		src/baudgen_rx.v \
		src/baudgen_tx.v \
		src/uart_rx.v \
		src/uart_tx.v \
		src/sevenseg.v \
		src/uart_parser.v \
		src/csoc_test.v \
		src/tb.v

run:
	pgrep vvp && killall -q vvp
	vvp $(top)
	notify-send -u critical 'Simulation done! Reload gtkwave' --icon=gtkwave


# Warning! File size is 370 MB.  This might fail in recoding.
# Consider converting it to the FST database format instead.  (See the
# vcd2fst(1) manpage for more information.)
# To disable this warning, set rc variable vcd_warning_filesize to zero.
# Alternatively, use the -o, --optimize command line option to convert to FST
# or the -g, --giga command line option to use dynamically compressed memory.


sim: iverilog run

wave:
	gtkwave --optimize  uart.vcd -a gtkwave/waveform.gtkw
