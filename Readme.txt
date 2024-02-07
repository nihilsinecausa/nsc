Dieses nsc Script-Paket dient zur Unterstützung von improvefile auf einem Linux-Rechner
Es basiert auf frankl's stereo utilities. Es gilt die GNU License (cf License.txt)

Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)


    VORAUSSETZUNGEN

- Linux System (z.B. DietPi, Arch), GUI dabei nicht erforderlich
- Die Software von frankl muss installiert sein, damit die Scripte später laufen.
  https://github.com/frankl-audio/frankl_stereo.git
- Das Script Paket muss installiert sein (vgl. Install.txt)


    VORBEREITUNGEN (GGF. AUF WINDOWS-EBENE)

- Ein oder zwei externe Datenträger sind mit dem Linux-Rechner physisch verbunden (z.B. über USB)
- Auf diesem(n) Datenträger(n) befinden sich folgende Verzeichnisse:
      "_source" --> Quelle für die zu improvenden Dateien
      "_etc"    --> Quelle für die Steuerdatei _nsc_config.txt sowie die für Infodatei _nsc_improved.txt
      "_improved" --> Ziel für die improvten Dateien
- Dabei können "_source" und "_improved" auf unterschiedlichen Datenträgern liegen.
      "_etc" aber muss auf demselben Datenträger liegen wie "_source". )
- Der Ordner "_etc" kann eine Datei "_config.txt" enthalten. 
  Sofern diese vorhanden ist, werden Parameter für die improvefile-Verarbeitung daraus gelesen
  Ein Beispile für eine solche Datei liegt in diesem Linux Projekt im Ordner utils
- Der Ordner "_etc" kann eine Datei "_improved.txt" enthalten. In dieser Datei lassen sich die Datum und
  Umstände der jweiligen improve-Sessions dokumentieren.


    ANWENDUNG des nsc-Script Pakets

Alle Aufrufe als root 

    "nsc.sh"

Damit startet das Hauptscript "nsc_main.sh" im Hintergrund und die Bearbeitung läuft automatisch ab.

Alternativ kann man dynamisch generierte mit ext formatierte Ramdisks verwenden. Der Aufruf lautet dann

    "nsc.sh ext"

Um einen Überblick über die Bearbeitung zu bekommen, kann man mit dem Aufruf

    "info.sh"

Einblick in die laufende Logdatei bekommen. Optional kann eine Zeilenzahl mit angegeben werden.
Beispiel:

    "info.sh 70"

gibt die 70 letzten Zeilen der laufenden Logdatei aus. 

Auf diese Weise kann man immer wieder nachsehen, wie weit die Bearbeitung vorangeschritten ist.

Am Ende der Bearbeitung steht in der laufenden Logdatei:

############################################################################################
#                                 nsc_main.sh SCRIPT ENDE                                  #
############################################################################################

Dann kann man den Linux-Rechner ausschalten mit

   poweroff

und die improvten Musikdateien genießen.

Happy listening!

