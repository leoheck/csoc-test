#!/bin/bash

set -o pipefail

# Le da entrada padrao e colore a saida

# Use colors only if connected to a terminal which supports them
if which tput >/dev/null 2>&1; then
	ncolors=$(tput colors)
fi

# 0 – Black
# 1 – Red
# 2 – Green
# 3 – Yellow
# 4 – Blue
# 5 – Magenta
# 6 – Cyan
# 7 – White

if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
	BLACK="$(tput setaf 0)"
	RED="$(tput setaf 1)"
	GREEN="$(tput setaf 2)"
	YELLOW="$(tput setaf 3)"
	BLUE="$(tput setaf 4)"
	BOLD="$(tput bold)"
	NORMAL="$(tput sgr0)"
	# ==
	REDBG=$(tput setab 7)
else
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	BOLD=""
	NORMAL=""
fi



# while read line
# do
#   echo "$line" | \
#   	sed "s/\(erro[^ \t]*\)/$BOLD$RED\1$NORMAL/gI" |
#   	sed "s/\(warn[^ \t]*\)/$BOLD$YELLOW\1$NORMAL/gI" |
#   	sed "s/\(info[^ \t]*\)/$BOLD$BLUE\1$NORMAL/gI"
# done

# < "${1:-/dev/stdin}"



#=========
# NEW WAY

cmd="$@"

echo -e "\n$BOLD$WHITE$cmd$NORMAL"

eval $@ | \
sed "s/\(erro[^ \t]*\)/$BOLD$RED\1$NORMAL/gI" | \
sed "s/\(warn[^ \t]*\)/$BOLD$YELLOW\1$NORMAL/gI" | \
sed "s/\(info[^ \t]*\)/$BOLD$BLUE\1$NORMAL/gI" | \
sed "s/\(\*\s*Synthesis Options Summary\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*HDL Compilation\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*Design Hierarchy Analysis\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*HDL Analysis\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*HDL Synthesis\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*Advanced HDL Synthesis\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*Low Level Synthesis\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*Partition Report\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI" | \
sed "s/\(\*\s*Final Report\s*\*\)/$REDBG$BOLD$BLACK\1$NORMAL/gI"
status=$?

echo
exit $status