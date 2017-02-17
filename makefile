
# tmp: simrun

# simulation with isim
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx13_1/ism_r_entering_simulation_tcl_commands.htm

top = csoc_test
top_tb = tb
target = xc3s1200e-fg320-4
ucf = nexsy2.ucf

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

$(top).xst: $(src)
	@ echo "Creating $(top).xst"
	./banner_rom.py > banner.txt
	# ./memory_gen.py "data" > memory_gen.txt
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
	@ color.sh $(xst) -ifn $(top).xst

$(top).ngd: $(top).ngc $(ucf)
	@ color.sh $(ngdbuild) -uc $(ucf) $(top).ngc

$(top).ncd: $(top).ngd
	@ color.sh $(map) $(top).ngd 2>&1

$(top)-routed.ncd: $(top).ncd
	@ color.sh $(par) -ol high -w $(top).ncd $(top)-routed.ncd

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
	@ color.sh $(bitgen) -w $(top)-routed.ncd $(top).bit
	@ du -sh $(top).bit

#====

fpga_ls:
	djtgcfg enum

fpga_init:
	djtgcfg init -d DOnbUsb

upload:
	/usr/bin/time -f "%E real, %U user, %S sys" \
	djtgcfg prog -d DOnbUsb -i 1 -f $(top).bit
	@ echo -e "\n\n ~ DONT FORGET TO RESET THE BOARD ~ \n\n"


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
	rm -f *.xrpt
	rm -f *-routed*
	rm -f *-routed_pad.tx
	rm -f *.bgn
	rm -f *.bld
	rm -f *.drc
	rm -f *.log
	rm -f *.lso
	rm -f *.map
	rm -f *.mrp
	rm -f *.ncd
	rm -f *.ngc
	rm -f *.ngd
	rm -f *.ngm
	rm -f *.pcf
	rm -f *.prj
	rm -f *.srp
	rm -f *.svf
	rm -f *.xrpt
	rm -f *.xwbt
	rm -f *_signalbrowser.*
	rm -f *_summary.xml
	rm -f *_usage*
	rm -f netlist.lst
	rm -f param.opt
	rm -f smartpreview.twr
	rm -f timing.twr
	rm -rf xlnx_auto_*_xdb
	rm -rf _xmsgs
	rm -rf xst
	rm -f *.xst
	rm -f *.bit
	rm -f $(top)
	rm -f *.vcd
	rm -rf isim
	rm -f fuseRelaunch.cmd
	rm -f fuse.xmsgs
	rm -f isim.wdb
	rm -f csoc_test.twx
	rm -f csoc_test.twr
	rm -f usage_statistics_webtalk.html



# FOSS tools

sim:
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
	vvp $(top)

simrun: sim run

wave:
	gtkwave uart.vcd -a waveform.gtkw

