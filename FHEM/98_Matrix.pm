#!/usr/bin/perl -w

##########################################################################
# This file is part of the Matrix module for FHEM.
#
# Copyright (c) 2022 Man-fred
#
# You can find FHEM at www.fhem.de.
#
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This file is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with FHEM/Matrix. If not, see <http://www.gnu.org/licenses/>.
##########################################################################
# Usage:
#
##########################################################################
# $Id: 98_Matrix.pm 14063 2022-11-12 12:52:00Z Man-fred $

package FHEM::Matrix;
use strict;
use warnings;
use HttpUtils;
use FHEM::Meta;
use GPUtils qw(GP_Export);

use JSON;
require FHEM::Devices::Matrix::Matrix;

#-- Run before package compilation
BEGIN {

    #-- Export to main context with different name
    GP_Export(qw(
        Initialize
    ));
}

sub Initialize {
    my ($hash) = @_;
    
    $hash->{DefFn}      = \&FHEM::Devices::Matrix::Define;
    $hash->{UndefFn}    = \&FHEM::Devices::Matrix::Undef;
    $hash->{Delete}     = \&FHEM::Devices::Matrix::Delete;
    $hash->{SetFn}      = \&FHEM::Devices::Matrix::Set;
    $hash->{GetFn}      = \&FHEM::Devices::Matrix::Get;
    $hash->{AttrFn}     = \&FHEM::Devices::Matrix::Attr;
    $hash->{ReadFn}     = \&FHEM::Devices::Matrix::Read;
    $hash->{RenameFn}   = \&FHEM::Devices::Matrix::Rename;
    $hash->{NotifyFn}   = \&FHEM::Devices::Matrix::Notify;

    $hash->{AttrList}   = FHEM::Devices::Matrix::Attr_List();
    return FHEM::Meta::InitMod( __FILE__, $hash );
}


1;

=pod
=item summary Provides a Matrix-Chatbot.
=item summary_DE Stellt einen Matrix-Chatbot bereit.
=begin html

<a id="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> implements a client to Matrix-Synapse-Servers. It is in a very early development state. 
    <br><br>
    <a id="Matrix-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; &lt;server&gt; &lt;user&gt;</code>
        <br><br>
        Example: <code>define matrix Matrix matrix.com fhem</code>
        <br><br>
        noch ins Englische: 
        1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die R??ume vorbereitet. Achtung: alle R??ume m??ssen noch unverschl??sselt sein um FHEM anzubinden. Alle Einladungen in R??ume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken f??r das Modul.<br/>
        2. Anmerkung: sets, gets, Attribute und Readings m??ssen noch besser bezeichnet werden.
    </ul>
    <br>
    
    <a id="Matrix-set"></a>
    <h4>Set</h4>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. 
        <br><br>
        Options:
        <ul>
              <a id="Matrix-set-password"></a>
              <li><i>password</i><br>
                  Set the password to login
              </li>
              <a id="Matrix-set-register"></a>
              <li><i>register</i><br>
                  without function, do not use this
              </li>
              <a id="Matrix-set-login"></a>
              <li><i>login</i><br>
                  Login to the Matrix-Server and sync endless if poll is set to "1"
              </li>
              <a id="Matrix-set-refresh"></a>
              <li><i>refresh</i><br>
                  If logged in or in state "soft-logout" refresh gets a new access_token and syncs endless if poll is set to "1"
              </li>
              <a id="Matrix-set-filter"></a>
              <li><i>filter</i><br>
                  A Filter must be set for syncing in long poll. This filter is in the moment experimentell and must be set manual to get the coresponding filterId
              </li>
              <a id="Matrix-set-poll"></a>
              <li><i>poll</i><br>
                  Defaults to "0": Set poll to "1" for starting the sync-loop
              </li>
              <a id="Matrix-set-pollFullstate"></a>
              <li><i>pollFullstate</i><br>
                  Defaults to "0": Set pollFullstate to "1" for getting in the next sync a full state of all rooms
              </li>
              <a id="Matrix-set-question"></a>
              <li><i>question</i><br>
                  Start a question in the room from reading room. The first answer to the question is logged and ends the question.
              </li>
              <a id="Matrix-set-questionEnd"></a>
              <li><i>questionEnd</i><br>
                  Stop a question also it is not answered.
              </li>
        </ul>
    </ul>
    <br>

    <a id="Matrix-get"></a>
    <h4>Get</h4>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        
    </ul>
    <br>
    
    <a id="Matrix-attr"></a>
    <h4>Attributes</h4>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        
        <br><br>
        Attributes:
        <ul>
            <a id="Matrix-attr-matrixPoll"></a>
            <li><i>matrixPoll</i><br>
                1: Automatic login and endless sychonisation.
            </li>
            <a id="Matrix-attr-matrixMessage"></a>
            <li><i>matrixMessage</i> &lt;room-id&gt;<br>
                Set the room-id to wich  messagesare sent.
            </li>
            <a id="Matrix-attr-matrixAnswer_"></a>
            <li><i>matrixAnswer_</i><br>
                Prepared commands.
            </li>
            <a id="Matrix-attr-matrixAnswer__0-9__"></a>
            <li><i>matrixAnswer_[0-9]+</i><br>
                Prepared commands.
            </li>
            <a id="Matrix-attr-matrixQuestion_"></a>
            <li><i>matrixQuestion_</i> <br>
                Prepared questions.
            </li>
            <a id="Matrix-attr-matrixQuestion__0-9__"></a>
            <li><i>matrixQuestion_[0..9]+</i> &lt;question&gt;:&lt;answer 1&gt;:&lt;answer 2&gt;:...&lt;answer max. 20&gt;<br>
                Prepared questions.
            </li>
            <a id="Matrix-attr-matrixRoom"></a>
            <li><i>matrixRoom</i> &lt;room-id 1&gt; &lt;room-id 2&gt; ...<br>
                Set the room-id's from wich are messages received.
            </li>
            <a id="Matrix-attr-matrixSender"></a>
            <li><i>matrixSender</i> <code>&lt;user 1&gt; &lt;user 2&gt; ...</code><br>
                Set the user's from wich are messages received.<br><br>
                Example: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
    <a id="Matrix-readings"></a>
    <h4>Readings</h4>
    <ul>
      <li><b>deviceId</b> - Ger??te-ID unter der der MatrixBot registriert ist</li>
      <li><b>eventId</b> - ID der letzten Nachricht</li>
      <li><b>filterId</b> - ID des Filters, der Voraussetzung f??r eine Longpoll-Verbindung zum Server ist</li>
      <li><b>homeServer</b> - R??ckmeldung des Servers unter welchem Namen er erreichbar ist</li>
      <li><b>httpStatus</b> - Statuscode der letzten Serverantwort</li>
      <li><b>lastLogin</b> - Statuscode und Zeit des letzten Logins</li>
      <li><b>lastRefresh</b> - Statuscode und Zeit des letzten erhaltenen Accesstokens</li>
      <li><b>logintypes</b> - unterst??tzte Login-M??glichkeiten des Servers. Zur Zeit ist "password" die einzige unterst??tzte Version</li>
      <li><b>message</b> - letzte empfangene Nachricht</li>
      <li><b>poll</b> - 0: kein Empfang, 1: Empfang eingeschaltet</li>
      <li><b>questionId</b> - ID der letzten Frage</li>
      <li><b>requestError</b> - Letzte Serveranfrage mit Fehlerantwort</li>
      <li><b>sender</b> - Sender der letzten Nachricht</li>
      <li><b>since</b> - Schl??ssel vom Server bis zu welcher Nachricht der Empfang erfolgreich ist</li>
      <li><b>userId</b> - Antwort des Servers welcher Account eingeloggt ist</li>
    </ul>
