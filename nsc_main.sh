#!/bin/bash
SCRIPTTEXT="Script nsc.sh, Version vom 06.02.2024"
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
#       "_source" --> Quelle für die zu improvenden Dateien
#       "_etc"    --> Quelle für die Steuerdatei _nsc_config.txt sowie die für Infodatei _nsc_improved.txt
#       "_improved" --> Ziel für die improvten Dateien
# - Dabei können "_source" und "_improved" auf unterschiedlichen Datenträgern liegen.
#       "_etc" aber muss auf demselben Datenträger liegen wie "_source". )
# - Das Script liest Vorgaben für die Parameter aus der Datei "_config.txt", falls eine solche
#       Datei im Ordner "_etc" liegt. Anderenfalls verwendet das Script die default-Werte von frankl.
# - Das Script kopiert die Datei "_improved.txt" in die jeweiligen Musikordner im Zielverzeichnis,
#       sofern eine solche Datei im Ordner "_etc" vorhanden ist.
#       In dieser Datei kann man (optional) die Bedingungen des Improvements individuell dokumentieren.


#23456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
#        1         2         3         4         5         6         7         8         9

# Hilfsvariable für das Script
START_TIME=$(date +%s)
SLASH='/'
TODAY=$(date +"%Y-%m-%d_%H-%M")
LOGFILE=$TODAY"_log.txt"
drive_count=1
mounted_directories=()
TMP=tmp
TMP0=tmp0
TMP1=tmp1
SIZE=2097152 # entspricht 2 GiB in kB

# Default-Werte für die Script-Steuerung (kann über die nsc_config.txt Datei geändert werden)
SETTINGS="nsc_settings.txt"
AUTO_MOUNT=1
SOURCE_DIR="_source"
ETC_DIR="_etc"
TARGET_DIR="_improved"
TARGET_TMP_DIR="_tmp_improved"

CONFIGFILE="_config.txt"
INFOFILE="_improved.txt"

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
NMAX_RAM=9
NMAX_PHYS=3
NMAX=$((NMAX_RAM + NMAX_PHYS))
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

# Hilfsvariable für mount und unmount
MAX_M_ATTEMPTS=10
M_ATTEMPT=0

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

    if [ $AUTO_MOUNT -eq 1 ]; then
        # Unmounte alle im Skript gemounteten Verzeichnisse
        for dir in "${mounted_directories[@]}"; do
            umount "$dir"
            echo "Unmounting: $dir"
        done
    else
        echo "Da Auto-Mount ausgeschaltet ist, wird kein umount externer Datenträger vorgenommen."
    fi
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
    echo -n "Verzeichnis für Zusatzdateien: "
    echo "$ETC_PATH"
    echo -n "Zielverzeichnis: "
    echo "$TARGET_PATH"
    echo -n "Verzeichnis für temporär improvte Dateien: "
    echo "$TARGET_TMP_PATH"
    echo ""
    echo -n "Anzahl der schnellen Durchläufe für jede Musikdatei: NMAX_RAM="
    echo $NMAX_RAM
    echo -n "Anzahl der langsamen Durchläufe für jede Musikdatei: NMAX_PHYS="
    echo $NMAX_PHYS
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

# Sicherstelle, dass der im Argument übergebene Mount-Point undgemoutet udn wieder gemountet wird
ensure_umount_and_mount(){
    MPATH_TARGET="$1"
    M_ATTEMPT=0

    while true; do
        echo "Schleifendurchlauf Nr. $M_ATTEMPT"

        mount $MPATH_TARGET
        if [ $? -eq 0 ]; then
            echo "mount erfolgreich durchgeführt"
            break;
        else
            umount $MPATH_TARGET
            if [ $? -eq 0 ]; then
                echo "umount erfolgreich durchgeführt, nach Kurzschlaf weiter in der while Schleife"
                sleep $FSLEEP
            fi
        fi

        M_ATTEMPT=$((M_ATTEMPT + 1))

        if [ $M_ATTEMPT -eq $MAX_M_ATTEMPTS ]; then
            echo "Mächtig schwerer Fehler! Umount und Mount nicht sicher möglich"
            break;    # optional exit 1
        fi
    done
}

# Funktionen zur Ramdisk-Behandlung
# Neue alternative Methode zur Behandlung des ram.
create_ram(){
    N_LOC="$1"
    echo "create_ram mit Parameter $1 nach neuer Methode aufgerufen."
    WPATH_PRE="$WPATH"
    if [ "$((N_LOC % 2))" -eq 0 ]; then
        WPATH="/mnt/nscram0/"
    else
        WPATH="/mnt/nscram1/"
    fi
}

