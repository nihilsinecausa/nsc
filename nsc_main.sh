#!/bin/bash
SCRIPTTEXT="Script nsc.sh, Version vom 09.02.2024"
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
#       "_A_SOURCE" --> Quelle für die zu improvenden Dateien
#       "_B_ETC"    --> Quelle für die Steuerdatei _nsc_config.txt sowie die für Infodatei _nsc_improved.txt
#       "_IMPROVED" --> Ziel für die improvten Dateien
# - Dabei können "_source" und "_improved" auf unterschiedlichen Datenträgern liegen.
#       "_etc" aber muss auf demselben Datenträger liegen wie "_source". )
# - Das Script liest Vorgaben für die Parameter aus der Datei "_config.txt", falls eine solche
#       Datei im Ordner "_B_ETC" liegt. Anderenfalls verwendet das Script die default-Werte von frankl.
# - Das Script kopiert die Datei "_improved.txt" in die jeweiligen Musikordner im Zielverzeichnis,
#       sofern eine solche Datei im Ordner "_B_ETC" vorhanden ist.
#       In dieser Datei kann man (optional) die Bedingungen des Improvements individuell dokumentieren.
# - Für die Standard-Ramdisk Methode benötigt das Script zwei Ramdisks.
#       Dazu folgende Zeilen in die fstab eintragen und anschließend rebooten
#       tmpfs    /mnt/nscram0    tmpfs    defaults,size=2048M    0    0
#       tmpfs    /mnt/nscram1    tmpfs    defaults,size=2048M    0    0
#

###################################################################################################
#                  Definition von Variablen für das Script
###################################################################################################

# Hilfsvariable für das Script
START_TIME=$(date +%s)
SLASH='/'
STAR='*'
TODAY=$(date +"%Y-%m-%d_%H-%M")
LOGFILE=$TODAY"_log.txt"
drive_count=1
mounted_directories=()
TMP=tmp
TMP0=tmp0
TMP1=tmp1

# Default-Werte für die Script-Steuerung (kann über die nsc_config.txt Datei geändert werden)
SETTINGS="nsc_settings.txt"
AUTO_MOUNT=1
SOURCE_DIR="_A_SOURCE"
ETC_DIR="_B_ETC"
TARGET_DIR="_IMPROVED"
TARGET_TMP_DIR="_NSC_TMP_IMPROVED"
MOUNT_PATH_TARGET="/mnt/target"
CONFIGFILE="_config.txt"
INFOFILE="_improved.txt"

# Hilfsvariable für die RAM Laufwerke
WPATH=""
WPATH_PRE=""
# Ramdisks für statische tmpfs Ramdisk Methode
RAMDISK0="/mnt/nscram0/"
RAMDISK1="/mnt/nscram1/"
# Variablen für die Horst-Methode
DEV_RAM_PATH="/dev/ram"
MNT_RAM_PATH="/mnt/ram"
REMOUNT_OPTION=""
# File-System Methode für den ramroot-Modus
FILESYSTEM_PATH="/root/nsc/tmp/"
DEFRAG=1

# Default-Werte für das Verfahren
RAM_METHOD="tmpfs"
NMAX_RAM=9
NMAX_PHYS=3
NMAX=$((NMAX_RAM + NMAX_PHYS))
RAM_SIZE=2G
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


###################################################################################################
#                   Definition von Funktionen für das Script
###################################################################################################

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

# Config-Infos ausgeben
print_basic_info()
{
    echo ""
    echo "Ermittelte Basis-Informationen"
    echo ""
    echo "Ramdisk-Methode ist auf $RAM_METHOD gesetzt."
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
    echo "Aktueller Stand der Bearbeitung (ca.-Angaben): "
    IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
    NEWLY_IMPROVED_FILES_SIZE=$((IMPROVED_FILES_SIZE - FORMER_IMPROVED_FILES_SIZE))
    PROGRESS=$((NEWLY_IMPROVED_FILES_SIZE *100 / TO_BE_IMPROVED_FILES_SIZE))
    echo "$PROGRESS % von 100 %"
}