</ul>

=end html
=begin html_DE

<a id="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> stellt einen Client f??r Matrix-Synapse-Server bereit. It is in a very early development state. 
    <br><br>
    <a id="Matrix-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; &lt;server&gt; &lt;user&gt;</code>
        <br><br>
        Beispiel: <code>define matrix Matrix matrix.com fhem</code>
        <br><br>
        1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die R??ume vorbereitet. Achtung: alle R??ume m??ssen noch unverschl??sselt sein um FHEM anzubinden. Alle Einladungen in R??ume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken f??r das Modul.<br/>
        2. Anmerkung: sets, gets, Attribute und Readings m??ssen noch besser bezeichnet werden.
    </ul>
    <br>
    
    <a id="Matrix-set"></a>
    <h4>Set</h4>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. 
        <br><br>
        Options:
        <ul>
              <a id="Matrix-set-password"></a>
              <li><i>password</i><br>
                  Setzt das Passwort zum Login
              </li>
              <a id="Matrix-set-register"></a>
              <li><i>register</i><br>
                  noch ohne Funktion!
              </li>
              <a id="Matrix-set-login"></a>
              <li><i>login</i><br>
                  Login beim Matrix-Server und horche andauernd auf Nachrichten wenn poll auf "1" gesetzt ist
              </li>
              <a id="Matrix-set-refresh"></a>
              <li><i>refresh</i><br>
                  Wenn eingeloggt oder im Zustand "soft-logout" erh??lt man mit refresh einen neuen access_token. Wenn poll auf "1" gesetzt ist l??uft dann wieder der Empfang andauernd.
              </li>
              <a id="Matrix-set-filter"></a>
              <li><i>filter</i><br>
                  Ein Filter muss gesetzt sein um "Longpoll"-Anfragen an den Server schicken zu k??nnen. Der Filter muss hier einmalg gesetzt werden um vom Server eine Filter-ID zu erhalten.
              </li>
              <a id="Matrix-set-poll"></a>
              <li><i>poll</i><br>
                  Zun??chst "0": Auf "1" startet die Empfangsschleife.
              </li>
              <a id="Matrix-set-pollFullstate"></a>
              <li><i>pollFullstate</i><br>
                  Standard ist "0": Wenn pollFullstate auf "1" gesetzt wird, werden beider n??chsten Synchronisation alle Raumeigenschaften neu eingelesen.
              </li>
              <a id="Matrix-set-question"></a>
              <li><i>question</i><br>
                  Frage in dem Raum des Attributs "MatrixMessage" stellen. Die erste Antwort steht im Reading "answer" und beendet die Frage.<br>
                  Als Wert wird entweder die Nummer einer vorbereiteten Frage ??bergeben oder eine komplette Frage in der Form<br>
                  <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
              </li>
              <a id="Matrix-set-questionEnd"></a>
              <li><i>questionEnd</i><br>
                  Die gestartete Frage ohne Antwort beenden. Entweder wird ohne Parameter die aktuelle Frage beendet oder mit einer Nachrichten-ID eine "verwaiste" Frage.
              </li>
        </ul>
    </ul>
    <br>

    <a id="Matrix-get"></a>
    <h4>Get</h4>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        
    </ul>
    <br>
    
    <a id="Matrix-attr"></a>
    <h4>Attributes</h4>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        
        <br><br>
        Attributes:
        <ul>
            <a id="Matrix-attr-matrixPoll"></a>
            <li><i>matrixPoll</i><br>
                1: Automatisches Login und dauerhafte Synchronisation. Ohne Attribut oder 0 stoppt die Synchronisation.
            </li>
            <a id="Matrix-attr-matrixMessage"></a>
            <li><i>matrixMessage</i> &lt;room-id&gt;<br>
                Setzt die Raum-ID in die alle Nachrichten gesendet werden. Zur Zeit ist nur ein Raum m??glich.
            </li>
            <a id="Matrix-attr-matrixAnswer_"></a>
            <li><i>matrixAnswer_</i><br>
                Antworten = Befehle ausf??hren ist noch nicht freigegeben
            </li>
            <a id="Matrix-attr-matrixAnswer__0-9__"></a>
            <li><i>matrixAnswer_[0-9]+</i><br>
                Antworten = Befehle ausf??hren ist noch nicht freigegeben
            </li>
            <a id="Matrix-attr-matrixQuestion_"></a>
            <li><i>matrixQuestion_</i> <br>
                Vorbereitete Fragen, die mit set mt question.start 0..9 gestartet werden k??nnen. Es sind maximal 20 Antworten m??glich.<br>
                Format der Fragen: <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
                Eingabe in der Attribut-Liste: <code>[0-9]+ Frage:Antwort 1:Antwort 2:....:Antwort n</code>
            </li>
            <a id="Matrix-attr-matrixQuestion__0-9__"></a>
            <li><i>matrixQuestion_[0-9]+</i><br>
                Vorbereitete Fragen, die mit set mt question.start 0..9 gestartet werden k??nnen. Es sind maximal 20 Antworten m??glich.<br>
                Format der Fragen: <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
                Eingabe in der Attribut-Liste: <code>[0-9]+ Frage:Antwort 1:Antwort 2:....:Antwort n</code>
            </li>
            <a id="Matrix-attr-matrixRoom"></a>
            <li><i>matrixRoom</i> &lt;room-id 1&gt; &lt;room-id 2&gt; ...<br>
                Alle Raum-ID's aus denen Nachrichten empfangen werden.
            </li>
            <a id="Matrix-attr-matrixSender"></a>
            <li><i>matrixSender</i> <code>&lt;user 1&gt; &lt;user 2&gt; ...</code><br>
                Alle Personen von denen Nachrichten empfangen werden.<br>
                Beispiel: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
    <a id="Matrix-readings"></a>
    <h4>Readings</h4>
    <ul>
      <li><b>deviceId</b> - Ger??te-ID unter der der MatrixBot registriert ist</li>
      <li><b>eventId</b> - ID der letzten Nachricht</li>
      <li><b>filterId</b> - ID des Filters, der Voraussetzung f??r eine Longpoll-Verbindung zum Server ist</li>
      <li><b>homeServer</b> - R??ckmeldung des Servers unter welchem Namen er erreichbar ist</li>
      <li><b>httpStatus</b> - Statuscode der letzten Serverantwort</li>
      <li><b>lastLogin</b> - Statuscode und Zeit des letzten Logins</li>
      <li><b>lastRefresh</b> - Statuscode und Zeit des letzten erhaltenen Accesstokens</li>
      <li><b>logintypes</b> - unterst??tzte Login-M??glichkeiten des Servers. Zur Zeit ist "password" die einzige unterst??tzte Version</li>
      <li><b>message</b> - letzte empfangene Nachricht</li>
      <li><b>poll</b> - 0: kein Empfang, 1: Empfang eingeschaltet</li>
      <li><b>questionId</b> - ID der letzten Frage</li>
      <li><b>requestError</b> - Letzte Serveranfrage mit Fehlerantwort</li>
      <li><b>sender</b> - Sender der letzten Nachricht</li>
      <li><b>since</b> - Schl??ssel vom Server bis zu welcher Nachricht der Empfang erfolgreich ist</li>
      <li><b>userId</b> - Antwort des Servers welcher Account eingeloggt ist</li>
    </ul>
</ul>

=end html_DE
=cut
