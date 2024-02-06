#!/bin/bash
SCRIPTTEXT="Script nsc_main.sh, Version vom 04.02.2024"
SCRIPTFILE="./nsc_main.sh"  # Der Name dieses Scripts, um eine Kopie im Etc-Pfad speichern zu können
# basierend auf frankl-stereo utils (GNU Licence)
# Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)
#
# Dieses Script liest alle Album-Verzeichnisse, die sich im Quellpfad _nsc_source befinden, kopiert und
#     verbessert die betreffenden Musikdateien mindestens zweimal und schreibt diese in den Zielpfad _nsc_target.
#
# Der Aufruf dieses Scripts erfolgt aus dem  Script "nsc.sh" im Hintergrund und ohne Terminal-Ausgaben.
#
# Vorausetzungen:
# - Ein oder zwei Datenträger sind mit dem Linux-Rechner physisch verbunden (z.B. über USB)
# - Auf diesem(n) Datenträger(n) befinden sich folgende Verzeichnisse:
#       "_nsc_source" --> Quelle für die zu improvenden Dateien
#       "_nsc_etc"    --> Quelle für die Steuerdatei _nsc_config.txt sowie die für Infodatei _nsc_improved.txt
#       "_nsc_target" --> Ziel für die improvten Dateien
# - Dabei können "_nsc_source" und "_nsc_target" auf unterschiedlichen Datenträgern liegen.
#       "_nsc_etc" aber muss auf demselben Datenträger liegen wie "_nsc_source". )
# - Das Script liest Vorgaben für die Parameter aus der Datei "_nsc_config.txt", falls eine solche
#       Datei im Ordner "_nsc_etc" liegt. Anderenfalls verwendet das Script die default-Werte von frankl.
# - Das Script kopiert die Datei "_nsc_improved.txt" in die jeweiligen Musikordner im Zielverzeichnis,
#       sofern eine solche Datei im Ordner "_nsc_etc" vorhanden ist.
#       In dieser Datei kann man (optional) die Bedingungen des Improvements individuell dokumentieren.


#23456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
#        1         2         3         4         5         6         7         8         9

# Hilfsvariable für das Script
START_TIME=$(date +%s)
SLASH='/'
CONFIGFILE="_nsc_config.txt"
INFOFILE="_nsc_improved.txt"
TODAY=$(date +"%Y-%m-%d_%H-%M")
LOGFILE=$TODAY"_log.txt"
drive_count=1
mounted_directories=()
TMP=tmp
TMP0=tmp0
SIZE=2097152 # entspricht 2 GiB in kB

# Hilfsvariable für die RAM Laufwerke
WPATH=""
WPATH_PRE=""
# ramdisk für die neuere Methode. Voraussetzung in der /etc/fstab steht
#     tmpfs    /mnt/nscram    tmpfs    defaults,size=4096M    0    0
RAMDISK="/mnt/nscram"
# Variablen für die Horst-Methode
DEV_RAM_PATH="/dev/ram"
MNT_RAM_PATH="/mnt/ram"

# Default-Werte für das Verfahren
NMAX=2
FAST_BUFFER_SIZE=536870912
FAST_LOOPS_PER_SECOND=2000
FAST_BYTES_PER_SECOND=8192000
FAST_DSYNCS_PER_SECOND=100
FAST_NR_REFRESHS=3
SLOW_BUFFER_SIZE=536870912
SLOW_LOOPS_PER_SECOND=2000
SLOW_BYTES_PER_SECOND=8192000
SLOW_DSYNCS_PER_SECOND=100
SLOW_NR_REFRESHS=3
LSLEEP=60
FSLEEP=5
UFSLEEP=1

# Hilfsvariable für die Fortschrittberechung
IMPROVED_FILES_SIZE=0
TO_BE_IMPROVED_FILES_SIZE=0
NEWLY_IMPROVED_FILES_SIZE=0