destroy_ram(){
    N_LOC="$1"
    echo "destroy_ram mit Parameter $1 nach neuer Methode aufgerufen."
    if [ "$((N_LOC % 2))" -eq 0 ]; then
        umount -v /mnt/nscram0/
        sleep $UFSLEEP
    else
        umount -v /mnt/nscram1/
        sleep $UFSLEEP
    fi
}

# Methode von Horst
# Erzeuge eine Ramdisk mit 2G Größe, Übergabeparameter: Nummer der RAM Disk beginnend mit 0
#create_ram(){
#    N_LOC="$1"
#    mke2fs -t ext2 -O extents -vm0 "$DEV_RAM_PATH$N_LOC" 2G -b 1024
#    sleep $UFSLEEP
#    mkdir -v "$MNT_RAM_PATH$N_LOC"
#    mount -v "$DEV_RAM_PATH$N_LOC" "$MNT_RAM_PATH$N_LOC"
#    sleep $UFSLEEP
#    chmod --verbose a+rwx "$MNT_RAM_PATH$N_LOC"
#    WPATH_PRE="$WPATH"
#    WPATH="$MNT_RAM_PATH$N_LOC$SLASH"
#}

# Lösche die Ramdisk mit der entsprechenden Nummer
#destroy_ram(){
#    N_LOC="$1"
#    umount -v "$DEV_RAM_PATH$N_LOC"
#    sleep $UFSLEEP
#    rmdir -v "$MNT_RAM_PATH$N_LOC"
#    rm -v "$DEV_RAM_PATH$N_LOC"
#}

# Start der Scriptausgabe
echo "############################################################################################"
echo "#                             SCRIPT nsc_main.sh GESTARTET                                 #"
echo "############################################################################################"
echo ""

# Auslesen der Variablen aus der Datei "$SETTINGS", sofern diese vorhanden ist
# sowie ggf. Überschreiben der default-Werte
#CFILE="$ETC_PATH$CONFIGFILE"
echo ""
echo "Auslesen der Konfigurationsdatei $SETTINGS"

