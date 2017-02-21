#!/bin/bash

# X11 Color names
# /etc/X11/rgb.txt

# // MAIN_STATES
# localparam
# 	INIT = 0,
# 	S1 = 5,
# 	S2 = 6,
# 	S3 = 7,
# 	S4 = 8,
# 	S5 = 9,
# 	S6 = 10,
# 	S7 = 11,
# 	S8 = 12,
# 	S9 = 13,
# 	INITIAL_MESSAGE = 1,
# 	GET_INTERNAL_STATE = 2,
# 	CSOC_RUN = 3,
# 	PROCEDURE_DONE = 4;

bits=$(($(grep "state, state_nxt;" src/uart_parser.v | cut -d'[' -f2 | cut -d':' -f1)+1))
state_list=$(sed -n '/MAIN_STATES/,/;/p' src/uart_parser.v | sed -e '1,2d' | sed 's/[,; \t\s\r]//g')

# echo $bits
# echo "$state_list"

IFS=$'\n'
for i in $state_list; do
	name=$(echo "$i" | tr '\r' ' ' | cut -d'=' -f1)
	code=$(echo "$i" | tr '\r' ' ' | cut -d'=' -f2)
	code_bin=$(echo "obase=2;${code}" | bc)
	code_bin_padding=$(printf "%0${bits}d" ${code_bin})

	lines=$(cat /etc/X11/rgb.txt | sed '/^!.*/d' | wc -l)
	line_num=$(shuf -i 0-$lines -n 1)
	line=$(sed "${line_num}q;d" /etc/X11/rgb.txt | sed '/^!.*/d' )
	color=$(echo $line | cut -c 15-)
	# color_tag="?$color?"	
	states="$code_bin_padding ${color_tag}$name\n$states"
done

echo -e "$states"