# Improvefile-Aufruf --> später verwenden
schaffwas_fast(){
    echo "schaffwas_fast Aufruf"
#    cp -v "$1" "$2"
    taskset -c 1 nsc_improvefile.sh "$1" "$2" $FAST_BUFFER_SIZE $FAST_LOOPS_PER_SECOND $FAST_BYTES_PER_SECOND $FAST_DSYNCS_PER_SECOND $FAST_NR_REFRESHS
}

schaffwas_slow(){
    echo "schaffwas_slow Aufruf"
#    cp -v "$1" "$2"
    taskset -c 1 nsc_improvefile.sh "$1" "$2" $SLOW_BUFFER_SIZE $SLOW_LOOPS_PER_SECOND $SLOW_BYTES_PER_SECOND $SLOW_DSYNCS_PER_SECOND $SLOW_NR_REFRESHS
}

# Definition von Funktionen für das Script
# Aufräumarbeiten zum Script-Ende
nsc_cleanup()
{
    echo -n "Uhrzeit: "
    CURRENT_TIME=$(date +"%H:%M")
    echo $CURRENT_TIME
    END_TIME=$(date +%s)
    RUNTIME=$(($END_TIME - $START_TIME))
    HOURS=$(($RUNTIME / 3600))
    MINUTES=$(( ($RUNTIME % 3600) /60 ))
    SECONDS=$(( $RUNTIME % 60 ))
    echo "Laufzeit des Scripts: $HOURS Stunde(n), $MINUTES Minute(n) und $SECONDS Sekunden"
    echo "############################################################################################"
    echo "#                                 nsc_main.sh SCRIPT ENDE                                  #"
    echo "############################################################################################"

    # Kopiere nohup.out in den Logfile
    cp -v nohup.out $ETC_PATH$LOGFILE

    # Unmounte alle im Skript gemounteten Verzeichnisse
    for dir in "${mounted_directories[@]}"; do
        umount "$dir"
        echo "Unmounting: $dir"
    done
}

# Config-Infos ausgeben
print_basic_info()
{
    echo ""
    echo "Ermittelte Basis-Informationen"
    echo ""
    echo -n "Version: "
    echo "$SCRIPTTEXT"
    CURRENT_TIME=$(date +"%H:%M")
    echo -n "Aktuelle Uhrzeit: "
    echo $CURRENT_TIME
    echo -n "Folgender User führt dieses Script aus: "
    who am i
    echo ""
    echo -n "Momentanes Arbeitsverzeichnis dieses Scripts: "
    pwd
    echo -n "Quellverzeichnis: "
    echo "$SOURCE_PATH"
    echo -n "Zielverzeichnis: "
    echo "$TARGET_PATH"
    echo -n "Verzeichnis für Zusatzdateien: "
    echo "$ETC_PATH"
    echo ""
    echo -n "Anzahl der Durchläufe für jede Musikdatei: NMAX="
    echo $NMAX
    echo -n "Puffergröße ind Bytes: FAST_BUFFER_SIZE="
    echo $FAST_BUFFER_SIZE
    echo -n "Loops pro Sekunde FAST_LOOPS_PER_SECOND="
    echo $FAST_LOOPS_PER_SECOND
    echo -n "Bytes pro Sekunde FAST_BYTES_PER_SECOND="
    echo $FAST_BYTES_PER_SECOND
    echo -n "Schreibvorgänge pro Sekunde FAST_DSYNCS_PER_SECOND="
    echo $FAST_DSYNCS_PER_SECOND
    echo -n "Zahl der Refreshes bevor auf die Ramdisk geschrieben wird: FAST_NR_REFRESHS="
    echo $FAST_NR_REFRESHS
    echo -n "Puffergröße ind Bytes: SLOW_BUFFER_SIZE="
    echo $SLOW_BUFFER_SIZE
    echo -n "Loops pro Sekunde SLOW_LOOPS_PER_SECOND="
    echo $SLOW_LOOPS_PER_SECOND
    echo -n "Bytes pro Sekunde SLOW_BYTES_PER_SECOND="
    echo $SLOW_BYTES_PER_SECOND
    echo -n "Schreibvorgänge pro Sekunde SLOW_DSYNCS_PER_SECOND="
    echo $SLOW_DSYNCS_PER_SECOND
    echo -n "Zahl der Refreshes bevor auf die Ramdisk geschrieben wird: SLOW_NR_REFRESHS="
    echo $SLOW_NR_REFRESHS
    echo -n "Wartezeit in Sekunden, bevor die ersten Schreibvorgänge gestartet werden:"
    echo $LSLEEP
    echo -n "Kurzschlafzeit in Sekunden:"
    echo $FSLEEP
    echo -n "Ultra-Kurzschlafzeit in Sekunden:"
    echo $UFSLEEP
}