# Überprüfen, ob die Datei existiert
if [ -e "$SETTINGS" ]; then
    # Schleife zum Lesen jeder Zeile in der Datei
    while IFS= read -r line; do
        # echo "habe Zeile $line gelesen"
        # Leerzeilen und Kommentare ignorieren
        if [[ -n "$line" && "$line" != \#* ]]; then
            # Variablen setzen, indem wir die Zeile in Teile aufteilen (hier am "=")
            key=$(echo "$line" | cut -d'=' -f1)
            value=$(echo "$line" | cut -d'=' -f2-)

            # Variablen setzen
            declare "$key=${value//\"/}"

            # Optional: Ausgabe der gesetzten Variablen
            echo "$key=$value"
        fi
    done < "$SETTINGS"
else
    echo "Die Datei $SETTINGS existiert nicht. Es werden default-Parameter verwendet."
fi

# Setzen der Pfad-Varialben "SOURCE_PATH", "TARGET_PATH" und "ETC_PATH"
# Durchlaufe alle nicht gemounteten Laufwerke
echo ""
echo "Mounten von Datenträgern und Auslesen wichtiger Pfade"
echo ""

if [ $AUTO_MOUNT -eq 1 ]; then
    for drive in $(lsblk -o NAME,MOUNTPOINT -nr | awk '$2 == "" {print $1}'); do
        # Mounte das Laufwerk unter /mnt/nscX, wobei X die Laufwerksnummer ist
        mount_point="/mnt/nsc$drive_count"
        mkdir -p "$mount_point"

        # Mounte das Laufwerk
        mount -v "/dev/$drive" "$mount_point"

        # Füge das gemountete Verzeichnis zur Liste hinzu
        mounted_directories+=("$mount_point")

        # Prüfe, ob das Verzeichnis /mnt/nscX/_nsc_source existiert
        source_path="$mount_point/$SOURCE_DIR"
        etc_path="$mount_point/$ETC_DIR"
        if [ -d "$source_path" ]; then
            SOURCE_PATH="$source_path$SLASH"
            ETC_PATH="$etc_path$SLASH"
            echo "SOURCE_PATH set to $SOURCE_PATH"
            echo "ETC_PATH set to $ETC_PATH"
        fi

        # Prüfe, ob das Verzeichnis /mnt/nscX/_nsc_target existiert
        target_path="$mount_point/$TARGET_DIR"
        target_tmp_path="$mount_point/$TARGET_TMP_DIR"
        if [ -d "$target_path" ]; then
            TARGET_PATH="$target_path$SLASH"
            TARGET_TMP_PATH="$target_tmp_path$SLASH"
            MPATH="$mount_point"
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
fi

# Auslesen der Variablen aus der Datei "_config", sofern diese vorhanden ist
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

# Diese Berechnung muss zwingend nach dem Einlesen erfolgen.
NMAX=$((NMAX_RAM + NMAX_PHYS))


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

            # große for-Schleife mit 5 zu unterscheidenden Fällen
            for ((N=1; N<=NMAX; N++)); do

                # N = 1 von _source nach RAM
                if [ $N -eq 1 ]; then

                    echo ""
                    echo "Erster improvefile-Durchlauf für diese Musikdatei (schnelles Verfahren; von _source ins RAM)"
                    echo ""

                    # Ramdisk bereitstellen
                    create_ram $N

                    # improvefile-Aufruf für die laufende Datei zum ersten Mal
                    schaffwas_fast "$SOURCE_PATH$DIRNAME$SLASH$FILENAME" "$WPATH$TMP$N"
                    check_bit_identity "$SOURCE_PATH$DIRNAME$SLASH$FILENAME" "$WPATH$TMP$N"

                    # Sicherstellen, dass die Datei $TMP1 nicht nur in den Cache geschrieben wird
                    sync
                    sleep $UFSLEEP
                    vmtouch -e "$WPATH$TMP$N"
                    sleep $UFSLEEP

                # N >= NMAX_RAM von RAM nach RAM
                elif [ $N -le $NMAX_RAM ]; then

                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (schnelles Verfahren; von RAM nach RAM)"
                    echo ""

                    # Zähler und Ramdisk bereitstellen ($WPATH wird in create_ram belegt)
                    NPRE=$(($N - 1))
                    create_ram $N

                    # improvefile-Aufruf
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

                # N = NMAX_RAM + 1 von RAM nach phys-tmp
                elif [ $N -eq $((NMAX_RAM + 1)) ]; then

                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (langsames Verfahren; von RAM nach phys-tmp)"
                    echo ""

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"
                    WPATH="$TARGET_TMP_PATH"

                    # improvefile-Aufruf
                    schaffwas_slow "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"
                    check_bit_identity "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"

                    # Sicherstellen, dass die Datei $TMP$N nicht nur in den Cache geschrieben wird
                    sync
                    sleep $UFSLEEP
                    vmtouch -e "$WPATH$TMP$N"
                    sleep $UFSLEEP

                    # Aufräumen in der Ramdisk
                    shred "$WPATH_PRE$TMP$NPRE"
                    rm -v "$WPATH_PRE$TMP$NPRE"
                    destroy_ram $NPRE

                # N > NMAX_RAM + 1 und N <= NMAX - 1 von phys-tmp nach phys-tmp
                elif [ "$N" -gt "$((NMAX_RAM + 1))" ] && [ "$N" -le "$((NMAX - 1))" ]; then

                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (langsames Verfahren; von phys-tmp nach phys-tmp)"
                    echo ""

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"
                    WPATH="$TARGET_TMP_PATH"

                    # improvefile-Aufruf
                    schaffwas_slow "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"
                    check_bit_identity "$WPATH_PRE$TMP$NPRE" "$WPATH$TMP$N"

                    # Sicherstellen, dass die Datei $TMP$N nicht nur in den Cache geschrieben wird
                    sync
                    sleep $UFSLEEP
                    vmtouch -e "$WPATH$TMP$N"
                    sleep $UFSLEEP

                    # Aufräumen
                    shred "$WPATH_PRE$TMP$NPRE"
                    rm -v "$WPATH_PRE$TMP$NPRE"
                    ensure_umount_and_mount "$MPATH"

                # N = NMAX von phys-tmp nach _improved
                else

                    echo ""
                    echo "Letzter Durchlauf von improvefile für diese Musikdatei (Nr. $N, langsames Verfahren, von phys-tmp nach _improved)"
                    echo ""

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"

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
                    ensure_umount_and_mount "$MPATH"

                    echo "improvefile-Anwendung für diese Musikdatei  abgeschlossen"
                fi
            done
        done
    fi
done

# Aufräumarbeiten zum Script-Ende
nsc_cleanup
