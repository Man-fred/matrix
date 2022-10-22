package main;
use strict;
use warnings;
use HttpUtils;

my $Module_Version = '0.0.4 - 16.10.2022';

my $AttrList = "MatrixRoom MatrixSender " . $readingFnAttributes;

sub Matrix_PerformHttpRequest($$$)
{
    my ($hash, $def, $value) = @_;
	my $now  = gettimeofday();
    my $name = $hash->{NAME};
    my $param = {
                    url        => $hash->{server}."/_matrix/client/v3/login", #/register",
					#data       => '{"username":"'.$hash->{user}.'", "password":"'.$hash->{password}.'", "auth": {"session":"'.$hash->{session}.'","type":"m.login.dummy"}}',
                    timeout    => 10,
                    hash       => $hash,                                                                                 # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method     => "POST",                                                                                 # Lesen von Inhalten
                    header     => "User-Agent: HttpUtils/2.2.3\r\nAccept: application/json",                            # Den Header gemäß abzufragender Daten ändern
                    callback   => \&Matrix_ParseHttpResponse                                                                  # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
    $hash->{BUSY}  = $hash->{BUSY} + 1;                                   # queue is busy until response is received
    $hash->{stage} = $def;
	$hash->{'LASTSEND'} = $now;                                # remember when last sent
	my $device_id = $hash->{device_id} ? ', "device_id":"'.$hash->{device_id}.'"' : "";
	if ($def eq "register"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$hash->{password}.'"}';
	}
	if ($def eq"reg2"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/register";
      $param->{'data'} = '{"username":"'.$hash->{user}.'", "password":"'.$hash->{password}.'", "auth": {"session":"'.$hash->{session}.'","type":"m.login.dummy"}}';
	}
	if ($def eq "login"){
      $param->{'url'} =  $hash->{server}."/_matrix/client/v3/login";
      $param->{'data'} = '{"type":"m.login.password", "refresh_token": true, "identifier":{ "type":"m.id.user", "user":"'.$hash->{user}.'" }, "password":"'.$hash->{password}.'"'
	                     .$device_id.'}';
	}
	if ($def eq "refresh"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/v1/refresh'; 
      $param->{'data'} = '{"refresh_token": "'.ReadingsVal($name, '.refresh_token','xx').'"}';
	}
	if ($def eq "wellknown"){
      $param->{'url'} =  $hash->{server}."/.well-known/matrix/client";
 	}
	if ($def eq "msg"){              
      $param->{'url'} =  $hash->{server}.'/_matrix/client/r0/rooms/'.ReadingsVal($name, 'room', '!!').'/send/m.room.message?access_token='.ReadingsVal($name, '.access_token', 'xx');
      $param->{'data'} = '{"msgtype":"m.text", "body":"'.$value.'"}';
	}
	if ($def eq "sync"){  
		my $since = $hash->{since} ? '&since='.$hash->{since} : "";
		my $full_state = ReadingsVal($name, "poll.fullstate",undef);
		if ($full_state){
		    $full_state = "&full_state=true";
			readingsSingleUpdate($hash, "poll.fullstate", 0, 1);
		} else {
			$full_state = "";
		}
		$param->{'url'} =  $hash->{server}.'/_matrix/client/r0/sync?access_token='.ReadingsVal($name, '.access_token', 'xx').$since.$full_state.'&timeout=50000&filter='.ReadingsVal($name, 'filter_id',0);
		$param->{'method'} = 'GET';
		$param->{'timeout'} = 60;
	}
	if ($def eq "filter"){
      if ($value){ # get
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.$hash->{user_id}.'/filter/'.$value.'?access_token='.ReadingsVal($name, '.access_token', 'xx');
		  $param->{'method'} = 'GET';
	  } else {	  
		  $param->{'url'} =  $hash->{server}.'/_matrix/client/v3/user/'.$hash->{user_id}.'/filter?access_token='.ReadingsVal($name, '.access_token', 'xx');
		  $param->{'data'} = '{';
		  $param->{'data'} .= '"event_fields": ["type","content","sender"],';
		  $param->{'data'} .= '"event_format": "client", ';
		  $param->{'data'} .= '"presence": { "senders": [ "@xx:example.com"]}';
		  #$param->{'data'} .= '"room": { "ephemeral": {"rooms": ["'.AttrVal($name, 'MatrixRoom', '!!').'"],"types": ["m.receipt"]}, "state": {"types": ["m.room.*"]},"timeline": {"types": ["m.room.message"] } }';
		  $param->{'data'} .= '}';
	  }
	}

    my $test = "$param->{url}, "
        . ( $param->{data}   ? "\r\ndata: $param->{data}, "   : "" )
        . ( $param->{header} ? "\r\nheader: $param->{header}" : "" );
	readingsSingleUpdate($hash, "fullRequest", $test, 1);                                                        # Readings erzeugen
	$test = "$name: Matrixe sends with timeout $param->{timeout} to ".$test;
    Log3 $name, 5, $test;
          
    HttpUtils_NonblockingGet($param);   #  Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
	return undef; #"connect"; #$test;
}

sub Matrix_ParseHttpResponse($)
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
	my $now  = gettimeofday();
	my $nextRequest = "";

    readingsBeginUpdate($hash);
	###readingsBulkUpdate($hash, "httpHeader", $param->{httpheader});
	readingsBulkUpdate($hash, "httpStatus", $param->{code});
	$hash->{STATE} = $hash->{stage}.' - '.$param->{code};
    if($err ne "") {                                                         # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        Log3 $name, 3, "error while requesting ".$param->{url}." - $err";    # Eintrag fürs Log
        readingsBulkUpdate($hash, "fullResponse", "ERROR ".$err);            # Readings erzeugen
		$hash->{FAILS} = 3;
    }
    elsif($data ne "") {                                                     # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
		Log3 $name, 3, "url ".$param->{url}." returned: $data";              # Eintrag fürs Log
		my $decoded = eval { decode_json($data) };
		Log3 $name, 2, "$name: json error: $@ in data" if( $@ );
        if ($param->{code} == 200){
			$hash->{FAILS} = 0;
		} else {
			$hash->{FAILS}++;
			if ($decoded->{'errcode'} eq "M_UNKNOWN_TOKEN" && $decoded->{'error'} eq "Access token has expired"){
			    if ($decoded->{'soft_logout'} eq "true"){
					#$hash->{polling} = $hash->{polling}.'; '.$param->{code}.' soft_logout->refresh';
					$nextRequest = 'refresh';
				}else{
					#$hash->{polling} = $hash->{polling}.'; '.$param->{code}.' hard_logout->login?';
				}
			}
		}
        # An dieser Stelle die Antwort parsen / verarbeiten mit $data
        $hash->{session} = $decoded->{'session'};
        $hash->{last_session} = $now;
        readingsBulkUpdate($hash, "fullResponse", $data); 
        if ($hash->{stage} eq "register"){
			$nextRequest = "reg2";
		}
        if ($param->{code} == 200 && ($hash->{stage} eq  "reg2" || $hash->{stage} eq  "login" || $hash->{stage} eq "refresh")){
			$hash->{user_id} = $decoded->{'user_id'} if ($decoded->{'user_id'});
			$hash->{home_server} = $decoded->{'home_server'} if ($decoded->{'home_server'});
			$hash->{device_id} = $decoded->{'device_id'} if ($decoded->{'device_id'});
			
			readingsBulkUpdate($hash, ".expires_in_ms", $decoded->{'expires_in_ms'}) if ($decoded->{'expires_in_ms'});
			readingsBulkUpdate($hash, ".refresh_token", $decoded->{'refresh_token'}) if ($decoded->{'refresh_token'}); 
			readingsBulkUpdate($hash, ".access_token",  $decoded->{'access_token'}) if ($decoded->{'access_token'});
			
		  	readingsBulkUpdate($hash, "last_register", $param->{code}) if $hash->{stage} eq  "reg2";
		  	readingsBulkUpdate($hash, "last_login",  $param->{code}) if $hash->{stage} eq  "login";
		  	readingsBulkUpdate($hash, "last_refresh", $param->{code}) if $hash->{stage} eq  "refresh";
			$hash->{polling} = '200 login' if $hash->{stage} eq  "login";
			$nextRequest = "sync" ;
		}
        if ($hash->{stage} eq "wellknown"){
			# https://spec.matrix.org/unstable/client-server-api/
		}
        if ($param->{code} == 200 && $hash->{stage} eq "sync"){
			$hash->{since} = $decoded->{'next_batch'} if ($decoded->{'next_batch'});
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
						}
					}
					#push(@roomlist,"$id: ";
				}
			}
			$nextRequest = "sync";
		}
        if ($hash->{stage} eq "filter"){
			readingsBulkUpdate($hash, "filter_id", $decoded->{'filter_id'}) if ($decoded->{'filter_id'});
		}
	}
    readingsEndUpdate($hash, 1);
    $hash->{BUSY}        = $hash->{BUSY} - 1;                                   # queue is busy until response is received
    if ($hash->{stage} eq "sync" && $nextRequest eq "sync" && ReadingsVal($name,'poll',0) == 1 && $hash->{FAILS} < 3){
		#$hash->{polling} = $hash->{polling}.'; '.$param->{code}.' sync=>sync';
		Matrix_PerformHttpRequest($hash, $nextRequest, '');
	} elsif ($nextRequest ne "" && ReadingsVal($name,'poll',0) == 1 && $hash->{FAILS} < 3) {
		#$hash->{polling} = $hash->{polling}.'; '.$param->{code}.' '.$hash->{stage}.'->'.$nextRequest;
		Matrix_PerformHttpRequest($hash, $nextRequest, '');
	}
    # Damit ist die Abfrage zuende.
    # Evtl. einen InternalTimer neu schedulen
}

