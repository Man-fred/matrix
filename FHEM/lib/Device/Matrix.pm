my $Module_Version = '0.0.7';

sub Matrix_PerformHttpRequest($$$)
{
    my ($hash, $def, $value) = @_;
	my $now  = gettimeofday();
    my $name = $hash->{NAME};
    my $param = {
                    timeout    => 10,
                    hash       => $hash,                                      # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    def        => $def,                                       # sichern für eventuelle Wiederholung
					value      => $value,                                     # sichern für eventuelle Wiederholung
                    method     => "POST",                                     # standard, sonst überschreiben
                    header     => "User-Agent: HttpUtils/2.2.3\r\nAccept: application/json",  # Den Header gemäß abzufragender Daten setzen
                    callback   => \&Matrix_ParseHttpResponse                  # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} + 1;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{'LASTSEND'} = $now;                                # remember when last sent
	if ($def eq "sync" && $data{MATRIX}{"$name"}{"next_refresh"} < $now){
		$def = "refresh";
		$data{MATRIX}{"$name"}{"next_refresh"} = $now + 300;
	}
	
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
      $param->{'url'} =  $hash->{server}.'/_matrix/client/r0/rooms/'.AttrVal($name, 'MatrixMessage', '!!').'/send/m.room.message?access_token='.$data{MATRIX}{"$name"}{"access_token"};
      $param->{'data'} = '{"msgtype":"m.text", "body":"'.$value.'"}';
	}
	if ($def eq "question.start"){ 
      $value = AttrVal($name, "MatrixQuestion_$value",$value); #  if ($value =~ /[0-9]/);
	  my @question = split(':',$value);
	  my $size = @question;
	  $value =~ tr/:/<br>/;
	  # min. question and one answer
	  if (int(@question) >= 2){
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'MatrixMessage', '!!').'/send/m.poll.start?access_token='.$data{MATRIX}{"$name"}{"access_token"};
		  $param->{'data'} = '{"org.matrix.msc3381.poll.start": {"max_selections": 1,'.
		  '"question": {"org.matrix.msc1767.text": "'.$question[0].'"},'.
		  '"kind": "org.matrix.msc3381.poll.undisclosed",'.
		  '"answers": [{"id": "'.$question[1].'", "org.matrix.msc1767.text": "'.$question[1].'"},{"id":"'.$question[2].'","org.matrix.msc1767.text": "'.$question[2].'"}],'.
		  '"org.matrix.msc1767.text": "'.$value.'"}}';
	  } else {
		  Log3 $name, 3, "question.start: $value $size $question[0]";
		  return;
	  }
	}
	if ($def eq "question.end"){   
	  $value = ReadingsVal($name, "question_id", "") if (!$value);
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/rooms/'.AttrVal($name, 'MatrixMessage', '!!').'/send/m.poll.end?access_token='.$data{MATRIX}{"$name"}{"access_token"};
	  # ""'.ReadingsVal($name, 'questionEventId', '!!').'
      $param->{'data'} = '{"m.relates_to": {"rel_type": "m.reference","event_id": "'.$value.'"},"org.matrix.msc3381.poll.end": {},'.
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
    Log3 $name, 3, $test;
          
    HttpUtils_NonblockingGet($param);   #  Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
	return undef; 
}

