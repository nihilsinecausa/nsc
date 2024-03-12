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
CHECK_STORAGE=0

# Prüfen, ob mehrer CPU Core 2 zur Verfügung steht:
CORE_COUNT=$(lscpu | grep 'Kern(e) pro Sockel' | awk '{print $NF}')

# Aufruf des Scripts ggf. mit Optionen
# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Usage: nsc.sh [OPTIONS]"
    echo "Options:"
    echo "  -check   Enable check storage mode (nur Info über die Speichersituation, keine Bearbeitung)"
    echo "  -h, --help   Show this help message"
}

# Optionen verarbeiten
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -check)
            CHECK_STORAGE=1
            echo "Aufruf mit Option -check, d.h. es wird nur eine Storage-Info geliefert, keine Bearbeitung."
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unbekannte Option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done


# Zum Arbeitsverzeichnis wechseln
cd "$WPATH"

# Die Datei nohup.out ggf. löschen
rm -f nohup.out

echo "Das Hauptscript wird jetzt gestartet."
echo "Alle  Terminal-Ausgaben werden unterdrückt."
echo "Statusabfragen sind möglich durch Aufruf des Scripts \"info.sh\"."

# Aufrufen des Haupt-Scripts ggf. im Hintergrund unter Verwendung von nohup
if [ "$CORE_COUNT" -ge 2 ] && [ "$CHECK_STORAGE" -eq 1 ]; then
    "$SCRIPTFILE" -check
elif [ "$CORE_COUNT" -lt 2 ] && [ "$CHECK_STORAGE" -eq 1 ]; then
    "$SCRIPTFILE" -check 
elif [ "$CORE_COUNT" -ge 2 ] && [ "$CHECK_STORAGE" -eq 0 ]; then
    taskset -c 2 nohup "$SCRIPTFILE" &
else
    nohup "$SCRIPTFILE" &
fi
