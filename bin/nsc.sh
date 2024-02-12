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

# Prüfen, ob mehrer CPU Core 2 zur Verfügung steht:
CORE_COUNT=$(lscpu | grep 'Kern(e) pro Sockel' | awk '{print $NF}')


# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"

# Die Datei nohup.out ggf. löschen
rm -f nohup.out

echo "Das Hauptscript wird jetzt gestartet."
echo "Alle  Terminal-Ausgaben werden unterdrückt."
echo "Statusabfragen sind möglich durch Aufruf des Scripts \"info.sh\"."

# Aufrufen des Haupt-Scripts mit nohup im Hintergrund
if [ "$CORE_COUNT" -ge 2 ]; then
    echo "Zuordnung des Hauptscripts auf Kern Nr. 2"
    taskset -c 2 nohup "$SCRIPTFILE" &
else
    nohup "$SCRIPTFILE" &
fi
