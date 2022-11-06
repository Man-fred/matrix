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
# $Id: 98_Matrix.pm 13172 2022-11-06 12:52:00Z Man-fred $

package FHEM::Devices::Matrix;
use strict;
use warnings;
use HttpUtils;
use FHEM::Meta;
use GPUtils qw(GP_Export GP_Import);

use JSON;
use vars qw(%data);
use FHEM::Core::Authentication::Passwords qw(:ALL);
require FHEM::Devices::Matrix::Matrix;

#-- Run before package compilation
BEGIN {

    #-- Export to main context with different name
    GP_Export(qw(
        Initialize
    ));
    GP_Import(qw(
		readingFnAttributes
	));
}

sub Initialize {
    my ($hash) = @_;
	
    $hash->{DefFn}      = \&FHEM::Devices::Matrix::Define;
    $hash->{UndefFn}    = \&FHEM::Devices::Matrix::Undef;
    $hash->{SetFn}      = \&FHEM::Devices::Matrix::Set;
    $hash->{GetFn}      = \&FHEM::Devices::Matrix::Get;
    $hash->{AttrFn}     = \&FHEM::Devices::Matrix::Attr;
    $hash->{ReadFn}     = \&FHEM::Devices::Matrix::Read;
    $hash->{RenameFn}   = \&FHEM::Devices::Matrix::Rename;
    $hash->{NotifyFn}   = \&FHEM::Devices::Matrix::Notify;

    #$hash->{AttrList}   = $FHEM::Devices::Matrix::attr_list;
    $hash->{AttrList}   = Attr_List();
    #$hash->{parseParams}    = 1;
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
        <code>define &lt;name&gt; <server> <user></code>
        <br><br>
        Example: <code>define matrix Matrix matrix.com fhem</code>
        <br><br>
        noch ins Englische: 
		1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die Räume vorbereitet. Achtung: alle Räume müssen noch unverschlüsselt sein um FHEM anzubinden. Alle Einladungen in Räume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken für das Modul.<br/>
		2. Anmerkung: sets, gets, Attribute und Readings müssen noch besser bezeichnet werden.
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
                  Set the password to login</li>
              <a id="Matrix-set-register"></a>
              <li><i>register</i><br>
                  without function, do not use this</li>
              <a id="Matrix-set-login"></a>
              <li><i>login</i><br>
                  Login to the Matrix-Server and sync endless if poll is set to "1"</li>
              <a id="Matrix-set-refresh"></a>
              <li><i>refresh</i><br>
                  If logged in or in state "soft-logout" refresh gets a new access_token and syncs endless if poll is set to "1"</li>
              <a id="Matrix-set-filter"></a>
              <li><i>filter</i><br>
                  A Filter must be set for syncing in long poll. This filter is in the moment experimentell and must be set manual to get the coresponding filter_id</li>
              <a id="Matrix-set-poll"></a>
              <li><i>poll</i><br>
                  Defaults to "0": Set poll to "1" for starting the sync-loop</li>
              <a id="Matrix-set-poll.fullstate"></a>
              <li><i>poll.fullstate</i><br>
                  Defaults to "0": Set poll.fullstate to "1" for getting in the next sync a full state of all rooms</li>
              <a id="Matrix-set-question.start"></a>
              <li><i>question.start</i><br>
                  Start a question in the room from reading room. The first answer to the question is logged and ends the question.</li>
              <a id="Matrix-set-question.end"></a>
              <li><i>question.end</i><br>
                  Stop a question also it is not answered.</li>
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
			<a id="Matrix-attr-MatrixMessage"></a>
            <li><i>MatrixMessage</i> &lt;room-id&gt;<br>
                Set the room-id to wich  messagesare sent.
            </li>
			<a id="Matrix-attr-MatrixQuestion_"></a>
            <li><i>MatrixQuestion_[0..9]+</i> &lt;question&gt;:&lt;answer 1&gt;:&lt;answer 2&gt;:...&lt;answer max. 20&gt;<br>
                Prepared questions.
            </li>
			<a id="Matrix-attr-MatrixQuestion__0-9__"></a>
            <li><i>MatrixQuestion_[0..9]+</i> &lt;question&gt;:&lt;answer 1&gt;:&lt;answer 2&gt;:...&lt;answer max. 20&gt;<br>
                Prepared questions.
            </li>
			<a id="Matrix-attr-MatrixAnswer_"></a>
            <li><i>MatrixAnswer_[0..9]</i><br>
                Prepared commands.
            </li>
			<a id="Matrix-attr-MatrixAnswer__0-9__"></a>
            <li><i>MatrixAnswer_[0..9]</i><br>
                Prepared commands.
            </li>
			<a id="Matrix-attr-MatrixRoom"></a>
            <li><i>MatrixRoom</i> &lt;room-id 1&gt; &lt;room-id 2&gt; ...<br>
                Set the room-id's from wich are messages received.
            </li>
			<a id="Matrix-attr-MatrixSender"></a>
            <li><i>MatrixSender</i> <code>&lt;user 1&gt; &lt;user 2&gt; ...</code><br>
                Set the user's from wich are messages received.<br><br>
				Example: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
    <a id="Matrix-readings"></a>
    <h4>Readings</h4>
</ul>
=end html
=begin html_DE
<a id="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> stellt einen Client für Matrix-Synapse-Server bereit. It is in a very early development state. 
    <br><br>
    <a id="Matrix-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; &lt;server&gt; &lt;user&gt;</code>
        <br><br>
        Beispiel: <code>define matrix Matrix matrix.com fhem</code>
        <br><br>
        1. Anmerkung: Zur einfachen Einrichtung habe ich einen Matrix-Element-Client mit "--profile=fhem" gestartet und dort die Registrierung und die Räume vorbereitet. Achtung: alle Räume müssen noch unverschlüsselt sein um FHEM anzubinden. Alle Einladungen in Räume und Annehmen von Einladungen geht hier viel einfacher. Aus dem Element-Client dann die Raum-IDs merken für das Modul.<br/>
		2. Anmerkung: sets, gets, Attribute und Readings müssen noch besser bezeichnet werden.
    </ul>
    <br>
    
    <a name="Matrix-set"></a>
    <h4>Set</h4>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;wert&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. 
        <br><br>
        Options:
        <ul>
              <a id="Matrix-set-password"></a>
			  <li><i>password</i><br>
                  Setzt das Passwort zum Login</li>
              <a id="Matrix-set-register"></a>
              <li><i>register</i><br>
                  noch ohne Funktion!</li>
              <a id="Matrix-set-login"></a>
              <li><i>login</i><br>
                  Login beim Matrix-Server und horche andauernd auf Nachrichten wenn poll auf "1" gesetzt ist</li>
              <a id="Matrix-set-refresh"></a>
              <li><i>refresh</i><br>
                  Wenn eingeloggt oder im Zustand "soft-logout" erhält man mit refresh einen neuen access_token. Wenn poll auf "1" gesetzt ist läuft dann wieder der Empfang andauernd.</li>
              <a id="Matrix-set-filter"></a>
              <li><i>filter</i><br>
                  Ein Filter muss gesetzt sein um "Longpoll"-Anfragen an den Server schicken zu können. Der Filter muss hier einmalg gesetzt werden um vom Server eine Filter-ID zu erhalten.</li>
              <a id="Matrix-set-poll"></a>
              <li><i>poll</i><br>
                  Zunächst "0": Auf "1" startet die Empfangsschleife.</li>
              <a id="Matrix-set-poll.fullstate"></a>
              <li><i>poll.fullstate</i><br>
                  Standard ist "0": Wenn poll.fullstate auf "1" gesetzt wird, werden beider nächsten Synchronisation alle Raumeigenschaften neu eingelesen.</li>
              <a id="Matrix-set-question.start"></a>
              <li><i>question.start</i><br>
                  Frage in dem Raum des Attributs "MatrixMessage" stellen. Die erste Antwort steht im Reading "answer" und beendet die Frage.<br>
				  Als Wert wird entweder die Nummer einer vorbereiteten Frage übergeben oder eine komplette Frage in der Form<br>
				  <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code></li>
              <a id="Matrix-set-question.end"></a>
              <li><i>question.end</i><br>
                  Die gestartete Frage ohne Antwort beenden. Entweder wird ohne Parameter die aktuelle Frage beendet oder mit einer Nachrichten-ID eine "verwaiste" Frage.</li>
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
			<a id="Matrix-attr-MatrixMessage"></a>
            <li><i>MatrixMessage</i> &lt;room-id&gt;<br>
                Setzt die Raum-ID in die alle Nachrichten gesendet werden. Zur Zeit ist nur ein Raum möglich.
            </li>
			<a id="Matrix-attr-MatrixAnswer_"></a>
            <li><i>MatrixAnswer_</i><br>
                Antworten = Befehle ausführen ist noch nicht freigegeben</code>
            </li>
			<a id="Matrix-attr-MatrixAnswer__0-9__"></a>
            <li><i>MatrixAnswer_[0-9]+</i><br>
                Antworten = Befehle ausführen ist noch nicht freigegeben</code>
            </li>
			<a id="Matrix-attr-MatrixQuestion_"></a>
            <li><i>MatrixQuestion_</i> <br>
                Vorbereitete Fragen, die mit set mt question.start 0..9 gestartet werden können. Es sind maximal 20 Antworten möglich.<br>
				Format der Fragen: <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
				Eingabe in der Attribut-Liste: <code>[0-9]+ Frage:Antwort 1:Antwort 2:....:Antwort n</code>
            </li>
			<a id="Matrix-attr-MatrixQuestion__0-9__"></a>
            <li><i>MatrixQuestion_[0-9]+</i><br>
                Vorbereitete Fragen, die mit set mt question.start 0..9 gestartet werden können. Es sind maximal 20 Antworten möglich.<br>
				Format der Fragen: <code>Frage:Antwort 1:Antwort 2:....:Antwort n</code>
				Eingabe in der Attribut-Liste: <code>[0-9]+ Frage:Antwort 1:Antwort 2:....:Antwort n</code>
            </li>
			<a id="Matrix-attr-MatrixRoom"></a>
            <li><i>MatrixRoom</i> &lt;room-id 1&gt; &lt;room-id 2&gt; ...<br>
                Alle Raum-ID's aus denen Nachrichten empfangen werden.
            </li>
			<a id="Matrix-attr-MatrixSender"></a>
            <li><i>MatrixSender</i> <code>&lt;user 1&gt; &lt;user 2&gt; ...</code><br>
                Alle Personen von denen Nachrichten empfangen werden.<br>
				Beispiel: <code>attr matrix MatrixSender @name:matrix.server @second.name:matrix.server</code><br>
            </li>
        </ul>
    </ul>
    <a id="Matrix-readings"></a>
    <h4>Readings</h4>
</ul>
=end html_DE
=cut