#############################################################################################
# called when the device gets renamed,
# in this case we then also need to rename the key in the token store and ensure it is recoded with new name
sub Matrix_Rename($$) {
    my ($new,$old) = @_;
    
    my $nhash = $defs{$new};
    
    #my $token = Matrix_readToken( $nhash, $old );
    #Matrix_storeToken( $nhash, $token );

    # remove old token with old name
    my $index_old = "Matrix_" . $old . "_token";
    #setKeyValue($index_old, undef); 
}

sub Matrix_Poll{
	#InternalTimer(gettimeofday()+$wait, "Matrix_UpdatePoll", $hash,0); 

}


sub Matrix_ResetPolling($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "Matrix_ResetPolling $name: called ";

  RemoveInternalTimer($hash);

  HttpUtils_Close( $hash->{HU_UPD_PARAMS} ); 
  HttpUtils_Close( $hash->{HU_DO_PARAMS} ); 
  
  $hash->{WAIT} = 0;
  $hash->{FAILS} = 0;

  # let all existing methods first run into block
  $hash->{POLLING} = -1;
  
  # wait some time before next polling is starting
  InternalTimer(gettimeofday()+30, "Matrix_RestartPolling", $hash,0); 

  Log3 $name, 4, "Matrix_ResetPolling $name: finished ";

}

  
######################################
#  make sure a reinitialization is triggered on next update
#  
sub Matrix_RestartPolling($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "Matrix_RestartPolling $name: called ";

  # Now polling can start
  $hash->{POLLING} = 0;

  # wait some time before next polling is starting
  Matrix_UpdatePoll($hash);

  Log3 $name, 4, "Matrix_RestartPolling $name: finished ";

}

