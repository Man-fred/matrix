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
# $Id: 98_Matrix.pm 28158 2022-11-02 19:56:00Z Man-fred $

package FHEM::Matrix;
use strict;
use warnings;
use HttpUtils;
use FHEM::Meta;
use GPUtils qw(GP_Export);

require FHEM::Device::Matrix;

#-- Run before package compilation
BEGIN {

    #-- Export to main context with different name
    GP_Export(
        qw(
            Initialize
          )
    );
}

sub Matrix_Initialize {
    my ($hash) = @_;
	
    $hash->{DefFn}      = \&FHEM::Device::Matrix::Define;
    $hash->{UndefFn}    = \&FHEM::Device::Matrix::Undef;
    $hash->{SetFn}      = \&FHEM::Device::Matrix::Set;
    $hash->{GetFn}      = \&FHEM::Device::Matrix::Get;
    $hash->{AttrFn}     = \&FHEM::Device::Matrix::Attr;
    $hash->{ReadFn}     = \&FHEM::Device::Matrix::Read;
    $hash->{RenameFn}   = \&FHEM::Device::Matrix::Rename;
    $hash->{NotifyFn}   = \&FHEM::Device::Matrix::Notify;

    $hash->{AttrList} = "MatrixRoom MatrixSender MatrixQuestion_0 MatrixQuestion_1  MatrixMessage " . $::readingFnAttributes;

    $hash->{parseParams}    = 1;

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

1;

=pod
=item summary Provides a Matrix-Chatbot.
=item summary_DE Stellt einen Matrix-Chatbot bereit.
=begin html
<a name="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> implements a client to Matrix-Synapse-Servers. It is in a very early development state. 
    <br><br>
    <a name="Matrixdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; <server> <user> <password></code>
        <br><br>
        Example: <code>define matrix Matrix matrix.com fhem asdf</code>
        <br><br>
        noch ins Englische: 
		1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die Räume vorbereitet. Achtung: alle Räume müssen noch unverschlüsselt sein um FHEM anzubinden. Alle Einladungen in Räume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken für das Modul.<br/>
		2. Anmerkung: sets, gets, Attribute und Readings müssen noch besser bezeichnet werden.
    </ul>
    <br>
    
    <a name="Matrixset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. 
        <br><br>
        Options:
        <ul>
              <li><i>register</i><br>
                  without function, do not use this</li>
              <li><i>login</i><br>
                  Login to the Matrix-Server and sync endless if poll is set to "1"</li>
              <li><i>refresh</i><br>
                  If logged in or in state "soft-logout" refresh gets a new access_token and syncs endless if poll is set to "1"</li>
              <li><i>filter</i><br>
                  A Filter must be set for syncing in long poll. This filter is in the moment experimentell and must be set manual to get the coresponding filter_id</li>
              <li><i>poll</i><br>
                  Defaults to "0": Set poll to "1" for starting the sync-loop</li>
              <li><i>poll.fullstate</i><br>
                  Defaults to "0": Set poll.fullstate to "1" for getting in the next sync a full state of all rooms</li>
              <li><i>question.start</i><br>
                  Start a question in the room from reading room. The first answer to the question is logged and ends the question.</li>
              <li><i>question.end</i><br>
                  Stop a question also it is not answered.</li>
        </ul>
    </ul>
    <br>

    <a name="Matrixget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        
    </ul>
    <br>
    
    <a name="Matrixattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        
        <br><br>
        Attributes:
        <ul>
            <li><i>MatrixMessage</i> <room-id><br>
                Set the room-id to wich  messagesare sent.
            </li>
            <li><i>MatrixQuestion_[0..9]</i> <room-id><br>
                Prepared questions.
            </li>
            <li><i>MatrixRoom</i> <room-id 1> <room-id 2> ...<br>
                Set the room-id's from wich are messages received.
            </li>
            <li><i>MatrixSender</i> <code><user 1> <user 2> ...</code><br>
                Set the user's from wich are messages received.<br><br>
				Example: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
</ul>
=end html
=begin html_DE
<a name="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> stellt einen Client für Matrix-Synapse-Server bereit. It is in a very early development state. 
    <br><br>
    <a name="Matrixdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; <server> <user> <passwort></code>
        <br><br>
        Beispiel: <code>define matrix Matrix matrix.com fhem asdf</code>
        <br><br>
        1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die Räume vorbereitet. Achtung: alle Räume müssen noch unverschlüsselt sein um FHEM anzubinden. Alle Einladungen in Räume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken für das Modul.<br/>
		2. Anmerkung: sets, gets, Attribute und Readings müssen noch besser bezeichnet werden.
    </ul>
    <br>
    
    <a name="Matrixset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;wert&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. 
        <br><br>
        Options:
        <ul>
              <li><i>register</i><br>
                  noch ohne Funktion!</li>
              <li><i>login</i><br>
                  Login beim Matrix-Server und horche andauernd auf Nachrichten wenn poll auf "1" gesetzt ist</li>
              <li><i>refresh</i><br>
                  Wenn eingeloggt oder im Zustand "soft-logout" erhält man mit refresh einen neuen access_token. Wenn poll auf "1" gesetzt ist läuft dann wieder der Empfang andauernd.</li>
              <li><i>filter</i><br>
                  Ein Filter muss gesetzt sein um "Longpoll"-Anfragen an den Server schicken zu können. Der Filter muss hier einmalg gesetzt werden um vom Server eine Filter-ID zu erhalten.</li>
              <li><i>poll</i><br>
                  Zunächst "0": Auf "1" startet die Empfangsschleife.</li>
              <li><i>poll.fullstate</i><br>
                  Standard ist "0": Wenn poll.fullstate auf "1" gesetzt wird, werden beider nächsten Synchronisation alle Raumeigenschaften neu eingelesen.</li>
              <li><i>question.start</i><br>
                  Frage in dem Raum des Attributs "MatrixMessage" stellen. Die erste Antwort steht im Reading "answer" und beendet die Frage.<br>
				  Als Wert wird entweder die Nummer einer vorbereiteten Frage übergeben oder eine komplette Frage in der Form<br>
				  <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code></li>
              <li><i>question.end</i><br>
                  Die gestartete Frage ohne Antwort beenden. Entweder wird ohne Parameter die aktuelle Frage beendet oder mit einer Nachrichten-ID eine "verwaiste" Frage.</li>
        </ul>
    </ul>
    <br>

    <a name="Matrixget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        
    </ul>
    <br>
    
    <a name="Matrixattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        
        <br><br>
        Attributes:
        <ul>
            <li><i>MatrixMessage</i> <room-id><br>
                Setzt die Raum-ID in die alle Nachrichten gesendet werden. Zur Zeit ist nur ein Raum möglich.
            </li>
            <li><i>MatrixQuestion_[0..9].</i> <room-id><br>
                Vorbereitete Fragen, die mit set mt question.start 0..9 gestartet werden können.<br>
				Format der Fragen: <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
            </li>
            <li><i>MatrixRoom</i> <room-id 1> <room-id 2> ...<br>
                Alle Raum-ID's aus denen Nachrichten empfangen werden.
            </li>
            <li><i>MatrixSender</i> <code><user 1> <user 2> ...</code><br>
                Alle Personen von denen Nachrichten empfangen werden.<br>
				Beispiel: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
</ul>
=end html_DE
=cut
