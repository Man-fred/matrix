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
# $Id: 98_Matrix.pm 24969 2022-10-31 09:44:00Z Man-fred $

package main;
use strict;
use warnings;
use HttpUtils;
use vars qw(%data);

my $Module_Version = '0.0.5 - 31.10.2022';

my $AttrList = "MatrixRoom MatrixSender MatrixMessage " . $readingFnAttributes;

sub Matrix_PerformHttpRequest($$$)
{
    my ($hash, $def, $value) = @_;
	my $now  = gettimeofday();
    my $name = $hash->{NAME};
    my $param = {
                    timeout    => 10,
                    hash       => $hash,                                      # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
					def        => $def,
                    method     => "POST",                                     # standard, sonst überschreiben
                    header     => "User-Agent: HttpUtils/2.2.3\r\nAccept: application/json",  # Den Header gemäß abzufragender Daten setzen
                    callback   => \&Matrix_ParseHttpResponse                  # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} + 1;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{'LASTSEND'} = $now;                                # remember when last sent
	my $device_id = ReadingsVal($name, 'device_id', undef) ? ', "device_id":"'.ReadingsVal($name, 'device_id', undef).'"' : "";
	if ($def eq "register"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$hash->{password}.'"}';
	}
	if ($def eq"reg2"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"username":"'.$hash->{user}.'", "password":"'.$hash->{password}.'", "auth": {"session":"'.$data{MATRIX}{"$name"}{"session"}.'","type":"m.login.dummy"}}';
	}
	if ($def eq "login"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/login";
      $param->{'data'} = '{"type":"m.login.password", "refresh_token": true, "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$hash->{password}.'"'
	                     .$device_id.'}';
	}
	if ($def eq "refresh"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v1/refresh'; 
      $param->{'data'} = '{"refresh_token": "'.$data{MATRIX}{"$name"}{"refresh_token"}.'"}';
	}
	if ($def eq "wellknown"){
      $param->{'url'} =  $hash->{server}."/.well-known/matrix/client";
 	}
	if ($def eq "msg"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/r0/rooms/'.AttrVal($name, 'MatrixMessageRoom', '!!').'/send/m.room.message?access_token='.$data{MATRIX}{"$name"}{"access_token"};
      $param->{'data'} = '{"msgtype":"m.text", "body":"'.$value.'"}';
	}
	if ($def eq "pollstart"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'MatrixMessageRoom', '!!').'/send/m.poll.start?access_token='.$data{MATRIX}{"$name"}{"access_token"};
      $param->{'data'} = '{"org.matrix.msc3381.poll.start": {"max_selections": 1,'.
      '"question": {"org.matrix.msc1767.text": "[Kategorie] Frage"},'.
	  '"kind": "org.matrix.msc3381.poll.undisclosed",'.
	  '"answers": [{"id": "Antwort1", "org.matrix.msc1767.text": "Antwort1"},{"id":"Antwort2","org.matrix.msc1767.text": "Antwort2"}],'.
	  '"org.matrix.msc1767.text": "[Kategorie] Frage\nAntwort1\nAntwort2"}}';
	}
	if ($def eq "pollend"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'MatrixMessageRoom', '!!').'/send/m.poll.end?access_token='.$data{MATRIX}{"$name"}{"access_token"};
	  # ""'.ReadingsVal($name, 'questionEventId', '!!').'
      $param->{'data'} = '{"m.relates_to": {"rel_type": "m.reference","event_id": "$8v_5pJZY9Ql_x93TfoHmqSBTiY6IYNdRpqiJuhMylxo"},"org.matrix.msc3381.poll.end": {},'.
                '"org.matrix.msc1767.text": "Antort '.ReadingsVal($name, "answer", "").' erhalten von '.ReadingsVal($name, "sender", "").'"}';
	}
	if ($def eq "sync"){  
		my $since = ReadingsVal($name, "since", undef) ? '&since='.ReadingsVal($name, "since", undef) : "";
		my $full_state = ReadingsVal($name, "poll.fullstate",undef);
		if ($full_state){
		    $full_state = "&full_state=true";
			readingsSingleUpdate($hash, "poll.fullstate", 0, 1);
		} else {
			$full_state = "";
		}
		$param->{'url'} =  $hash->{server}.'/_matrix/client/r0/sync?access_token='.$data{MATRIX}{"$name"}{"access_token"}.$since.$full_state.'&timeout=50000&filter='.ReadingsVal($name, 'filter_id',0);
		$param->{'method'} = 'GET';
		$param->{'timeout'} = 60;
	}
	if ($def eq "filter"){
      if ($value){ # get
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.ReadingsVal($name, "user_id",0).'/filter/'.$value.'?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'method'} = 'GET';
	  } else {	  
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.ReadingsVal($name, "user_id",0).'/filter?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'data'} = '{';
		  $param->{'data'} .= '"event_fields": ["type","content","sender"],';
		  $param->{'data'} .= '"event_format": "client", ';
		  $param->{'data'} .= '"presence": { "senders": [ "@xx:example.com"]}'; # no presence
		  #$param->{'data'} .= '"room": { "ephemeral": {"rooms": ["'.AttrVal($name, 'MatrixRoom', '!!').'"],"types": ["m.receipt"]}, "state": {"types": ["m.room.*"]},"timeline": {"types": ["m.room.message"] } }';
		  $param->{'data'} .= '}';
	  }
	}

    my $test = "$param->{url}, "
        . ( $param->{data}   ? "\r\ndata: $param->{data}, "   : "" )
        . ( $param->{header} ? "\r\nheader: $param->{header}" : "" );
	readingsSingleUpdate($hash, "fullRequest", $test, 1);                                                        # Readings erzeugen
	$test = "$name: Matrix sends with timeout $param->{timeout} to ".$test;
    Log3 $name, 5, $test;
          
    HttpUtils_NonblockingGet($param);   #  Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
	return undef; 
}

