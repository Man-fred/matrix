##########################################################################
# Usage:
#
##########################################################################
# $Id: Matrix.pm 22821 2022-11-12 12:52:00Z Man-fred $
#
# from the developerpages:
# Verwendung von lowerCamelCaps für a) die Bezeichnungen der Behälter für Readings, Fhem und Helper und der Untereintraege, 
#                                   b) die Bezeichnungen der Readings, 
#                                   c) die Bezeichnungen der Attribute.

package FHEM::Devices::Matrix;
use strict;
use warnings;
use HttpUtils;
use JSON;
#use GPUtils qw(GP_Import);
#use vars qw(%data);
use FHEM::Core::Authentication::Passwords qw(:ALL);

#    InternalTimer
#    strftime
#    RemoveInternalTimer
#    readingFnAttributes
#    notifyRegexpChanged
#    HttpUtils_BlockingGet

BEGIN {

  GP_Import(qw(
    readingsBeginUpdate
    readingsBulkUpdate
    readingsEndUpdate
    readingsSingleUpdate
    Log3
    defs
    init_done
	IsDisabled
	deviceEvents
    AttrVal
    ReadingsVal
    HttpUtils_NonblockingGet
	data
	gettimeofday
	fhem
  ))
};

my $Module_Version = '0.0.7';
my $language = 'EN';

sub Attr_List{
	return "matrixRoom matrixSender matrixMessage matrixQuestion_ matrixQuestion_[0-9]+ matrixAnswer_ matrixAnswer_[0-9]+ $readingFnAttributes";
}

sub Define {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
	my $name = $param[0]; #$param[0];
	
    Log3($name, 1, "$name: Define: $param[2] ".int(@param)); 

    if(int(@param) < 1) {
        return "too few parameters: define <name> Matrix <server> <user>";
    }
    $hash->{name}  = $param[0];
    $hash->{server} = $param[2];
    $hash->{user} = $param[3];
    $hash->{password} = $param[4];
    $hash->{helper}->{passwdobj} = FHEM::Core::Authentication::Passwords->new($hash->{TYPE});
	#$hash->{helper}->{i18} = Get_I18n();
	$hash->{NOTIFYDEV} = "global";
	Startproc($hash) if($init_done);
    return ;
}

sub Undef {
    my ($hash, $arg) = @_; 
    my $name = $hash->{NAME};
    # undef $data
	$data{MATRIX}{"$name"} = undef;
    $hash->{helper}->{passwdobj}->setDeletePassword($name);
    return ;
}

sub Startproc {
	my ($hash) = @_;
	my $name = $hash->{NAME};
    Log3($name, 1, "$name: Startproc V".$hash->{ModuleVersion}." -> V".$Module_Version) if ($hash->{ModuleVersion}); 
	# Update necessary?
	$hash->{ModuleVersion} = $Module_Version;   
	$language = AttrVal('global','language','EN');
}

##########################
sub Notify($$)
{
	my ($hash, $dev) = @_;
	my $name = $hash->{NAME};
	my $devName = $dev->{NAME};
	return "" if(IsDisabled($name));
	#Log3($name, 1, "$name : X_Notify $devName");
	my $events = deviceEvents($dev,1);
	return if( !$events );

	if(($devName eq "global") && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		Startproc($hash);
	}
	foreach my $event (@{$events}) {
		$event = "" if(!defined($event));
		### Writing log entry
		Log3($name, 4, "$name : X_Notify $devName - $event");
		$language = AttrVal('global','language','EN') if ($event =~ /ATTR global language.*/);
		# Examples:
		# $event = "ATTR global language DE"
		# $event = "readingname: value" 
		# or
		# $event = "INITIALIZED" (for $devName equal "global")
		#
		# processing $event with further code
	}
	return undef;
}

#############################################################################################
# called when the device gets renamed, copy from telegramBot
# in this case we then also need to rename the key in the token store and ensure it is recoded with new name
sub Rename($$) {
    my ($new,$old) = @_;
	my $hash    = $defs{$new};

	$data{MATRIX}{"$new"} = $data{MATRIX}{"$old"};
	$data{MATRIX}{"$old"} = undef;
    $hash->{helper}->{passwdobj}->setRename($new,$old);
	
    #my $nhash = $defs{$new};
}

sub I18N {
	my $value = shift;
	my $def = { 
		'EN' => {
			'require2' => 'requires 2 arguments'
		},
		'DE' => {
			'require2' => 'benötigt 2 Argumente'
		}, 
	};
    my $result = $def->{$language}->{$value};
	return ($result ? $result : $value);
	
}