# CPU Status anzeigen
print_status()
{
    echo ""
    echo "############################################################################################"
    echo "#                                    STATUSINFO                                            #"
    echo "############################################################################################"
    CURRENT_TIME=$(date +"%H:%M")
    echo -n "Aktuelle Uhrzeit: "
    echo $CURRENT_TIME
    echo ""
    /boot/dietpi/dietpi-cpuinfo
    echo ""
    echo "Aktueller Stand der Bearbeitung (ca.-Angaben):"
    IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
    NEWLY_IMPROVED_FILES_SIZE=$((IMPROVED_FILES_SIZE - FORMER_IMPROVED_FILES_SIZE))
    PROGRESS=$((NEWLY_IMPROVED_FILES_SIZE *100 / TO_BE_IMPROVED_FILES_SIZE))
    echo "$PROGRESS % von 100 %"
}

# Fundamentale Funktion zur Überprüfung der Bit-Identität
check_bit_identity(){
    if cmp -s "$1" "$2"; then
        echo "Die Dateien $1 und $2 sind Bit-identisch."
    else
        echo "############################################################################################"
        echo "#               BIT IDENTITÄT VERLETZT - DAS SCRIPT $SCRIPTFILE WIRD BEENDET               #"
        echo "############################################################################################"
        nsc_cleanup
        exit 1
    fi
}

# Funktionen zur Ramdisk-Behandlung
# Neue alternative Methode zur Behandlung des ram.
#create_ram(){
#    N_LOC="$1"
#    echo "create_ram mit Parameter $1 nach neuer Methode aufgerufen."
#    WPATH_PRE="$WPATH"
#    if [ "$((N_LOC % 2))" -eq 0 ]; then
#        WPATH="/mnt/nscram0/"
#    else
#        WPATH="/mnt/nscram1/"
#    fi
#}

#destroy_ram(){
#    N_LOC="$1"
#    echo "destroy_ram mit Parameter $1 nach neuer Methode aufgerufen."
#    if [ "$((N_LOC % 2))" -eq 0 ]; then
#        umount -v /mnt/nscram0/
#        sleep $UFSLEEP
#    else
#        umount -v /mnt/nscram1/
#        sleep $UFSLEEP
#    fi
#}

# Methode von Horst
# Erzeuge eine Ramdisk mit 2G Größe, Übergabeparameter: Nummer der RAM Disk beginnend mit 0
create_ram(){
    N_LOC="$1"
    mke2fs -t ext2 -O extents -vm0 "$DEV_RAM_PATH$N_LOC" 2G -b 1024
    sleep $UFSLEEP
    mkdir -v "$MNT_RAM_PATH$N_LOC"
    mount -v "$DEV_RAM_PATH$N_LOC" "$MNT_RAM_PATH$N_LOC"
    sleep $UFSLEEP
    chmod --verbose a+rwx "$MNT_RAM_PATH$N_LOC"
    WPATH_PRE="$WPATH"
    WPATH="$MNT_RAM_PATH$N_LOC$SLASH"
}

# Lösche die Ramdisk mit der entsprechenden Nummer
destroy_ram(){
    N_LOC="$1"
    umount -v "$DEV_RAM_PATH$N_LOC"
    sleep $UFSLEEP
    rmdir -v "$MNT_RAM_PATH$N_LOC"
    rm -v "$DEV_RAM_PATH$N_LOC"
}

# Start der Scriptausgabe
echo "############################################################################################"
echo "#                             SCRIPT nsc_main.sh GESTARTET                                 #"
echo "############################################################################################"
echo ""