sub Matrix_ParseHttpResponse($)
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
	my $def = $param->{def};
    my $name = $hash->{NAME};
	my $now  = gettimeofday();
	my $nextRequest = "";

    readingsBeginUpdate($hash);
	###readingsBulkUpdate($hash, "httpHeader", $param->{httpheader});
	readingsBulkUpdate($hash, "httpStatus", $param->{code});
	$hash->{STATE} = $def.' - '.$param->{code};
    if($err ne "") {                                                         # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        Log3 $name, 3, "error while requesting ".$param->{url}." - $err";    # Eintrag fürs Log
        readingsBulkUpdate($hash, "fullResponse", "ERROR ".$err);            # Readings erzeugen
		$data{MATRIX}{"$name"}{"FAILS"} = 3;
    }
    elsif($data ne "") {                                                     # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
		Log3 $name, 3, $def." returned: $data";              # Eintrag fürs Log
		my $decoded = eval { decode_json($data) };
		Log3 $name, 2, "$name: json error: $@ in data" if( $@ );
        if ($param->{code} == 200){
			$data{MATRIX}{"$name"}{"FAILS"} = 0;
		} else {
			$data{MATRIX}{"$name"}{"FAILS"}++;
		}
		
		# default next request
		$nextRequest = "sync" ;
        # An dieser Stelle die Antwort parsen / verarbeiten mit $data
		
		# "errcode":"M_UNKNOWN_TOKEN: login or refresh
		my $errcode = $decoded->{'errcode'} ? $decoded->{'errcode'} : "";
		if ($decoded->{'errcode'} eq "M_UNKNOWN_TOKEN"){
			if ($decoded->{'error'} eq "Access token has expired"){
				if ($decoded->{'soft_logout'} eq "true"){
					$nextRequest = 'refresh';
				}else{
					$nextRequest = 'login';
				}
			} elsif ($decoded->{'error'} eq "refresh token does not exist"){
				$nextRequest = 'login';
			}
		}
        
        readingsBulkUpdate($hash, "fullResponse", $data); 
        if ($def eq "register"){
			$data{MATRIX}{"$name"}{"session"} = $decoded->{'session'};
			$nextRequest = "reg2";
		}
        if ($param->{code} == 200 && ($def eq  "reg2" || $def eq  "login" || $def eq "refresh")){
			readingsBulkUpdate($hash, "user_id", $decoded->{'user_id'}) if ($decoded->{'user_id'});
			readingsBulkUpdate($hash, "home_server", $decoded->{'home_server'}) if ($decoded->{'home_server'});
			readingsBulkUpdate($hash, "device_id", $decoded->{'device_id'}) if ($decoded->{'device_id'});
		  	readingsBulkUpdate($hash, "last_register", $param->{code}) if $def eq  "reg2";
		  	readingsBulkUpdate($hash, "last_login",  $param->{code}) if $def eq  "login";
		  	readingsBulkUpdate($hash, "last_refresh", $param->{code}) if $def eq  "refresh";
			
			$data{MATRIX}{"$name"}{"expires"} = $decoded->{'expires_in_ms'} if ($decoded->{'expires_in_ms'});
			$data{MATRIX}{"$name"}{"refresh_token"} = $decoded->{'refresh_token'} if ($decoded->{'refresh_token'}); 
			$data{MATRIX}{"$name"}{"access_token"} =  $decoded->{'access_token'} if ($decoded->{'access_token'});
		}
        if ($def eq "wellknown"){
			# https://spec.matrix.org/unstable/client-server-api/
		}
        if ($param->{code} == 200 && $def eq "sync"){
			readingsBulkUpdate($hash, "since", $decoded->{'next_batch'}) if ($decoded->{'next_batch'});
			# roomlist
			my $list = $decoded->{'rooms'}->{'join'};
			#my @roomlist = ();
			my $pos = 0;
			foreach my $id ( keys $list->%* ) {
				if (ref $list->{$id} eq ref {}) {
					my $member = "";
					#my $room = $list->{$id};
					$pos = $pos + 1;
					# MatrixRoom ?
					readingsBulkUpdate($hash, "room$pos.id", $id); 
					#foreach my $id ( $decoded->{'rooms'}->{'join'}->{AttrVal($name, 'MatrixRoom', '!!')}->{'timeline'}->{'events'}->@* ) {
					foreach my $ev ( $list->{$id}->{'state'}->{'events'}->@* ) {
						readingsBulkUpdate($hash, "room$pos.topic", $ev->{'content'}->{'topic'}) if ($ev->{'type'} eq 'm.room.topic'); 
						readingsBulkUpdate($hash, "room$pos.name", $ev->{'content'}->{'name'}) if ($ev->{'type'} eq 'm.room.name'); 
						$member .= "$ev->{'sender'} " if ($ev->{'type'} eq 'm.room.member'); 
					}
					readingsBulkUpdate($hash, "room$pos.member", $member); 
					foreach my $tl ( $list->{$id}->{'timeline'}->{'events'}->@* ) {
						readingsBulkUpdate($hash, "room$pos.topic", $tl->{'content'}->{'topic'}) if ($tl->{'type'} eq 'm.room.topic'); 
						readingsBulkUpdate($hash, "room$pos.name", $tl->{'content'}->{'name'}) if ($tl->{'type'} eq 'm.room.name'); 
						if ($tl->{'type'} eq 'm.room.message' && $tl->{'content'}->{'msgtype'} eq 'm.text'){
							my $sender = $tl->{'sender'};
							if (AttrVal($name, 'MatrixSender', '') =~ $sender){
								readingsBulkUpdate($hash, "message", $tl->{'content'}->{'body'}); 
								readingsBulkUpdate($hash, "sender", $sender); 
								# command
								
							} else {
								readingsBulkUpdate($hash, "message", 'ignoriert, nicht '.AttrVal($name, 'MatrixSender', '')); 
								readingsBulkUpdate($hash, "sender", $sender); 
							}
						} elsif ($tl->{'type'} eq "org.matrix.msc3381.poll.response"){
							my $sender = $tl->{'sender'};
							if (AttrVal($name, 'MatrixSender', '') =~ $sender){
								readingsBulkUpdate($hash, "answer", $tl->{'content'}->{'org.matrix.msc3381.poll.response'}->{'answers'}[0]); 
								readingsBulkUpdate($hash, "sender", $sender); 
								# poll.end and 
								$nextRequest = "pollend" ;
								# command
							}
						}
					}
					#push(@roomlist,"$id: ";
				}
			}
		}
        if ($def eq "filter"){
			readingsBulkUpdate($hash, "filter_id", $decoded->{'filter_id'}) if ($decoded->{'filter_id'});
		}
        if ($def eq "msg" || $def eq "pollstart" || $def eq "pollend"){
			readingsBulkUpdate($hash, "event_id", $decoded->{'event_id'}) if ($decoded->{'event_id'});
			#m.relates_to
		}
	}
    readingsEndUpdate($hash, 1);
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} + 1;      # queue is busy until response is received
    if ($def eq "sync" && $nextRequest eq "sync" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3){
		Matrix_PerformHttpRequest($hash, $nextRequest, '');
	} elsif ($nextRequest ne "" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3) {
		Matrix_PerformHttpRequest($hash, $nextRequest, '');
	}
    # Damit ist die Abfrage zuende.
}

