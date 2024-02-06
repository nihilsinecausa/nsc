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
SLEEPTIME=${2:-15} # Verwendet den zweiten Parameter oder setzt standardmäßig 15
###################################################################################################

# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"

N=1
if [ -e "$FILE" ]; then
    while true
    do
        clear
        echo "guggemodo.sh Durchlauf Nr. $N"
        echo "Nächster Durchlauf in $SLEEPTIME Sekunden"
        echo ""
#        echo "Zeilenzahl zur Anzeige ist $NUM_LINES"
        echo "Letzte $NUM_LINES Zeilen der Datei nohup.out:"
        echo ""
        tail -n $NUM_LINES "$FILE"
        sleep $SLEEPTIME
    done
else
    echo "Die Datei $FILE existiert nicht."
fi

