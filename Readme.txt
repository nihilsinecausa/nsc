Dieses nsc Script-Paket dient zur Unterstützung von improvefile auf einem Linux-Rechner
Es basiert auf frankl's stereo utilities. Es gilt die GNU License (cf License.txt)

Autor: Dr. Harald Scherer (nihil.sine.causa im Forum aktives-hoeren.de)


    VORAUSSETZUNGEN

- Linux System (z.B. DietPi, Arch), GUI dabei nicht erforderlich
- Die Software von frankl muss installiert sein, damit die Scripte später laufen.
  https://github.com/frankl-audio/frankl_stereo.git
- Das Script Paket muss installiert sein (vgl. Install.txt)


    VORBEREITUNGEN (GGF. AUF WINDOWS-EBENE)

- Es können ein oder zwei Datenträger verwendet werden. Das Scriptset prüft im Auto-Mount
  Modus (default) nach, welche Datenträger angeschlossen sind, mountet sie automatisch
  und überprüft dabei, ob die Ordner mit den hier verwendeten Namen vorhanden sind.
  Werden die Namen nicht gefunden, dann läuft das Scriptset auf Fehler und endet.

- Die Verzeichnisse "_A_SOURCE" und "_B_ETC" sollten sich auf einem Datenträger befinden.
  Das Verzeichnis "_IMPROVED" kann sich auf demselben Datenträger befinden,
  aber auch auf einm anderen.

Anwendung der Verzeichnisse

- "_A_SOURCE" --> Hier die Dateien ablegen, die improvt werden sollen.
                  Nach einem erfolgreichen Script-Durchlauf müssen diese Dateien manuell
                  verschoben oder gelöscht werden. (Das Scriptset nimmt sicherheitshalber
                  nur Löschung von Dateien vor, die es selbst angelegt hat.)

- "_B_ETC"    --> Hier die Dateien _config.txt und improved.txt ablegen. Beides optional.
                  _config.txt: Parameterwerte für die improvefile-Aufrufe.
                               optional heißt hier: wenn die Datei vorhanden ist, wird sie
                               berücksichtigt, falls nicht, werden Standardwerte verwendet.
                  _improved.txt: Infodatei, die in jeden improvten Albumordner kopiert wird.
                                 optional heißt hier: wenn die Datei fehlt, wird nichts kopiert.

- "_IMPROVED" --> In diesen Ordner werden die improvten Albumverzeichnisse abgelegt.


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

Example: Ein Beispiel für die Ordnerstruktur findet sich im Verzeichnis "example_Ordnerstruktur".
Dieser kleine Verzeichnisbaun kann bei Bedarf direkt auf den betreffenden Datenträger kopiert werden.

Hinweis: Auf dem Zieldatenträger muss bei der Bearbeitung noch mindestens soviel freier Speicherplatz
übrig bleiben, der dem Speicherbedarf der größten Musikdatei entspricht. 


    ANWENDUNG des nsc-Script-Pakets

Alle Aufrufe als root 

    "nsc.sh"

Damit startet das Hauptscript "nsc_main.sh" im Hintergrund und die Bearbeitung läuft automatisch ab.

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

