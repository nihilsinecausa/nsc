#!/bin/bash
# Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)
#
#23456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
#        1         2         3         4         5         6         7         8         9
# Dieses Script startet das Hauptscript für das Improvefile-Verfahren.
# Aufruf erfolgt einfach mit "nsc.sh"
# Voraussetzung: dieses Script befindet sich in einem für die in der $PATH Variable festgeleten 
#     Verzeichnis, typischerweise in /usr/local/bin

###################################################################################################
# INDIVIDUELL ZU SETZENDES
WPATH="/root/nsc/"
FILE="nohup.out"
NUM_LINES=${1:-50}  # Verwendet den ersten Parameter oder setzt standardmäßig 30
###################################################################################################

# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"

clear

echo "info.sh Script"
echo "Letzte $NUM_LINES Zeilen der Datei nohup.out:"
echo ""

if [ -e "$FILE" ]; then
    tail -n "$NUM_LINES" "$FILE"
else
    echo "Die Datei $FILE existiert nicht."
fi

