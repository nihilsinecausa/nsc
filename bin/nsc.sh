#!/bin/bash
# Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)
#
# Dieses Script startet das Hauptscript für das nsc-improvefile-Verfahren.
# Aufruf erfolgt mit "nsc.sh"
# Voraussetzung: dieses Script befindet sich in einem für die in der $PATH Variable festgeleten
#     Verzeichnis, typischerweise in /usr/local/bin

#23456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
#        1         2         3         4         5         6         7         8         9

###################################################################################################
# INDIVIDUELL ZU SETZENDES
WPATH="/root/nsc/"
SCRIPTFILE="./nsc_main.sh"
# SCRIPTFILE="./mytest.sh"
###################################################################################################

# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"
echo -n "Das Script arbeitet jetzt im Arbeitsverzeichnis: "
pwd

rm -v nohup.out
echo "Das Hauptscript $SCRIPTFILE wird jetzt gestartet. Dabei werden alle  Terminal-Ausgaben unterdrückt."
# Aufrufen des Haupt-Scripts mit nohup im Hintergrund
nohup "$SCRIPTFILE" &
echo "Statusabfragen sind möglich durch Aufruf des Scripts info.sh"

