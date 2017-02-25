#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Simple ET parser to handle ATP Test over serial
# Leandro Heck (leoheck@gmail.com)

## Create a fake terminal to test
# sudo apt install socat
# socat -d -d pty,raw,echo=0 pty,raw,echo=0

import argparse
import itertools
import time
import os.path

try:
	import serial
except Exception, e:
	print NEED_PYSERIAL
	raise e

parser = argparse.ArgumentParser(description='Enable ATPG tests')
parser.add_argument('-v', '--verbose', action='count', default=0, help='Increase verbosity. Number of -v will increase verbosity')
parser.add_argument('-d', '--device', default="/dev/ttyUSB0", help='Default: /dev/ttyUSB0')
parser.add_argument('-b', '--baud', default="9600", help='Default: 9600')
parser.add_argument('-f', '--atpg_file', help='Cadence ET ATPG file')
args = parser.parse_args()

# Execusao por arquivo (script)
if args.atpg_file:

	fname = args.atpg_file

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
			if args.verbose >= 1:
				print cmd, "Encounter Test String"
			continue

		elif cmd == 200:
			if args.verbose >= 1:
				print cmd, "Input config values:", line_splited[1]

		elif cmd == 201:
			if args.verbose >= 1:
				print cmd, "Input config values:", line_splited[1]

		elif cmd == 202:
			if args.verbose >= 1:
				print cmd, "Expected output values:", line_splited[1]

		elif cmd == 203:
			if args.verbose >= 1:
				print cmd, "Undefined single character:", line_splited[1]

		elif cmd == 300:
			if args.verbose >= 1:
				print cmd, "Input/output stream", line_splited[1], line_splited[2][:20] + "..."
			if args.verbose >= 2:
				print "BITS:", len(line_splited[2])

		elif cmd == 301:
			if args.verbose >= 1:
				print cmd, "Input/output stream", line_splited[1], line_splited[2][:20] + "..."
				if args.verbose >= 2:
					print "BITS:", len(line_splited[2])

		elif cmd == 400:
			if args.verbose >= 1:
				print cmd, "Start test"

		elif cmd == 600:
			if args.verbose >= 1:
				print cmd, "Set clock pulses:", map(int,line_splited[1:])

		elif cmd == 900:
			if args.verbose >= 1:
				print cmd, "Test pattern:", line_splited[1]

		elif cmd == 901:
			if args.verbose >= 1:
				print cmd, "Test pattern:", line_splited[1]

		# NAO É COMANDO
		elif len(line_splited[0]) > 3:
			if args.verbose >= 2:
				print "BITS", len(line_splited[0])
			continue

		else:
			print "Warning, missing command"
			continue

# Abre no modo iterativo
else:

	# http://www.varesano.net/blog/fabio/serial%20rs232%20connections%20python
	# configure the serial connections (the parameters differs on the device you are connecting to)
	ser = serial.Serial(
		port=args.device,
		baudrate=args.baud
	)

	if not ser.isOpen():
		ser.open()
	ser.isOpen()

	print "Interactive mode"
	print 'Enter your commands below.\r\nInsert "exit" to leave the application.'

	input = 1
	while 1:
	    # get keyboard input
	    input = raw_input("> ")
	        # Python 3 users
	        # input = input(">> ")
	    if input == 'exit':
	        ser.close()
	        exit()
	    else:
	        # send the character to the device
	        # (note that I happend a \r\n carriage return and line feed to the characters - this is requested by my device)
	        ser.write(input + '\r\n')
	        out = ''
	        # let's wait one second before reading output (let's give device time to answer)
	        time.sleep(1)
	        while ser.inWaiting() > 0:
	            out += ser.read(1)

	        if out != '':
	            print ">" + out