sub Matrix_ParseHttpResponse($)
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
        readingsBulkUpdate($hash, "fullResponse", $data); 
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
			$data{MATRIX}{"$name"}{"next_refresh"} = $now + $data{MATRIX}{"$name"}{"expires"}/1000 - 60; # refresh one minute before end
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
								
							}
							#else {
							#	readingsBulkUpdate($hash, "message", 'ignoriert, nicht '.AttrVal($name, 'MatrixSender', '')); 
							#	readingsBulkUpdate($hash, "sender", $sender); 
							#}
						} elsif ($tl->{'type'} eq "org.matrix.msc3381.poll.response"){
							my $sender = $tl->{'sender'};
							if (AttrVal($name, 'MatrixSender', '') =~ $sender){
								readingsBulkUpdate($hash, "answer", $tl->{'content'}->{'org.matrix.msc3381.poll.response'}->{'answers'}[0]); 
								readingsBulkUpdate($hash, "sender", $sender); 
								# poll.end and 
								$nextRequest = "question.end" ;
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
        if ($def eq "msg" ){
			readingsBulkUpdate($hash, "event_id", $decoded->{'event_id'}) if ($decoded->{'event_id'});
			#m.relates_to
		}
        if ($def eq "question.start"){
			readingsBulkUpdate($hash, "question_id", $decoded->{'event_id'}) if ($decoded->{'event_id'});
			#m.relates_to
		}
        if ($def eq "question.end"){
			readingsBulkUpdate($hash, "event_id", $decoded->{'event_id'}) if ($decoded->{'event_id'});
			readingsBulkUpdate($hash, "question_id", "") if ($decoded->{'event_id'});
			#m.relates_to
		}
	}
    readingsEndUpdate($hash, 1);
    $data{MATRIX}{"$name"}{"busy"} = $data{MATRIX}{"$name"}{"busy"} - 1;      # queue is busy until response is received
	$data{MATRIX}{"$name"}{"sync"} = 0 if ($def eq "sync");                   # possible next sync
	$nextRequest = "" if ($nextRequest eq "sync" && $data{MATRIX}{"$name"}{"sync"} == 1); # only one sync at a time!
	
    #if ($def eq "sync" && $nextRequest eq "sync" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3){
	#	Matrix_PerformHttpRequest($hash, $nextRequest, '');
	#} els
	if ($nextRequest ne "" && ReadingsVal($name,'poll',0) == 1 && $data{MATRIX}{"$name"}{"FAILS"} < 3) {
		if ($nextRequest eq "sync" && $data{MATRIX}{"$name"}{"repeat"}){
			$def = $data{MATRIX}{"$name"}{"repeat"}->{"def"};
			$value = $data{MATRIX}{"$name"}{"repeat"}->{"value"};
			$data{MATRIX}{"$name"}{"repeat"} = undef;
			Matrix_PerformHttpRequest($hash, $def, $value);
		} else {
			Matrix_PerformHttpRequest($hash, $nextRequest, '');
		}
	}
    # Damit ist die Abfrage zuende.
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
    #$data{MATRIX}{"$name"}{"FAILS"} = 0;
    #$data{MATRIX}{"$name"}{"busy"} = 0;      # queue is busy until response is received
	#$data{MATRIX}{"$name"}{'LASTSEND'} = 0;  # remember when last sent
	#$data{MATRIX}{"$name"}{"expires"} = 0;
	#$data{MATRIX}{"$name"}{"refresh_token"} = ""; 
	#$data{MATRIX}{"$name"}{"access_token"} =  "";
	#$data{MATRIX}{"$name"}{"session"} = ""; # used for register
	#$hash->{STATE} = "paused";
	$hash->{NOTIFYDEV} = "global";
	Matrix_Startproc($hash) if($init_done);
    return ;
}

sub Matrix_Undef {
    my ($hash, $arg) = @_; 
    my $name = $hash->{NAME};
    # undef $data
	$data{MATRIX}{"$name"} = undef;
    return ;
}

sub Matrix_Startproc {
	my ($hash) = @_;
	my $name = $hash->{NAME};
    Log3 $name, 1, "$name: Matrix_Startproc V".$hash->{ModuleVersion}." -> V".$Module_Version; 
	# Update necessary?
	$hash->{ModuleVersion} = $Module_Version;   
}

##########################
sub Matrix_Notify($$)
{
	my ($hash, $dev) = @_;
	my $name = $hash->{NAME};
	my $devName = $dev->{NAME};
	return "" if(IsDisabled($name));
	Log3 $name, 1, "$name : X_Notify $devName";
	my $events = deviceEvents($dev,1);
	return if( !$events );

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		Matrix_Startproc($hash);
	}

	foreach my $event (@{$events}) {
		$event = "" if(!defined($event));
		### Writing log entry
		Log3 $name, 1, "$name : X_Notify $devName - $event";
		# Examples:
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
	elsif ($opt eq "question.start") {
		return Matrix_PerformHttpRequest($hash, $opt, $value);
	}
	elsif ($opt eq "question.end") {
		return Matrix_PerformHttpRequest($hash, $opt, $value);
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
		return "Unknown argument $opt, choose one of filter:noArg question.start question.end poll:0,1 poll.fullstate:0,1 msg register login:noArg refresh:noArg";
	}
    
	#return "$opt set to $value. Try to get it.";
}


sub Matrix_Attr {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
        if($attr_name eq "xxMatrixRoom") {
			$attr_value =~ tr/: /~:/;
			addToDevAttrList("mt", "MatrixMessage:".$attr_value);
		} elsif($attr_name eq "xxMatrixMessage") {
			@_[3] =~ tr/~/:/;
		} else {
		    return ;
		}
	}
	return ;
}
