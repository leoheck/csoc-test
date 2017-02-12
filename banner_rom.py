#!/usr/bin/env python

import time
import datetime
import itertools
import operator

def sort_uniq(sequence):
    return itertools.imap(
        operator.itemgetter(0),
        itertools.groupby(sorted(sequence)))

date_str = datetime.datetime.now().strftime("%y-%m-%d")
time_str = datetime.datetime.now().strftime("%H_%M")

banner = "CSoC" + " " + date_str + " " + time_str + " " + "GAPH" + " " + "LHEC" + " "

# print "Banner:", "'" + banner + "'"
# print "Characters:", len(list(banner))

# print
# print "Memory:"

for i in range(len(list(banner))):
	# print hex(banner[i])
	# print "8'h{}", hex(banner[i])
	print("8'h{0:02x}".format(ord(banner[i])))

# print
# print "Used characters"
# used_chars = list(sort_uniq(list(banner)))
# for i in range(len(used_chars)):
	# print("8'h{0:02x} // '{0:c}'".format(ord(used_chars[i]), used_chars[i]))