sub Get {
	my ( $hash, $name, $cmd, @args ) = @_;
	my $value = join(" ", @args);
	#$cmd = '?' if (!$cmd);

	if ($cmd eq "wellknown") {
		return PerformHttpRequest($hash, $cmd, '');
	}
	elsif ($cmd eq "logintypes") {
		return PerformHttpRequest($hash, $cmd, '');
	}
	elsif ($cmd eq "sync") {
		$data{MATRIX}{"$name"}{"FAILS"} = 0;
		return PerformHttpRequest($hash, $cmd, '');
	}
	elsif ($cmd eq "filter") {
	    return qq("get Matrix $cmd" needs a filterId to request);
		return PerformHttpRequest($hash, $cmd, $value);
	}
	return "Unknown argument $cmd, choose one of logintypes filter sync wellknown";
}

sub Set {
	my ( $hash, $name, $cmd, @args ) = @_;
	my $value = join(" ", @args);
	#$opt = '?' if (!$opt);
	
	#Log3($name, 5, "Set $hash->{NAME}: $name - $cmd - $value");
	#return "set $name needs at least one argument" if (int(@$param) < 3);
	
	if ($cmd eq "msg") {
		return PerformHttpRequest($hash, $cmd, $value);
	}
	elsif ($cmd eq "poll" || $cmd eq "pollFullstate") {
		readingsSingleUpdate($hash, $cmd, $value, 1);                                                        # Readings erzeugen
	}
	elsif ($cmd eq "password") {
		my ($erg,$err) = $hash->{helper}->{passwdobj}->setStorePassword($name,$value);
		return undef;
	}
	elsif ($cmd eq "filter") {
		return PerformHttpRequest($hash, $cmd, '');
	}
	elsif ($cmd eq "question") {
		return PerformHttpRequest($hash, $cmd, $value);
	}
	elsif ($cmd eq "questionEnd") {
		return PerformHttpRequest($hash, $cmd, $value);
	}
	elsif ($cmd eq "register") {
		return PerformHttpRequest($hash, $cmd, ''); # 2 steps (ToDo: 3 steps empty -> dummy -> registration_token o.a.)
	}
	elsif ($cmd eq "login") {
		return PerformHttpRequest($hash, $cmd, '');
	}
	elsif ($cmd eq "refresh") {
		return PerformHttpRequest($hash, $cmd, '');
	}
    else {		
		return "Unknown argument $cmd, choose one of filter:noArg password question questionEnd poll:0,1 pollFullstate:0,1 msg register login:noArg refresh:noArg";
	}
    
	#return "$opt set to $value. Try to get it.";
}


