Beispiel-Ordnerstruktur zur Anwendung des nsc Scriptpakets.

Die Beispielordner können direkt auf Datenträger kopiert werden. Dabei bitte beachten:
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



                  

