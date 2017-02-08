
top = csoc_test
target = xc3s1200e-fg320-4
ucf = nexsy2.ucf

src = $(shell find  *.v)

all: $(top).xst $(top).bit

xst: $(top).ngc;
ngdbuild: $(top).ngd
map: $(top).ncd
par: $(top)-routed.ncd
bitgen: $(top).bit

$(top).xst: $(src)
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
	@ for i in $(shell echo $^); do \
		echo "verilog work $$i" >> $(top).prj; \
	done

$(top).ngc: $(top).prj
	@ color.sh xst -ifn $(top).xst

$(top).ngd: $(top).ngc $(ucf)
	@ color.sh ngdbuild -uc $(ucf) $(top).ngc

$(top).ncd: $(top).ngd
	@ color.sh map $(top).ngd 2>&1

$(top)-routed.ncd: $(top).ncd
	@ color.sh par -ol high -w $(top).ncd $(top)-routed.ncd

$(top).bit: $(top)-routed.ncd
	@ color.sh bitgen -w $(top)-routed.ncd $(top).bit
	@ du -sh $(top).bit

#====

fpga_ls:
	djtgcfg enum

fpga_init:
	djtgcfg init -d DOnbUsb

upload:
	djtgcfg prog -d DOnbUsb -i 1 -f $(top).bit


dev=/dev/ttyUSB0
baud=9600
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

cleanall: clean
	rm -f *.bit