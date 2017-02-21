#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Simple ET parser to handle ATP Test over serial
# Leandro Heck (leoheck@gmail.com)

import argparse
import itertools


# Arquivos de teste (hardwcoded para facilitar)
# fname = "dft-psynth/atpg/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.logic.ex1.ts2"
fname = "dft-psynth/atpg/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1"

parser = argparse.ArgumentParser(description='Enable ATPG tests')
parser.add_argument('-v', '--verbose', action='count', default=0, help='Increase verbosity')
# parser.add_argument('atpg_file', help='Cadence ET ATPG file')
args = parser.parse_args()



# enable verbose

with open(fname) as f:
	lines = f.readlines()

for i, line in enumerate(lines):

	# print line
	line_splited = line.split()

	if not line_splited:
		# print
		continue

	cmd = int(line_splited[0])

	if cmd == 100:
		if args.verbose >= 2:
			print cmd, "Encounter Test String"
		continue

	elif cmd == 200:
		if args.verbose >= 2:
			print cmd, "Input config values:", line_splited[1]

	elif cmd == 201:
		if args.verbose >= 2:
			print cmd, "Input config values:", line_splited[1]

	elif cmd == 202:
		if args.verbose >= 2:
			print cmd, "Expected output values:", line_splited[1]

	elif cmd == 203:
		if args.verbose >= 2:
			print cmd, "Undefined single character:", line_splited[1]

	elif cmd == 300:
		if args.verbose >= 2:
			print cmd, "Input/output stream", line_splited[1], line_splited[2][:20] + "..."
		if args.verbose >= 3:
			print "BITS:", len(line_splited[2])

	elif cmd == 301:
		if args.verbose >= 2:
			print cmd, "Input/output stream", line_splited[1], line_splited[2][:20] + "..."
			if args.verbose >= 3:
				print "BITS:", len(line_splited[2])

	elif cmd == 400:
		if args.verbose >= 2:
			print cmd, "Start test"

	elif cmd == 600:
		if args.verbose >= 2:
			print cmd, "Set clock pulses:", map(int,line_splited[1:])

	elif cmd == 900:
		if args.verbose >= 2:
			print cmd, "Test pattern:", line_splited[1]

	elif cmd == 901:
		if args.verbose >= 2:
			print cmd, "Test pattern:", line_splited[1]

	# NAO É COMANDO
	elif len(line_splited[0]) > 3:
		if args.verbose >= 3:
			print "BITS", len(line_splited[0])
		continue

	else:
		print "Warning, missing command"
		continue


	# TODO: Send to serial...
	# TODO: Receive from serial...
