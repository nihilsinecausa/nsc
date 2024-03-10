#!/bin/bash

echo "Dieses Script beendet das Hauptscript nsc_main.sh." 
echo "Ist das so gewollt? (yes für ja, beliebiges anderes Zeichen für nein)"
read user_input

if [[ $user_input == "yes" ]]; then
    # Beende das Hauptscript nsc_main.sh
    if pkill -f nsc_main.sh; then
        echo "Hauptscript nsc_main.sh wurde beendet. Weitere Informationen sind über info.sh verfügbar."
    else
        echo "Fehler beim Beenden des Hauptscripts."
    fi
else
    echo "Das Hauptscript wurde wunschgemäß nicht beendet."
fi
