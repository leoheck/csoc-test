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
parser.add_argument('-t', '--test_mode', action='store_true', help='Disable serial commands to test ATPG parsing')
args = parser.parse_args()


if args.test_mode:
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




#==========================================================

def send_data(data):
	"Send a byte through serial"
	if args.verbose >= 2:
		print "Sending", data
	if not args.test:
		ser.write(data)
	return True

def recv_data(data):
	"Receive a byte through serial"
	if not args.test:
		data += ser.read()
	if args.verbose >= 2:
		print "Received", data
	return data

#==========================================================

# Primary IOs
# stim_PIs      [1:0014]
# part_PIs      [1:0014]
# stim_CIs      [1:0014]
# resp_POs      [1:0011]
# scan_POs      [1:0011]
# part_POs      [1:0011]
# Shift Chains
# stim_SLs     [1:1919]
# resp_MLs     [1:1919]
# resp_ORs     [1:0001]
# scan_ORs     [1:0001]
# comp_ORs     [1:0001]
# part_SLs_1   [1:1919]
# part_MLs_1   [1:1919]

# integer  CYCLE, SCANCYCLE, SERIALCYCLE, PInum, POnum, ORnum, MODENUM, EXPNUM, SCANOPNUM, SEQNUM, TASKNUM, SCANNUM;
# integer  CMD, FID, TID, r, repeat_depth, MAX, FAILSETID, file_position, start_of_line;
# real     good_compares, miscompares, total_good_compares, total_miscompares;
# integer  start_of_repeat [1:15], num_repeats [1:15];
# reg      [1:8185] name_POs [1:0011];
# reg      sim_trace, sim_heart, sim_range, failset, global_term, sim_debug, sim_more_debug;
# reg      [1:800] PATTERN, pattern, TESTFILE, SOD, EOD;
# reg      [1:8184] FILE, COMMENT, FAILSET;

RESET_CMD = "r"
EXECUTE_CMD = "e"
FREE_RUN_CMD = "f"
PAUSE_CMD = "p"
GET_STATE_CMD = "g"
GET_OUTPUTS_CMD = "o"
SET_STATE_CMD = "s"
SET_INPUTS_CMD = "i"

def set_internal_state(cycles, internal_state):
	"Set scan chain state"
	send_data(SET_STATE_CMD)
	send_data(cycles_hi)
	send_data(cycles_lo)
	for i, data in enumerate(internal_state):
		send_data(data)

def get_internal_state(cyles):
	"Get scan chain state"
	send_data(GET_STATE_CMD)
	send_data(cycles_hi)
	send_data(cycles_lo)
	internal_state = list()
	for i, data in range(cyles):
		send_data.append(data)
	return internal_state

def set_inputs_state(ninputs, input_state):
	"Set inputs state"
	send_data(SET_INPUTS_CMD)
	send_data(cycles_hi)
	send_data(cycles_lo)
	for i, data in enumerate(input_state):
		send_data.append(data)

def get_outputs_state(noutputs):
	"Get outputs state"
	send_data(GET_OUTPUTS_CMD)
	send_data(cycles_hi)
	send_data(cycles_lo)
	for i, data in range(noutputs):
		send_data.append(data)
	return outputs_state

#==========================================================