sub Matrix_Initialize {
    my ($hash) = @_;
	
    $hash->{DefFn}      = \&Matrix_Define;
    $hash->{UndefFn}    = \&Matrix_Undef;
    $hash->{SetFn}      = \&Matrix_Set;
    $hash->{GetFn}      = \&Matrix_Get;
    $hash->{AttrFn}     = \&Matrix_Attr;
    $hash->{ReadFn}     = \&Matrix_Read;
    $hash->{RenameFn}   = \&Matrix_Rename;

    $hash->{AttrList} = $AttrList;
	$hash->{STATE} = "paused";
	$hash->{ModuleVersion} = $Module_Version;   
}

sub Matrix_Define {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    
    if(int(@param) < 4) {
        return "too few parameters: define <name> Matrix <server> <user> <password>";
    }
    
    $hash->{name}  = $param[0];
    $hash->{server} = $param[2];
    $hash->{user} = $param[3];
    $hash->{password} = $param[4];
	
	my $name = $param[0];
    $data{MATRIX}{"$name"}{"FAILS"} = 0;
    $data{MATRIX}{"$name"}{"busy"} = 0;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{'LASTSEND'} = 0;  # remember when last sent
	$data{MATRIX}{"$name"}{"expires"} = 0;
	$data{MATRIX}{"$name"}{"refresh_token"} = ""; 
	$data{MATRIX}{"$name"}{"access_token"} =  "";
	$data{MATRIX}{"$name"}{"session"} = ""; # used for register
    return ;
}