# Setzen der Pfad-Varialben "SOURCE_PATH", "TARGET_PATH" und "ETC_PATH"
# Durchlaufe alle nicht gemounteten Laufwerke
echo "Mounten von Datenträgern und Auslesen wichtiger Pfade"
echo ""
for drive in $(lsblk -o NAME,MOUNTPOINT -nr | awk '$2 == "" {print $1}'); do
    # Mounte das Laufwerk unter /mnt/nscX, wobei X die Laufwerksnummer ist
    mount_point="/mnt/nsc$drive_count"
    mkdir -p "$mount_point"

    # Mounte das Laufwerk
    mount -v "/dev/$drive" "$mount_point"

    # Füge das gemountete Verzeichnis zur Liste hinzu
    mounted_directories+=("$mount_point")

    # Prüfe, ob das Verzeichnis /mnt/nscX/_nsc_source existiert
    source_path="$mount_point/_nsc_source"
    etc_path="$mount_point/_nsc_etc"
    if [ -d "$source_path" ]; then
        SOURCE_PATH="$source_path$SLASH"
        ETC_PATH="$etc_path$SLASH"
        echo "SOURCE_PATH set to $SOURCE_PATH"
        echo "ETC_PATH set to $ETC_PATH"
    fi

    # Prüfe, ob das Verzeichnis /mnt/nscX/_nsc_target existiert
    target_path="$mount_point/_nsc_target"
    if [ -d "$target_path" ]; then
        TARGET_PATH="$target_path$SLASH"
        echo "TARGET_PATH set to $TARGET_PATH"
    fi

    # Falls weder _nsc_source noch _nsc_target existieren, unmounte das Laufwerk
    if [ ! -d "$target_path" ] && [ ! -d "$source_path" ]; then
        # Weder $target_path noch $source_path existieren
        echo "Weder $target_path noch $source_path existieren."
        echo "$mount_point wird ungemountet"
        umount -v "$mount_point"
    fi
    # Inkrementiere die Laufwerksnummer für das nächste Laufwerk
    ((drive_count++))
done


# Auslesen der Variablen aus der Datei "_nsc_config", sofern diese vorhanden ist
# sowie ggf. Überschreiben der default-Werte

CFILE="$ETC_PATH$CONFIGFILE"
echo ""
echo "Auslesen der Konfigurationsdatei $CFILE"