sub Attr {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	Log3($name, 1, "Attr - $cmd - $name - $attr_name - $attr_value");
	if($cmd eq "set") {
		if ($attr_name eq "matrixQuestion_") {
			my @erg = split(/ /, $attr_value, 2);
			#$_[2] = "matrixQuestion_n";
			return qq("attr $name $attr_name" ).I18N('require2') if (!$erg[1] || $erg[0] !~ /[0-9]/);
			$_[2] = "matrixQuestion_$erg[0]";
			$_[3] = $erg[1];
		}
		if ($attr_name eq "matrixAnswer_") {
			my @erg = split(/ /, $attr_value, 2);
			return qq(wrong arguments $attr_name") if (!$erg[1] || $erg[0] !~ /[0-9]+/);
			$_[2] = "matrixAnswer_$erg[0]";
			$_[3] = $erg[1];
		}
	}
	return ;
}

sub Get_Message($$$) {
	my($name, $def, $message) = @_;
	Log3($name, 5, "$name - $def - $message");
	my $q = AttrVal($name, "matrixQuestion_$def", "");
	my $a = AttrVal($name, "matrixAnswer_$def", "");
	my @questions = split(':',$q);
	shift @questions;
	my @answers = split(':', $a);
	Log3($name, 5, "$name - $q - $a");
	my $pos = 0;
	my ($question, $answer);
	foreach $question (@questions){
		$answer = $answers[$pos] if ($message eq $question);
		if ($answer){
			Log3($name, 5, "$name - $pos - $answer");
			fhem($answer);
			last;
		}
		$pos++;
	}
}

sub PerformHttpRequest($$$)
{
    my ($hash, $def, $value) = @_;
	my $now  = gettimeofday();
    my $name = $hash->{NAME};
	my $passwd = "";
	if ($def eq "login" || $def eq "reg2"){
		$passwd = $hash->{helper}->{passwdobj}->getReadPassword($name) ;
	}
	#Log3($name, 5, "PerformHttpRequest - $name - $passwd");
	
	
    my $param = {
                    timeout    => 10,
                    hash       => $hash,                                      # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    def        => $def,                                       # sichern für eventuelle Wiederholung
					value      => $value,                                     # sichern für eventuelle Wiederholung
                    method     => "POST",                                     # standard, sonst überschreiben
                    header     => "User-Agent: HttpUtils/2.2.3\r\nAccept: application/json",  # Den Header gemäß abzufragender Daten setzen
                    callback   => \&ParseHttpResponse                         # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} ? $data{MATRIX}{"$name"}{"busy"} + 1 : 1;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{'LASTSEND'} = $now;                                # remember when last sent
	if ($def eq "sync" && $data{MATRIX}{"$name"}{"next_refresh"} < $now){
		$def = "refresh";
		Log3($name, 3, qq($name - sync2refresh - $data{MATRIX}{"$name"}{"next_refresh"} < $now) );
		$data{MATRIX}{"$name"}{"next_refresh"} = $now + 300;
	}
	
	my $deviceId = ReadingsVal($name, 'deviceId', undef) ? ', "deviceId":"'.ReadingsVal($name, 'deviceId', undef).'"' : "";
	if ($def eq "logintypes"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/r0/login";
	  $param->{'method'} = 'GET';
	}
	if ($def eq "register"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$passwd.'"}';
	}
	if ($def eq "reg1"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$passwd.'"}';
	}
	if ($def eq"reg2"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"username":"'.$hash->{user}.'", "password":"'.$passwd.'", "auth": {"session":"'.$data{MATRIX}{"$name"}{"session"}.'","type":"m.login.dummy"}}';
	}
	if ($def eq "login"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/login";
      $param->{'data'} = '{"type":"m.login.password", "refresh_token": true, "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$passwd.'"'
	                     .$deviceId.'}';
	}
	if ($def eq "refresh"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v1/refresh'; 
      $param->{'data'} = '{"refresh_token": "'.$data{MATRIX}{"$name"}{"refresh_token"}.'"}';
	}
	if ($def eq "wellknown"){
      $param->{'url'} =  $hash->{server}."/.well-known/matrix/client";
 	}
	if ($def eq "msg"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/r0/rooms/'.AttrVal($name, 'matrixMessage', '!!').'/send/m.room.message?access_token='.$data{MATRIX}{"$name"}{"access_token"};
      $param->{'data'} = '{"msgtype":"m.text", "body":"'.$value.'"}';
	}
	if ($def eq "question"){ 
	  $data{MATRIX}{"$name"}{"question"}=$value;
      $value = AttrVal($name, "matrixQuestion_$value",""); #  if ($value =~ /[0-9]/);
	  my @question = split(':',$value);
	  my $size = @question;
	  my $answer;
	  my $q = shift @question;
	  $value =~ s/:/<br>/g;
	  # min. question and one answer
	  if (int(@question) >= 2){
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'matrixMessage', '!!').
			'/send/m.poll.start?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'data'} = '{"org.matrix.msc3381.poll.start": {"max_selections": 1,'.
		  '"question": {"org.matrix.msc1767.text": "'.$q.'"},'.
		  '"kind": "org.matrix.msc3381.poll.undisclosed","answers": [';
		  my $comma = '';
		  foreach $answer (@question){
			  $param->{'data'} .= qq($comma {"id": "$answer", "org.matrix.msc1767.text": "$answer"});
			  $comma = ',';
		  }
		  $param->{'data'} .= qq(],"org.matrix.msc1767.text": "$value"}});
	  } else {
		  Log3($name, 5, "question: $value $size $question[0]");
		  return;
	  }
	}
	if ($def eq "questionEnd"){   
	  $value = ReadingsVal($name, "questionId", "") if (!$value);
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'matrixMessage', '!!').'/send/m.poll.end?access_token='.$data{MATRIX}{"$name"}{"access_token"};
	  # ""'.ReadingsVal($name, 'questionEventId', '!!').'
      $param->{'data'} = '{"m.relates_to": {"rel_type": "m.reference","eventId": "'.$value.'"},"org.matrix.msc3381.poll.end": {},'.
                '"org.matrix.msc1767.text": "Antort '.ReadingsVal($name, "answer", "").' erhalten von '.ReadingsVal($name, "sender", "").'"}';
	}
	if ($def eq "sync"){  
		my $since = ReadingsVal($name, "since", undef) ? '&since='.ReadingsVal($name, "since", undef) : "";
		my $full_state = ReadingsVal($name, "pollFullstate",undef);
		if ($full_state){
			$full_state = "&full_state=true";
			readingsSingleUpdate($hash, "pollFullstate", 0, 1);
		} else {
			$full_state = "";
		}
		$param->{'url'} =  $hash->{server}.'/_matrix/client/r0/sync?access_token='.$data{MATRIX}{"$name"}{"access_token"}.$since.$full_state.'&timeout=50000&filter='.ReadingsVal($name, 'filterId',0);
		$param->{'method'} = 'GET';
		$param->{'timeout'} = 60;
	}
	if ($def eq "filter"){
      if ($value){ # get
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.ReadingsVal($name, "userId",0).'/filter/'.$value.'?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'method'} = 'GET';
	  } else {	  
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.ReadingsVal($name, "userId",0).'/filter?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'data'} = '{';
		  $param->{'data'} .= '"event_fields": ["type","content","sender"],';
		  $param->{'data'} .= '"event_format": "client", ';
		  $param->{'data'} .= '"presence": { "senders": [ "@xx:example.com"]}'; # no presence
		  #$param->{'data'} .= '"room": { "ephemeral": {"rooms": ["'.AttrVal($name, 'matrixRoom', '!!').'"],"types": ["m.receipt"]}, "state": {"types": ["m.room.*"]},"timeline": {"types": ["m.room.message"] } }';
		  $param->{'data'} .= '}';
	  }
	}

    my $test = "$param->{url}, "
        . ( $param->{data}   ? "\r\ndata: $param->{data}, "   : "" )
        . ( $param->{header} ? "\r\nheader: $param->{header}" : "" );
	#readingsSingleUpdate($hash, "fullRequest", $test, 1);                                                        # Readings erzeugen
	$test = "$name: Matrix sends with timeout $param->{timeout} to ".$test;
    Log3($name, 5, $test);
          
    HttpUtils_NonblockingGet($param);   #  Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
	return undef; 
}