print_kurzstatus()
{
    echo -n "Kurze Status-Info: "
    CURRENT_TIME=$(date +"%H:%M")
    echo $CURRENT_TIME
    echo -n "Album-Verzeichnis: "
    echo "$DIRNAME"
    echo -n "Musikdatei: "
    echo "$FILENAME"

    echo -n "Aktueller Stand der Bearbeitung (ca.-Angaben): "
    IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
    NEWLY_IMPROVED_FILES_SIZE=$((IMPROVED_FILES_SIZE - FORMER_IMPROVED_FILES_SIZE))
    PROGRESS=$((NEWLY_IMPROVED_FILES_SIZE *100 / TO_BE_IMPROVED_FILES_SIZE))
    echo "$PROGRESS % von 100 %"
    echo ""
}

# Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
analyse_frag_and_defrag(){
    echo "Analyse, ob Datei $1 fragmentiert ist"
    filefrag -v "$1"
    # Prüfen, ob die Variable DEFRAG gesetzt ist
    if [ -n "$DEFRAG" ] && [ "$DEFRAG" -eq 1 ]; then
        # Funktion Defragmentierungsprozedur
        echo "DEFRAG ist auf 1 gesetzt. Die Datei Quelldatei $1 wird defragmentiert"
        e4defrag "$1"
        echo "Wiederholung der Analyse, ob Datei $1 fragmentiert ist"
        filefrag -v "$1"
    else
        # Variable DEFRAG existiert nicht oder ist nicht auf 1 gesetzt
        echo "DEFRAG ist nicht auf 1 gesetzt oder existiert nicht. Die Quelldatei $1 wird nicht defragmentiert"
    fi
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

# Sicherstellen, dass der Mount-Point $MOUNT_PATH_TARGET ungemoutet udn wieder gemountet wird
ensure_umount_and_mount(){
    echo ""
    echo "Automatisches Unmounten und Mounten des Zieldatenträgers, um Schreiben auf den Datenträger zu erzwingen."
    echo "Einzelne mount oder umount Fehlermeldungen im folgenden sind unkritisch."
    echo "REMOUNT_OTION is set to $REMOUNT_OPTION"

    # Erster umount und anschließender mount-Versuch
    umount -v $MOUNT_PATH_TARGET
    local umount_exit_code=$?
    sleep $FSLEEP
    if [ $umount_exit_code -eq 0 ]; then
        echo "umount erfolgreich durchgeführt. Weiter mit mount-Versuch."
        mount -v $REMOUNT_OPTION $MOUNT_PATH_TARGET
        if [ $? -eq 0 ]; then
            echo "mount erfolgreich durchgeführt."
            return 0
        fi
    fi

    # while-Schleife mit mehreren Versuchen, falls umount und mount problemaisch
    M_ATTEMPT=1
    while true; do
        echo "Mount / Umount Schleifendurchlauf Nr. $M_ATTEMPT"

        mount -v $REMOUNT_OPTION $MOUNT_PATH_TARGET
        if [ $? -eq 0 ]; then
            echo "mount erfolgreich durchgeführt"
            break;
        else
            umount -v $MOUNT_PATH_TARGET
            if [ $? -eq 0 ]; then
                echo "umount erfolgreich durchgeführt, nach Kurzschlaf weiter in der while Schleife"
                sleep $FSLEEP
            else
                echo "umount nicht erfolgreich, nach Kurzschlaf neuer Versuch."
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
# Neue alternative Methode zur Behandlung des ram
create_ram(){
    N_LOC="$1"
    if [ "$RAM_METHOD" = "tmpfs" ]; then
        echo "create_ram mit Parameter $1 nach tmpfs Methode aufgerufen."
        WPATH_PRE="$WPATH"
        if [ "$((N_LOC % 2))" -eq 0 ]; then
            WPATH="$RAMDISK0"
        else
            WPATH="$RAMDISK1"
        fi
    elif [ "$RAM_METHOD" = "ext" ]; then
        echo "create_ram mit Parameter $1 nach ext Methode aufgerufen."
        mke2fs -t ext2 -O extents -vm0 "$DEV_RAM_PATH$N_LOC" $RAM_SIZE -b 1024
        sleep $UFSLEEP
        mkdir -v "$MNT_RAM_PATH$N_LOC"
        mount -v "$DEV_RAM_PATH$N_LOC" "$MNT_RAM_PATH$N_LOC"
        sleep $UFSLEEP
        chmod --verbose a+rwx "$MNT_RAM_PATH$N_LOC"
        WPATH_PRE="$WPATH"
        WPATH="$MNT_RAM_PATH$N_LOC$SLASH"
    else
        echo "create ram mit Parameter $1 nach Filesystem-Methode aufgerufen."
        mkdir -v "$FILESYSTEM_PATH$N_LOC"
        WPATH_PRE="$WPATH"
        WPATH="$FILESYSTEM_PATH$N_LOC$SLASH"
    fi
}

destroy_ram(){
    N_LOC="$1"
    if [ "$RAM_METHOD" = "tmpfs" ]; then
        echo "destroy_ram mit Parameter $1 nach tmpfs Methode aufgerufen."
        if [ "$((N_LOC % 2))" -eq 0 ]; then
            umount -v /mnt/nscram0/
            sleep $UFSLEEP
        else
            umount -v /mnt/nscram1/
            sleep $UFSLEEP
        fi
    elif [ "$RAM_METHOD" = "ext" ]; then
        echo "destroy_ram mit Parameter $1 nach ext Methode aufgerufen."
        umount -v "$DEV_RAM_PATH$N_LOC"
        sleep $UFSLEEP
        rmdir -v "$MNT_RAM_PATH$N_LOC"
        rm -v "$DEV_RAM_PATH$N_LOC"
    else
        echo "destroy_ram mit Parameter $1 nach Filesystem-Methode aufgerufen."
        rmdir -v "$FILESYSTEM_PATH$N_LOC"
    fi
}


# Aufräumarbeiten zum Script-Ende
nsc_cleanup()
{
# Umgang mit Ordner $TARGET_TMP_PATH
# Überprüfe, ob das Verzeichnis existiert
    if [ -d "$TARGET_TMP_PATH" ]; then
        # Das Verzeichnis existiert, lösche es mit seinem Inhalt
        rm -r "$TARGET_TMP_PATH"
        echo "Das Verzeichnis $TARGET_TMP_PATH und sein Inhalt wurden gelöscht."
    fi

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


###################################################################################################
#                   START DER EIGENTLICHEN ABARBEITUNG - VORBEREITUNGEN
###################################################################################################

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
echo "Einzelne mount und umount Fehlermeldungen im folgenden sind unkritisch."
echo ""

if [ $AUTO_MOUNT -eq 1 ]; then
    for drive in $(lsblk -o NAME,MOUNTPOINT -nr | awk '$2 == "" {print $1}'); do
        # Mounte das Laufwerk unter /mnt/nscX, wobei X die Laufwerksnummer ist
        mount_point="/mnt/nsc$drive_count"
        mkdir -p "$mount_point"

        # Mounte das Laufwerk
        mount -v -o rw "/dev/$drive" "$mount_point"

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
            DEV_PATH_TARGET="/dev/$drive"
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

# Extraktion der Mountpath-Variable aus TARGET_PATH
# Extrahiere den Mount-Point
MOUNT_PATH_TARGET=$(df -P "$TARGET_PATH" | awk 'NR==2 {print $6}')
echo "Der Mount-Point von $TARGET_PATH ist: $MOUNT_PATH_TARGET"


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

# Diese Berechnungen müssen nach dem Einlesen erfolgen.
FORMER_IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
TO_BE_IMPROVED_FILES_SIZE=$(du -s "$SOURCE_PATH" | awk '{print $1}')
NMAX=$((NMAX_RAM + NMAX_PHYS))
# Umgang mit den mount options
if [ $AUTO_MOUNT -eq 1 ]; then
     REMOUNT_OPTION="-o rw $DEV_PATH_TARGET"
fi

# Vorbereitung für das Ausgeben des laufenden Bearbeitungsstandes:
IMPROVED_FILES_SIZE=$(du -s "$TARGET_PATH" | awk '{print $1}')
TO_BE_IMPROVED_FILES_SIZE=$(du -s "$SOURCE_PATH" | awk '{print $1}')

# Starte das Script und zeige die Config-Info
print_basic_info

# Umgang mit Ordner $TARGET_TMP_PATH
# Überprüfe, ob das Verzeichnis existiert
if [ -d "$TARGET_TMP_PATH" ]; then
    # Das Verzeichnis existiert, lösche seinen Inhalt
    # Prüfe, ob Dateien im Verzeichnis vorhanden sind
    if [ "$(ls -A "$TARGET_TMP_PATH")" ]; then
        rm -v "$TARGET_TMP_PATH"*
        echo "Dateien im Verzeichnis $TARGET_TMP_PATH wurden alte tmp-Dateien gelöscht."
    else
        echo "Das Verzeichnis $TARGET_TMP_PATH ist erwartungsgemäß leer."
    fi
else
    # Das Verzeichnis existiert nicht, lege es an
    mkdir -p "$TARGET_TMP_PATH"
    echo "Das Verzeichnis $TARGET_TMP_PATH wurde erstellt."
fi

# Umgang mit möglichen Überbleibseln aus den Ramdisks bei statischer tpmfs Methode
# Überprüfe, ob das Verzeichnis $RAMDISK0 existiert
if [ -d "$RAMDISK0" ]; then
    # Prüfe, ob Dateien im Verzeichnis vorhanden sind
    if [ "$(ls -A "$RAMDISK0")" ]; then
        rm -v "$RAMDISK0"*
        echo "Dateien im Verzeichnis $RAMDISK0 wurden gelöscht."
    else
        echo "Das Verzeichnis $RAMDISK0 ist erwartungsgemäß leer."
    fi
else
    echo "Das Verzeichnis $RAMDISK0 existiert nicht. Unproblematisch bei den Methoden ext und filesystem."
fi

# Überprüfe, ob das Verzeichnis $RAMDISK1 existiert
if [ -d "$RAMDISK1" ]; then
    # Prüfe, ob Dateien im Verzeichnis vorhanden sind
    if [ "$(ls -A "$RAMDISK1")" ]; then
        rm -v "$RAMDISK1"*
        echo "Dateien im Verzeichnis $RAMDISK1 wurden gelöscht."
    else
        echo "Das Verzeichnis $RAMDISK1 ist erwartungsgemäß leer."
    fi
else
    echo "Das Verzeichnis $RAMDISK1 existiert nicht. Unproblematisch nur bei den Methoden ext und filesystem."
fi

# Überprüfe, ob das Verzeichnis $FILESYSTEM_PATH existiert
if [ -d "$FILESYSTEM_PATH" ]; then
    # Prüfe, ob Dateien im Verzeichnis vorhanden sind
    if [ "$(ls -A "$FILESYSTEM_PATH")" ]; then
        rm -rv "$FILESYSTEM_PATH"*
        echo "Dateien im Verzeichnis $FILESYSTEM_PATH wurden gelöscht."
    else
        echo "Das Verzeichnis $FILESYSTEM_PATH ist erwartungsgemäß leer."
    fi
else
    echo "Das Verzeichnis $FILESYSTEM_PATH existiert nicht. Unproblematisch bei den Methoden tmpfs und ext."
fi



# Pausieren
echo -n "Das Script pausiert jetzt "
echo -n $LSLEEP
echo -e " Sekunde(n). \n"
sleep $LSLEEP

###################################################################################################
#       START DER EIGENTLICHEN ABARBEITUNG - DURCHGANG DURCH DIE ALBUM-VERZEICHNISSE
###################################################################################################


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

            # set each file name to the 'FILENAME' variable
            FILENAME=$(basename "$FILE")
            # Analysiere die Dateiendung
            POSTFIX=$(echo "$FILENAME" | awk -F'.' '{print tolower($NF)}')
            # Den Fall abfangen, dass die zu improvende Datei "_improved.txt" heißt
            if [ "$FILENAME" = "_improved.txt" ]; then
                echo "Es wurde _improved.txt in den Quelldateien gefunden. Dieser Fall wird ignoriert."
                continue
            # Den Fall abfangen, dass es sich um eine Grafik- oder pdf-datei handelt
            elif [ "$POSTFIX" == "jpg" ] || [ "$POSTFIX" == "png" ] || [ "$POSTFIX" == "bmp" ] || [ "$POSTFIX" == "pdf" ]; then
                echo "Die Datei $FILENAME ist eine Grafik- oder pdf-datei, sie wird normal kopiert."
                cp -v "$SOURCE_PATH$DIRNAME$SLASH$FILENAME" "$TARGET_PATH$DIRNAME"
                continue
            else
                echo "Die Datei $FILENAME ist weder _improved.txt noch eine Grafikdatei"
            fi

            # Status ausgeben
            print_status
            echo""
            echo "Status: Bearbeitung des Album-Verzeichnisses: "
            echo "$DIRNAME"
            echo ""
            echo "Folgende Musikdatei wird gleich improvt: "
            echo "$FILENAME"

            # große for-Schleife mit 5 zu unterscheidenden Fällen
            for ((N=1; N<=NMAX; N++)); do

                # N = 1 von _source nach RAM
                if [ $N -eq 1 ]; then

                    echo ""
                    echo ""
                    echo "Erster improvefile-Durchlauf für diese Musikdatei (schnelles Verfahren; von _source ins RAM)"
                    echo ""
                    print_kurzstatus

                    # Ramdisk bereitstellen
                    create_ram $N

                    # Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
                    analyse_frag_and_defrag "$SOURCE_PATH$DIRNAME$SLASH$FILENAME"

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
                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (schnelles Verfahren; von RAM nach RAM)"
                    echo ""
                    print_kurzstatus

                    # Zähler und Ramdisk bereitstellen ($WPATH wird in create_ram belegt)
                    NPRE=$(($N - 1))
                    create_ram $N

                    # Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
#                    analyse_frag_and_defrag "$WPATH_PRE$TMP$NPRE"
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
                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (langsames Verfahren; von RAM nach phys-tmp)"
                    echo ""
                    print_kurzstatus

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"
                    WPATH="$TARGET_TMP_PATH"

                    # Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
#                    analyse_frag_and_defrag "$WPATH_PRE$TMP$NPRE"

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
                    echo ""
                    echo "Mehrfachanwendung von improvefile Nr. $N (langsames Verfahren; von phys-tmp nach phys-tmp)"
                    echo ""
                    print_kurzstatus

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"
                    WPATH="$TARGET_TMP_PATH"

                    # Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
#                    analyse_frag_and_defrag "$WPATH_PRE$TMP$NPRE"

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
                    ensure_umount_and_mount

                # N = NMAX von phys-tmp nach _improved
                else

                    echo ""
                    echo ""
                    echo "Letzter Durchlauf von improvefile für diese Musikdatei (Nr. $N, langsames Verfahren, von phys-tmp nach _IMPROVED)"
                    echo ""
                    print_kurzstatus

                    # Zähler und WPATH bereitstellen
                    NPRE=$(($N - 1))
                    WPATH_PRE="$WPATH"

                    # Fragmentierung der Quelldatei überprüfen und defragmentieren, wenn DEFRAG=1 gesetzt ist
#                    analyse_frag_and_defrag "$WPATH$TMP$NPRE"

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
                    ensure_umount_and_mount

                    echo "improvefile-Anwendung für diese Musikdatei  abgeschlossen"
                fi
            done
        done
    fi
done

# Aufräumarbeiten zum Script-Ende
nsc_cleanup