# Überprüfen, ob die Datei existiert
if [ -e "$CFILE" ]; then
    # Schleife zum Lesen jeder Zeile in der Datei
    while IFS= read -r line; do
        # echo "habe Zeile $line gelesen"
        # Leerzeilen und Kommentare ignorieren
        if [[ -n "$line" && "$line" != \#* ]]; then
            # Variablen setzen, indem wir die Zeile in Teile aufteilen (hier am "=")
            key=$(echo "$line" | cut -d'=' -f1)
            value=$(echo "$line" | cut -d'=' -f2-)

            # Variablen setzen
            declare "$key=$value"

            # Optional: Ausgabe der gesetzten Variablen
            # echo "$key=$value"
        fi
    done < "$CFILE"
else
    echo "Die Datei $CFILE existiert nicht. Es werden default-Parameter verwendet."
fi

# Vorbereitung für das Ausgeben des laufenden Bearbeitungsstandes:
IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
TO_BE_IMPROVED_FILES_SIZE=$(du -s "$SOURCE_PATH" | awk '{print $1}')

# Starte das Script und zeige die Config-Info
print_basic_info

# Pausieren
echo -n "Das Script pausiert jetzt "
echo -n $LSLEEP
echo -e " Sekunde(n). \n"
sleep $LSLEEP

# Hier beginnt die eigentliche Arbeit dieses Scripts
# Verzeichnisschleife - läuft durch jedes Verzeichnis (= Album-Ordner) im Quellverzeichnispfad
echo ""
echo "############################################################################################"
echo "#                             BEGINN DER VERZEICHNISSCHLEIFE                               #"
echo "############################################################################################"
echo ""
for DIR in "$SOURCE_PATH"/*; do
    if [ -d "$DIR" ]; then
        DIRNAME=$(basename "$DIR")  # Store directory name with spaces
        echo -e "\nDer Inhalt im folgenden Album-Verzeichnis wird gleich improved:"
        echo -n "Verzeichnisname: "
        echo "$DIRNAME"

        # Anlegen des Album-Verzeichnisses im Zielpfad
        mkdir -v "$TARGET_PATH$DIRNAME"
        cp -v "$ETC_PATH$INFOFILE" "$TARGET_PATH$DIRNAME"

        # Schleife durch die alle Files im laufenden Verzeichnis
        for FILE in "$SOURCE_PATH$DIRNAME"/*; do
            # Status ausgeben
            print_status
            # set each file name to the 'FILENAME' variable
            FILENAME=$(basename "$FILE")
            echo""
            echo "Folgende Musikdatei wird gleich improvt: "
            echo "$FILENAME"
            echo ""

            # Ramdisk bereitstellen
            create_ram 0
            N=0
#            WPATH="$MNT_RAM_PATH$N$SLASH"

            echo ""
            echo "Erster improvefile-Durchlauf für diese Musikdatei (schnelles Verfahren)"
            echo ""
            # improvefile-Aufruf für die laufende Datei zum ersten Mal
            schaffwas_fast "$SOURCE_PATH$DIRNAME$SLASH$FILENAME" "$WPATH$TMP0"
            check_bit_identity "$SOURCE_PATH$DIRNAME$SLASH$FILENAME" "$WPATH$TMP0"

            # Sicherstellen, dass die Datei $TMP0 nicht nur in den Cache geschrieben wird
            sync
            sleep $UFSLEEP
            vmtouch -e "$WPATH$TMP0"
            sleep $UFSLEEP

            # For-Schleife für NMAX Mehrfachanwendung von improvefile je zu improvender Datei
            for ((N=1; N<=NMAX - 1; N++)); do
                if [[ $N -lt $(($NMAX - 1)) ]]
                then
                    # Schnelles Verfahren bis zum vorletzten Durchlauf
                    NPRE=$(($N - 1))

                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (schnelles Verfahren)"
                    echo ""

 #                   WPATH_PRE="$WPATH"
                    create_ram $N
 #                   WPATH="$MNT_RAM_PATH$N$SLASH"
                    schaffwas_fast "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"
                    check_bit_identity "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"

                    # Sicherstellen, dass die Datei $TMP$N nicht nur in den Cache geschrieben wird
                    sync
                    sleep $UFSLEEP
                    vmtouch -e "$WPATH$TMP$N"
                    sleep $UFSLEEP

                    # Aufräumen
                    shred "$WPATH_PRE$TMP$NPRE"
                    rm -v "$WPATH_PRE$TMP$NPRE"
                    destroy_ram $NPRE

                else
                    # Langsames Verfahren beim letzten Durchlauf
                    NPRE=$(($NMAX - 2))

                    echo ""
                    echo "Letzter Durchlauf von improvefile (Nr. $N, langsames Verfahren)"
                    echo ""

                    echo "$WPATH$TMP$NPRE"
                    schaffwas_slow "$WPATH$TMP$NPRE" "$TARGET_PATH$DIRNAME$SLASH$FILENAME"
                    check_bit_identity "$WPATH$TMP$NPRE" "$TARGET_PATH$DIRNAME$SLASH$FILENAME"

                    # Sicherstellen, dass die Datei "$TARGET_PATH$DIRNAME$SLASH$FILENAME" nicht nur in den Cache geschrieben wird
                    sync
                    sleep $UFSLEEP
                    vmtouch -e "$TARGET_PATH$DIRNAME$SLASH$FILENAME"
                    sleep $UFSLEEP

                    # Aufräumen
                    shred "$WPATH$TMP$NPRE"
                    rm -v "$WPATH$TMP$NPRE"
                    destroy_ram $NPRE
                    echo "improvefile-Anwendung für diese Musikdatei  abgeschlossen"
                fi
            done
        done
    fi
done

# Aufräumarbeiten zum Script-Ende
nsc_cleanup
