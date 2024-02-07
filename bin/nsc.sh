#!/bin/bash
# Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)
# Dieses Script startet das Hauptscript für das nsc-improvefile-Verfahren.
# basierend auf frankl-stereo utils (GNU Licence)
#
# Aufruf erfolgt mit "nsc.sh" für Verwendung der Standard tmpfs Ramdisk Methode
#     oder mit "nsc.sh ext" für Verwendung der dynamischen ext Ramdisk Methode
#
# Voraussetzung: dieses Script befindet sich in einem für die in der $PATH Variable festgeleten
#     Verzeichnis, typischerweise in /usr/local/bin
###################################################################################################

WPATH="/root/nsc/"
SCRIPTFILE="./nsc_main.sh"
RAM_METHOD="tmpfs"

# Überprüfen, ob ein Parameter übergeben wurde
if [ $# -eq 1 ]; then
    # Wenn ein Parameter übergeben wurde, setze RAM_METHOD auf den übergebenen Wert
    RAM_METHOD="$1"
fi

# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"

rm -f nohup.out
if [ "$RAM_METHOD" = "tmpfs" ]; then
    echo "Das Hauptscript wird jetzt gestartet."
    echo "Es arbeitet mit der Standard tmpfs Ramdisk Methode."
    echo "Alle  Terminal-Ausgaben werden unterdrückt."
    # Aufrufen des Haupt-Scripts mit nohup im Hintergrund
    nohup "$SCRIPTFILE" &
elif [ "$RAM_METHOD" = "ext" ]; then
    echo "Das Hauptscript wird jetzt gestartet."
    echo "Es arbeitet mit der dynamischen ext Ramdisk Methode."
    echo "Alle Terminal-Ausgaben werden unterdrückt."
    # Aufrufen des Haupt-Scripts mit nohup im Hintergrund
    nohup "$SCRIPTFILE" "ext" &
else
    echo "Aufrufparameter \"$RAM_METHOD\" ist nicht vorgesehen. Folgende Möglichkeiten stehen zur Verfügung:"
    echo "\"nsc.sh\" Startet das Hauptscript mit der Standard tmpfs Ramdisk Methode."
    echo "\"nsc.sh ext\" Startet das Hauptscript mit der dynamischen ext Ramdisk Methode."
    exit 1
fi

echo "Statusabfragen sind möglich durch Aufruf des Scripts \"info.sh\"."