# Codigos de comando dentro do arquivo de ATPG (Cadence ET):
# 000
# 100 COMMENT
# 200 stim_PIs -------------------------- Example: 0XXXXXXXX111XX
# 201 stim_CIs -------------------------- Example: 0XXXXXXXX1XXXX
# 202 resp_POs -------------------------- Example: 11110100010
# 203 global_term_[Z] ------------------- Valor do sinal, todos em alta impedancia (z)
# 300 MODENUM_[1] stim_SLs stim_SLs ----- Example: 1 1100110011... (acho que tem blocos de 1000 dados)
# 301 MODENUM_[1] resp_MLs resp_MLs ----- Example: 1 1100110011... (acho que tem blocos de 1000 dados)
# 400 ----------------------------------- test_cycle
# 500 ----------------------------------- Não encontrado nos nossos arquivos de teste
# 501 ----------------------------------- Não encontrado nos nossos arquivos de teste
# 600 MODENUM_[1] SEQNUM_[1|100|2] MAX -- Example: 1 2 1919
# 900 PATTERN --------------------------- Example: 1.1.1.2.1.9
# 901 PATTERN --------------------------- Example: 1.1.1.2.1.9

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
			comment = ' '.join(line_splited[2:])
			if args.verbose >= 1:
				print cmd, comment
			continue

		# 200 stim_PIs -------------------------- Example: 0XXXXXXXX111XX
		elif cmd == 200:
			stim_PIs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Inputs stimuli:", stim_PIs

		# 201 stim_CIs -------------------------- Example: 0XXXXXXXX1XXXX
		elif cmd == 201:
			stim_CIs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Input comparison stimuli:", stim_CIs

		# 202 resp_POs -------------------------- Example: 11110100010
		elif cmd == 202:
			resp_POs = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Output responses:", resp_POs



		# 203 global_term_[Z] ------------------- Valor do sinal, todos em alta impedancia (z)
		elif cmd == 203:
			global_term = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Undefined single character", global_term

		# 300 MODENUM_[1] stim_SLs stim_SLs ----- Example: 1 1100110011... \n 1100110011... (sequencias de 1000 dados?)
		elif cmd == 300:
			modenum = line_splited[1]
			stim_SLs = list()
			stim_SLs.append(line_splited[2])
			i=i+1
			line_splited = lines[i].split()
			stim_SLs.append(line_splited[0])
			if args.verbose >= 1:
				print cmd, "Input/output stream", modenum, stim_SLs[0][:10] + "...",  stim_SLs[1][:10] + "..."

		# 301 MODENUM_[1] resp_MLs resp_MLs ----- Example: 1 1100110011... \n 1100110011... (sequencias de 1000 dados?)
		elif cmd == 301:
			modenum = line_splited[1]
			resp_MLs = list()
			resp_MLs.append(line_splited[2])
			i=i+1
			line_splited = lines[i].split()
			resp_MLs.append(line_splited[0])

			if args.verbose >= 1:
				print cmd, "Input/output stream", modenum, resp_MLs[0][:10] + "...",  resp_MLs[1][:10] + "..."

		# 400 ----------------------------------- test_cycle
		elif cmd == 400:
			if args.verbose >= 1:
				print cmd, "Start test"
				print ""

		# 500 ----------------------------------- Não encontrado nos nossos arquivos de teste
		elif cmd == 500:
			print "Command", cmd, "not implemented yet."

		# 501 ----------------------------------- Não encontrado nos nossos arquivos de teste
		elif cmd == 501:
			print "Command", cmd, "not implemented yet."

		# 600 MODENUM_[1] SEQNUM_[1|100|2] MAX -- Example: 1 2 1919
		elif cmd == 600:
			modenum = line_splited[1]
			seqnum = line_splited[2]
			cycles = line_splited[3]
			if args.verbose >= 1:
				print cmd, "Set clock pulses:", modenum, seqnum, cycles

		# 900 PATTERN --------------------------- Example: 1.1.1.2.1.9
		elif cmd == 900:
			pattern = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Test pattern:", pattern

			# if SOD == pattern:
				# sim_range = 1;
            # if (( CMD == 900 ) & sim_range & sim_heart )
            # $display ( "\nINFO (TVE-202): Simulating pattern %0s at Time %0t. ", pattern, $time );


		# 901 PATTERN --------------------------- Example: 1.1.1.2.1.9
		elif cmd == 901:
			pattern = line_splited[1]
			if args.verbose >= 1:
				print cmd, "Test pattern:", pattern

		# NAO É COMANDO
		elif len(line_splited[0]) > 3:
			# if args.verbose >= 2:
				# print "BITS", len(line_splited[0])
			continue

		else:
			print "Warning, missing command"
			continue


		# if EOD == pattern:
		# 	sim_range = 0;



#
# INTERACTIVE MODE
#

else:

	print "PART TESTER IN INTERACTIVE MODE"
	print "RESET THE BOARD FIRST."
	print "Insert \"exit\" to leave the application."

	input = 1
	while 1:
		# get keyboard input
		input = raw_input("cmd> ")
		# Python 3 users
		# input = input("cmd> ")

		if input == 'exit':
			try:
				if ser.isOpen():
					ser.close()
			except:
				exit()

		else:
			# send the character to the device
			# (note that I append a \r\n carriage return and line feed to the characters - this is requested by my device)
			ser.write(input + '\r\n')
			out = ''

			# let's wait one second before reading output (let's give device time to answer)
			time.sleep(1)
			while ser.inWaiting() > 0:
				out += ser.read(1)

			if out != '':
				print out