sub ParseHttpResponse($)
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
	my $def = $param->{def};
	my $value = $param->{value};
    my $name = $hash->{NAME};
	my $now  = gettimeofday();
	my $nextRequest = "";

    readingsBeginUpdate($hash);
	###readingsBulkUpdate($hash, "httpHeader", $param->{httpheader});
	readingsBulkUpdate($hash, "httpStatus", $param->{code});
	$hash->{STATE} = $def.' - '.$param->{code};
    if($err ne "") {                                                         # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        Log3($name, 2, "error while requesting ".$param->{url}." - $err");   # Eintrag fürs Log
        readingsBulkUpdate($hash, "responseError", $err);                    # Reading erzeugen
		$data{MATRIX}{"$name"}{"FAILS"} = 3;
    }
    elsif($data ne "") {                                                     # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
		Log3($name, 4, $def." returned: $data");              # Eintrag fürs Log
		my $decoded = eval { JSON::decode_json($data) };
		Log3($name, 2, "$name: json error: $@ in data") if( $@ );
        if ($param->{code} == 200){
			$data{MATRIX}{"$name"}{"FAILS"} = 0;
		} else {
			$data{MATRIX}{"$name"}{"FAILS"}++;
			readingsBulkUpdate($hash, "responseError", $data{MATRIX}{"$name"}{"FAILS"}.' - '.$data);        
		}
        # readingsBulkUpdate($hash, "fullResponse", $data); 
		
		# default next request
		$nextRequest = "sync" ;
        # An dieser Stelle die Antwort parsen / verarbeiten mit $data
				
		# "errcode":"M_UNKNOWN_TOKEN: login or refresh
		my $errcode = $decoded->{'errcode'} ? $decoded->{'errcode'} : "";
		if ($errcode eq "M_UNKNOWN_TOKEN"){
			$data{MATRIX}{"$name"}{"repeat"} = $param if ($def ne "sync");
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
        
        if ($def eq "register"){
			$data{MATRIX}{"$name"}{"session"} = $decoded->{'session'};
			$nextRequest = "";#"reg2";
		}
		if ($def eq  "reg2" || $def eq  "login" || $def eq "refresh") {
			readingsBulkUpdate($hash, "lastRegister", $param->{code}) if $def eq  "reg2";
			readingsBulkUpdate($hash, "lastLogin",  $param->{code}) if $def eq  "login";
			readingsBulkUpdate($hash, "lastRefresh", $param->{code}) if $def eq  "refresh";
			if ($param->{code} == 200){
				readingsBulkUpdate($hash, "userId", $decoded->{'userId'}) if ($decoded->{'userId'});
				readingsBulkUpdate($hash, "homeServer", $decoded->{'homeServer'}) if ($decoded->{'homeServer'});
				readingsBulkUpdate($hash, "deviceId", $decoded->{'deviceId'}) if ($decoded->{'deviceId'});
				
				$data{MATRIX}{"$name"}{"expires"} = $decoded->{'expires_in_ms'} if ($decoded->{'expires_in_ms'});
				$data{MATRIX}{"$name"}{"refresh_token"} = $decoded->{'refresh_token'} if ($decoded->{'refresh_token'}); 
				$data{MATRIX}{"$name"}{"access_token"} =  $decoded->{'access_token'} if ($decoded->{'access_token'});
				$data{MATRIX}{"$name"}{"next_refresh"} = $now + $data{MATRIX}{"$name"}{"expires"}/1000 - 60; # refresh one minute before end
			}
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
					# matrixRoom ?
					readingsBulkUpdate($hash, "room$pos.id", $id); 
					#foreach my $id ( $decoded->{'rooms'}->{'join'}->{AttrVal($name, 'matrixRoom', '!!')}->{'timeline'}->{'events'}->@* ) {
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
							my $message = $tl->{'content'}->{'body'};
							if (AttrVal($name, 'matrixSender', '') =~ $sender){
								readingsBulkUpdate($hash, "message", $message); 
								readingsBulkUpdate($hash, "sender", $sender); 
								# command
								Get_Message($name, '99', $message);
							}
							#else {
							#	readingsBulkUpdate($hash, "message", 'ignoriert, nicht '.AttrVal($name, 'matrixSender', '')); 
							#	readingsBulkUpdate($hash, "sender", $sender); 
							#}
						} elsif ($tl->{'type'} eq "org.matrix.msc3381.poll.response"){
							my $sender = $tl->{'sender'};
							my $message = $tl->{'content'}->{'org.matrix.msc3381.poll.response'}->{'answers'}[0];
							if (AttrVal($name, 'matrixSender', '') =~ $sender){
								readingsBulkUpdate($hash, "message", $message); 
								readingsBulkUpdate($hash, "sender", $sender); 
								$nextRequest = "questionEnd" ;
								# command
								Get_Message($name, $data{MATRIX}{"$name"}{"question"}, $message);
							}
						}
					}
					#push(@roomlist,"$id: ";
				}
			}
		}
        if ($def eq "logintypes"){
			my $types = '';
			foreach my $flow ( $decoded->{'flows'}->@* ) {
				if ($flow->{'type'} =~ /m\.login\.(.*)/) {
					#$types .= "$flow->{'type'} ";
					$types .= "$1 ";# if ($flow->{'type'} );
				}
			}
			readingsBulkUpdate($hash, "logintypes", $types);
		}
        if ($def eq "filter"){
			readingsBulkUpdate($hash, "filterId", $decoded->{'filterId'}) if ($decoded->{'filterId'});
		}
        if ($def eq "msg" ){
			readingsBulkUpdate($hash, "eventId", $decoded->{'eventId'}) if ($decoded->{'eventId'});
			#m.relates_to
		}
        if ($def eq "question"){
			readingsBulkUpdate($hash, "questionId", $decoded->{'eventId'}) if ($decoded->{'eventId'});
			#m.relates_to
		}
        if ($def eq "questionEnd"){
			readingsBulkUpdate($hash, "eventId", $decoded->{'eventId'}) if ($decoded->{'eventId'});
			readingsBulkUpdate($hash, "questionId", "") if ($decoded->{'eventId'});
			#m.relates_to
		}
	}
    readingsEndUpdate($hash, 1);
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} - 1;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{"sync"} = 0 if ($def eq "sync" || !$data{MATRIX}{"$name"}{"sync"});                   # possible next sync
	$nextRequest = "" if ($nextRequest eq "sync" && $data{MATRIX}{"$name"}{"sync"} == 1); # only one sync at a time!
	
    #if ($def eq "sync" && $nextRequest eq "sync" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3){
	#	PerformHttpRequest($hash, $nextRequest, '');
	#} els
	if ($nextRequest ne "" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3) {
		if ($nextRequest eq "sync" && $data{MATRIX}{"$name"}{"repeat"}){
			$def = $data{MATRIX}{"$name"}{"repeat"}->{"def"};
			$value = $data{MATRIX}{"$name"}{"repeat"}->{"value"};
			$data{MATRIX}{"$name"}{"repeat"} = undef;
			PerformHttpRequest($hash, $def, $value);
		} else {
			PerformHttpRequest($hash, $nextRequest, '');
		}
	}
    # Damit ist die Abfrage zuende.
}