sub Matrix_Undef {
    my ($hash, $arg) = @_; 
    my $name = $hash->{NAME};
    # undef $data
	$data{MATRIX}{"$name"} = undef;
    return ;
}

#############################################################################################
# called when the device gets renamed, copy from telegramBot
# in this case we then also need to rename the key in the token store and ensure it is recoded with new name
sub Matrix_Rename($$) {
    my ($new,$old) = @_;
	$data{MATRIX}{"$new"} = $data{MATRIX}{"$old"};
	$data{MATRIX}{"$old"} = undef;
    
    my $nhash = $defs{$new};
    
    #my $token = Matrix_readToken( $nhash, $old );
    #Matrix_storeToken( $nhash, $token );

    # remove old token with old name
    my $index_old = "Matrix_" . $old . "_token";
    #setKeyValue($index_old, undef); 
}

sub Matrix_Get {
    my ( $hash, $name, $opt, @args ) = @_;

	return "\"get $name\" needs at least one argument" unless(defined($opt));
	
	my $value = shift @args;

	if ($opt eq "wellknown") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "sync") {
		$data{MATRIX}{"$name"}{"FAILS"} = 0;
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "filter") {
	    return "\"get Matrix $opt\" needs at least two arguments" if (int(@args) < 1);
		return Matrix_PerformHttpRequest($hash, $opt, $value);
	}
	return "Unknown argument $opt, choose one of filter sync wellknown";
}

sub Matrix_Set {
	my ($hash, @param) = @_;
	
	#return '"set Matrix needs at least two arguments' if (int(@param) < 3);
	
	my $name = shift @param;
	my $opt = shift @param;
	my $value = join("", @param);
	
	if ($opt eq "msg") {
		return Matrix_PerformHttpRequest($hash, $opt, $value);
	}
	elsif ($opt eq "poll" || $opt eq "poll.fullstate") {
		readingsSingleUpdate($hash, $opt, $value, 1);                                                        # Readings erzeugen
	}
	elsif ($opt eq "filter") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "pollstart") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "pollend") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "register") {
		return Matrix_PerformHttpRequest($hash, $opt, ''); # 2 steps (ToDo: 3 steps empty -> dummy -> registration_token o.a.)
	}
	elsif ($opt eq "login") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "refresh") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
    else {		
		return "Unknown argument $opt, choose one of filter pollstart pollend poll:0,1 poll.fullstate:0,1 msg register login:noArg refresh:noArg";
	}
    
	#return "$opt set to $value. Try to get it.";
}


sub Matrix_Attr {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
        if($attr_name eq "matrixRoom") {
			if($attr_value !~ /^yes|no$/) {
			    my $err = "Invalid argument $attr_value to $attr_name. Must be yes or no.";
			    Log 3, "Matrix: ".$err;
			    return $err;
			}
		} else {
		    return ;
		}
	}
	return ;
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
                  Experimental: start a in this time fixed question in the room from reading room. The first answer to the question is logged and ends the question.</li>
              <li><i>question.end</i><br>
                  Experimental: stop a question also it is not answered.</li>
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
                Set the room-id to wich are messages sent.
            </li>
            <li><i>MatrixQuestion_.</i> <room-id><br>
                Set the room-id to wich are messages sent.
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
                  Experimentell: zur Zeit noch feste Frage in den Raum des Attributs "MatrixMessage". Die erste Antwort steht im Reading "answer" und die Frage wird beendet.</li>
              <li><i>question.end</i><br>
                  Experimentell: Die gestartete Frage ohne Antwort beenden.</li>
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
                Set the room-id to wich are messages sent.
            </li>
            <li><i>MatrixQuestion_.</i> <room-id><br>
                Set the room-id to wich are messages sent.
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
=end html_DE
=cut
