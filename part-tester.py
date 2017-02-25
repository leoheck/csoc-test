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
import stat

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
parser.add_argument('-t', '--test_mode', action='store_false', help='Disable serial commands to test ATPG parsing')
args = parser.parse_args()

if not args.test_mode:

	try:
		stat.S_ISBLK(os.stat(args.device).st_mode)
	except:
		print "Device", args.device, "is missing"
		exit()

	# http://www.varesano.net/blog/fabio/serial%20rs232%20connections%20python
	# configure the serial connections (the parameters differs on the device you are connecting to)
	ser = serial.Serial(
		port=args.device,
		baudrate=args.baud
	)

	if not ser.isOpen():
		ser.open()
	ser.isOpen()

# Codigos de comando dentro do arquivo de ATPG (Cadence ET):
# 000
# 100 COMMENT
# 200 stim_PIs -------------------------- Exemplo: 0XXXXXXXX111XX
# 201 stim_CIs -------------------------- Exemplo: 0XXXXXXXX1XXXX
# 202 resp_POs -------------------------- Exemplo: 11110100010
# 203 global_term_[Z] ------------------- Valor do sinal, todos em alta impedancia (z)
# 300 MODENUM_[1] stim_SLs stim_SLs ----- Exemplo: 1 1100110011... (acho que tem blocos de 1000 dados)
# 301 MODENUM_[1] resp_MLs resp_MLs ----- Exemplo: 1 1100110011... (acho que tem blocos de 1000 dados)
# 400 ----------------------------------- test_cycle
# 500 ----------------------------------- Não encontrado nos nossos arquivos de teste
# 501 ----------------------------------- Não encontrado nos nossos arquivos de teste
# 600 MODENUM_[1] SEQNUM_[1|100|2] MAX -- Exemplo: 1 2 1919
# 900 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9
# 901 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9

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

		# 000
		if cmd == 000:
			if args.verbose >= 1:
				print cmd, "Starting tests?"

		# 100 COMMENT
		if cmd == 100:
			if args.verbose >= 1:
				print cmd, "Encounter Test String"
			continue

		# 200 stim_PIs -------------------------- Exemplo: 0XXXXXXXX111XX
		elif cmd == 200:
			stim_PIs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Inputs stimuli:", stim_PIs

		# 201 stim_CIs -------------------------- Exemplo: 0XXXXXXXX1XXXX
		elif cmd == 201:
			stim_CIs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Input comparison stimuli:", stim_CIs

		# 202 resp_POs -------------------------- Exemplo: 11110100010
		elif cmd == 202:
			resp_POs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Output responses:", resp_POs



		# 203 global_term_[Z] ------------------- Valor do sinal, todos em alta impedancia (z)
		elif cmd == 203:
			global_term = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Undefined single character", global_term

		# 300 MODENUM_[1] stim_SLs stim_SLs ----- Exemplo: 1 1100110011... \n 1100110011... (acho que tem blocos de 1000 dados)
		elif cmd == 300:
			modenum = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Input/output stream", modenum, line_splited[2][:20] + "..."
			if args.verbose >= 2:
				print "BITS:", len(line_splited[2])

		# 301 MODENUM_[1] resp_MLs resp_MLs ----- Exemplo: 1 1100110011... (acho que tem blocos de 1000 dados)
		elif cmd == 301:
			modenum = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Input/output stream", modenum, line_splited[2][:20] + "..."
				if args.verbose >= 2:
					print "BITS:", len(line_splited[2])

		# 400 ----------------------------------- test_cycle
		elif cmd == 400:
			if args.verbose >= 1:
				print cmd, "Start test"
			print "\n"

		# 500 ----------------------------------- Não encontrado nos nossos arquivos de teste
		elif cmd == 500:
			print "Command", cmd, "not implemented yet."

		# 501 ----------------------------------- Não encontrado nos nossos arquivos de teste
		elif cmd == 501:
			print "Command", cmd, "not implemented yet."

		# 600 MODENUM_[1] SEQNUM_[1|100|2] MAX -- Exemplo: 1 2 1919
		elif cmd == 600:
			modenum = line_splited[1]
			seqnum = line_splited[2]
			cycles = line_splited[3]
			if args.verbose >= 1:
				print cmd, "Set clock pulses:", map(int,line_splited[1:])

		# 900 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9
		elif cmd == 900:
			if args.verbose >= 1:
				print cmd, "Test pattern:", line_splited[1]

		# 901 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9
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

	print "INTERACTIVE MODE"
	print "Enter your commands below."
	print "RESET THE BOARD FIRST."
	print "Insert \"exit\" to leave the application."

	input = 1
	while 1:
		# get keyboard input
		input = raw_input("cmd> ")
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
				print out