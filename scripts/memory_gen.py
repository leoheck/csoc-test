#!/usr/bin/env python

# Script simples pra gerar o arquivo de memoria
# String nao pode ter \n e coisas do tipo

import argparse
import time
import datetime
import itertools
import operator

parser = argparse.ArgumentParser(description='Generate a ROM')
parser.add_argument('-f', dest='outfile', help='Output file. If none, prints to stdout')
parser.add_argument('data', help='String with data to put in the ROM')
args = parser.parse_args()

# Converte string para memoria
memory = list()
for i in list(args.data):
	memory.append(i.encode("hex"))

# Imprime na tela
if not args.outfile:
	print "Input data:", args.data
	print "Data size:", len(list(args.data))
	print "Memory:",
	for i in range(len(memory)):
		if i%20 == 0:
			print
		print memory[i]

# Salva em um arquivo
else:
	file = open(args.outfile, "w")
	for i in range(len(memory)):
		file.write(memory[i] + "\n")
	file.close()
