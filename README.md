# FHEM/70_Matrix.pm
## Vorwort
Ich habe seit gefühlten Ewigkeiten FHEM im Einsatz und jetzt neu auch Matrix, was bei mir Telegram als Meldungszentrale ablösen soll. Ich bin dabei einen Bot als FHEM-Modul aufzubauen der sowohl Meldungen absetzen kann als auch Befehle empfangen kann.

Das funktioniert mit Access-Token, Refresh-Token und sync auch schon ganz gut. Aktuelles Highlight ist Start und Beobachten einer Umfrage zur Reaktion auf Alarmmeldungen von FHEM.

Das Modul enthält allerdings noch viele Tests und Machbarkeitsstudien und ist noch nicht für "Endbenutzer" geeignet. Im Moment ist es eher für interessierte Developer und sehr Neugierige geeignet. Ich poste hier trotzdem schon mal, da ich noch sehr wenig zum Thema Matrix-Chat gefunden habe. Nicht das mehrere Entwicklungen parallel laufen.

## Zu meinem Ziel
Der FHEM-Matrix-Bot soll natürlich Meldungen in eine oder mehrere Gruppen posten können. Er soll aber auch ständig verbunden bleiben um Nachrichten und Befehle jederzeit empfangen zu können. Und da Befehle tippen im Chat zu umständlich ist experimentiere ich mit den Umfragen, bei deren Auswahl dann entsprechende Befehle empfangen werden. Auf Serverseite gibt es nur eine Einschränkung: Es müssen unverschlüsselte Gruppen zugelassen sein. Die Gruppe kann aber auf jedem beliebigen öffentlich vorhandenen oder einem eigenen Matrix-Server angelegt werden.

## Implementierung
Der Einfachheit empfehle ich folgendes Vorgehen wenn jemand schon testen will:
1. einen Matrix-Client für FHEM anlegen und den User registrieren Das geht unter Windows einfach mit dem installierten Matrix-Element-Client indem der Link kopiert wird und beim Aufruf ("Ziel") "--profile fhem" angehängt wird. Damit wird eine unabhängige Instanz erzeugt.
2. Einen unverschlüsselten privaten Raum anlegen und die Benutzer einladen, die Nachrichten erhalten sollen und Befehle absetzen können.
3. Die Raum-ID aus den Rauminformationen ablesen.
4. Modul aus Github in das FHEM-Verzeichnis kopieren und ein device anlegen:
  device matrix Matrix <server> <user> <passwort>
5. Mit "set matrix poll 1" kann eingestellt werden, dass das Modul nach dem Login in einer Endlosschleife läuft.
6. Jetzt sollte über "set matrix login" schon die Schleife starten zum horchen auf Nachrichten. Die Nachrichten erscheinen unter dem Reading "message" und passend dazu gibt es das Reading "sender" welches den Absender der aktuellen Nachricht enthält.

Nachrichten senden geht auch, da muss ich aber noch den Raum, an den gesendet wird, auf Attribute umstellen. Auch die Umfragen werden in Kürze so umgestellt, dass sie nicht nur für meinen Test funktionieren.

### Hinweise
Look for development guideof a FHEM Module at the FHEM wiki
https://wiki.fhem.de/wiki/DevelopmentModuleIntro

**Ab hier stehen noch die Inhalte des Templates um Inhalte vergleichen zu können und zu erkennen, was noch fehlt:**
# Files included in this template:

## Fhem module files and folders

### lib/

Put any libs(pure perl modules) you provide in a own package (not main) create in here