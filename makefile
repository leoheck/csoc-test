
top = csoc_test
target = xc3s1200e-fg320-4
ucf = nexsy2.ucf

src = $(shell find  *.v)

define colorecho
	@tput bold
	@echo -e "\n-------------------"
	@echo $1
	@tput sgr0
endef

all: $(top).xst $(top).bit

$(top).xst:
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
	@ rm -f $(top).prj
	@ for i in $(shell echo $^); do \
		echo "verilog work $$i" >> $(top).prj; \
	done

$(top).ngc: $(top).prj
	$(call colorecho,"#> Running XST")
	xst -ifn $(top).xst | ./color.sh

$(top).ngd: $(top).ngc $(ucf)
	$(call colorecho,"#> Running NGDBUILD")
	ngdbuild -uc $(ucf) $(top).ngc | ./color.sh

$(top).ncd: $(top).ngd
	$(call colorecho,"#> Running MAP")
	map $(top).ngd 2>&1 | ./color.sh

$(top)-routed.ncd: $(top).ncd
	$(call colorecho,"#> Running PAR")
	par -ol high -w $(top).ncd $(top)-routed.ncd | ./color.sh

$(top).bit: $(top)-routed.ncd
	$(call colorecho,"#> Running BITGEN")
	bitgen -w $(top)-routed.ncd $(top).bit | ./color.sh

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