sub Matrix_Initialize {
    my ($hash) = @_;

    $hash->{DefFn}      = \&Matrix_Define;
    $hash->{UndefFn}    = \&Matrix_Undef;
    $hash->{SetFn}      = \&Matrix_Set;
    $hash->{GetFn}      = \&Matrix_Get;
    $hash->{AttrFn}     = \&Matrix_Attr;
    $hash->{ReadFn}     = \&Matrix_Read;
   # $hash->{RenameFn}   = \&Matrix_Rename;

    $hash->{AttrList} = $AttrList;
	$hash->{STATE} = "paused";
    $hash->{FAILS} = 0;
    $hash->{POLLING} = -1;
	$hash->{ModuleVersion} = $Module_Version;    
	$hash->{polling} = undef;

	my $encoded = to_json($hash->{NAME});
    Log3 "Matrix", 1, "Matrix_Initialize: $encoded";
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
    return ;
}

sub Matrix_Undef {
    my ($hash, $arg) = @_; 
    # nothing to do
    return ;
}

sub Matrix_Get {
    my ( $hash, $name, $opt, @args ) = @_;

	return "\"get $name\" needs at least one argument" unless(defined($opt));
	
	my $value = shift @args;

	if ($opt eq "wellknown") {
		return Matrix_PerformHttpRequest($hash, $opt, '');
	}
	elsif ($opt eq "sync") {
		$hash->{FAILS} = 0;
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
		return "Unknown argument $opt, choose one of filter poll:0,1 poll.fullstate:0,1 msg register login:noArg refresh:noArg";
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
=begin html

<a name="Matrix"></a>
<h3>Matrix</h3>
<ul>
    <i>Matrix</i> implements the classical "Matrix World" as a starting point for module development. 
    You may want to copy 98_Matrix.pm to start implementing a module of your very own. See 
    <a href="http://wiki.fhem.de/wiki/DevelopmentModuleIntro">DevelopmentModuleIntro</a> for an 
    in-depth instruction to your first module.
    <br><br>
    <a name="Matrixdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; Matrix &lt;greet&gt;</code>
        <br><br>
        Example: <code>define Matrix Matrix TurnUrRadioOn</code>
        <br><br>
        The "greet" parameter has no further meaning, it just demonstrates
        how to set a so called "Internal" value. See <a href="http://fhem.de/commandref.html#define">commandref#define</a> 
        for more info about the define command.
    </ul>
    <br>
    
    <a name="Matrixset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. They're just there to 
        <i>get</i> them. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>satisfaction</i><br>
                  Defaults to "no"</li>
              <li><i>whatyouwant</i><br>
                  Defaults to "can't"</li>
              <li><i>whatyouneed</i><br>
                  Defaults to "try sometimes"</li>
        </ul>
    </ul>
    <br>

    <a name="Matrixget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can <i>get</i> the value of any of the options described in 
        <a href="#Matrixset">paragraph "Set" above</a>. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
    </ul>
    <br>
    
    <a name="Matrixattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i>formal</i> no|yes<br>
                When you set formal to "yes", all output of <i>get</i> will be in a
                more formal language. Default is "no".
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
