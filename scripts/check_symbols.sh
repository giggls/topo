#!/bin/bash

# Check if all symbols referenced in mapfile are available
# either as files or as an internal symbol definition

MAPFILE=mytopo.map

for i in $(grep SYMBOL $MAPFILE |sed -e 's/^ *SYMBOL *//g' -e 's/\"//g'); do
  if ! [ -f $i ]; then
    # if SYMBOL is not a file it must be an internal SYMBOL
    # so we need to check for this first before printing an
    # error message
    if ! egrep -q "NAME \"*$i\"*$" $MAPFILE; then
      echo "file/symbol "$i" not found!"
    fi
  fi
done