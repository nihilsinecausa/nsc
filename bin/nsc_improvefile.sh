#!/bin/bash
# Dieses Script stammt ursprünglich von frankl und wurde modifiziert für den
#    Aufruf aus nsc_main.sh.
# Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)


if test -e "$2" ; then
  echo "the file $2 already exists, please delete it first"
  exit
fi

bufhrt --file="$1" --outfile="$2" --buffer-size="$3" \
       --loops-per-second="$4" --bytes-per-second="$5" \
       --dsyncs-per-second="$6" --number-refreshs="$7" --interval --verbose

