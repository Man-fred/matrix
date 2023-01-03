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
#
#
package FHEM::Devices::Matrix::Client;

use strict;
use warnings;

use HttpUtils;
use JSON;
use GPUtils                               qw(GP_Import);
use FHEM::Core::Authentication::Passwords qw(:ALL);

use experimental qw /switch/
  ;    #(CoolTux) - als Ersatz für endlos lange elsif Abfragen
use Carp qw( carp )
  ;    # wir verwenden Carp für eine bessere Fehlerrückgabe (CoolTux)

use Data::Dumper;    # Debugging
use Encode;

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval {
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
} or do {

    # try to use JSON wrapper
    #   for chance of better performance
    eval {
        # JSON preference order
        local $ENV{PERL_JSON_BACKEND} =
          'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
          unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

        require JSON;
        import JSON qw( decode_json encode_json );
        1;
    } or do {

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        } or do {

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            } or do {

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                } or do {

                    # Fallback to JSON::backportPP in really rare cases
                    require JSON::backportPP;
                    import JSON::backportPP qw(decode_json encode_json);
                    1;
                };
            };
        };
    };
};

BEGIN {

    GP_Import(
        qw(
          readingFnAttributes
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
          InternalTimer
          RemoveInternalTimer
          gettimeofday
          AnalyzeCommandChain
        )
    );
}

my $VERSION = '0.0.15';

sub Attr_List {
    return
"matrixLogin:password matrixRoom matrixPoll:0,1 matrixSender matrixMessage matrixQuestion_ matrixQuestion_[0-9]+ matrixAnswer_ matrixAnswer_[0-9]+ $readingFnAttributes";
}

sub Define {

    #(CoolTux) bei einfachen übergaben nimmt man die Daten mit shift auf
    my $hash = shift;
    my $aArg = shift;

    return 'too few parameters: define <name> Matrix <server> <user>'
      if ( scalar( @{$aArg} ) != 4 );

    my $name = $aArg->[0];

    $hash->{SERVER}  = $aArg->[2];   # Internals sollten groß geschrieben werden
    $hash->{URL}     = 'https://' . $hash->{SERVER} . '/_matrix/client/';
    $hash->{USER}    = $aArg->[3];
    $hash->{VERSION} = $VERSION;

    $hash->{helper}->{passwdobj} =
      FHEM::Core::Authentication::Passwords->new( $hash->{TYPE} );
    $hash->{NOTIFYDEV} = 'global,' . $name;

    readingsSingleUpdate( $hash, 'state', 'defined', 1 );

    Log3( $name, 1,
"$name: Define: $name with Server URL: $hash->{URL} and User: $hash->{USER}"
    );

    return;
}

sub Undef {
    my $hash = shift;
    my $name = shift;

    RemoveInternalTimer($hash);

    return;
}

sub Delete {
    my $hash = shift;
    my $name = shift;

    $hash->{helper}->{passwdobj}->setDeletePassword($name);

    return;
}

sub _Init {    # wir machen daraus eine privat function (CoolTux)
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $hash = shift;

    my $name = $hash->{NAME};

    Log3( $name, 4,
        "$name : Matrix::_Init $hash " . AttrVal( $name, 'matrixPoll', '-1' ) );

    # Update necessary?
    Log3( $name, 1,
        $name . ': Start V' . $hash->{VERSION} . ' -> V' . $VERSION )
      if ( $hash->{VERSION} );

    return ::readingsSingleUpdate( $hash, 'state', 'please set password first',
        1 )
      if (
        !exists( $hash->{helper}->{passwdobj} )
        || ( exists( $hash->{helper}->{passwdobj} )
            && !defined( $hash->{helper}->{passwdobj}->getReadPassword($name) )
        )
      );

    $hash->{helper}->{softfail} = 1;

    return _PerformHttpRequest( $hash, 'login', '' );
}

sub Notify {
    my $hash = shift;
    my $dev  = shift;

    my $name = $hash->{NAME};
    return if ( ::IsDisabled($name) );

    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = ::deviceEvents( $dev, 1 );
    return if ( !$events );

    return _Init($hash)
      if (
        (
               grep { /^INITIALIZED$/x } @{$events}
            or grep { /^ATTR.$name.matrixPoll.1/x } @{$events}
            or grep { /^DELETEATTR.$name.disable$/x } @{$events}
            or grep { /^DEFINED.$name$/x } @{$events}
        )
        && $init_done
      );

#(CoolTux) bin mir nicht sicher wieso die Schleife. Nötig ist sie aber egal wofür gedacht nicht.
#(Man-Fred) die Schleife ist vom Debugging, ich wollte wissen was im Notify ankommt.
#           kann raus in einer späteren Version
# foreach my $event ( @{$events} ) {
#     $event = "" if ( !defined($event) );
#     ### Writing log entry
#     Log3( $name, 3, "$name : Matrix::Notify $devname - $event" );
#     $language = AttrVal( 'global', 'language', 'EN' )
#       if ( $event =~ /ATTR global language.*/ );

    #     # Examples:
    #     # $event = "ATTR global language DE"
    #     # $event = "readingname: value"
    #     # or
    #     # $event = "INITIALIZED" (for $devName equal "global")
    #     #
    #     # processing $event with further code
    # }

    return
      ; #(CoolTux) es reicht nur return. Wichtig jede sub muss immer mit return enden
}

#############################################################################################
# called when the device gets renamed, copy from telegramBot
# in this case we then also need to rename the key in the token store and ensure it is recoded with new name
sub Rename {
    my $new = shift;
    my $old = shift;

    my $hash = $defs{$new};

    my ( $passResp, $passErr );

    ( $passResp, $passErr ) =
      $hash->{helper}->{passwdobj}->setRename( $new, $old )
      ;    #(CoolTux) Es empfiehlt sich ab zu fragen ob der Wechsel geklappt hat

    Log3( $new, 1,
"$new : Matrix::Rename - error while change the password hash after rename - $passErr"
      )
      if (!defined($passResp)
        && defined($passErr) );

    Log3( $new, 1,
        "$new : Matrix::Rename - change password hash after rename successfully"
      )
      if ( defined($passResp)
        && !defined($passErr) );

    return;
}

sub _I18N {    # wir machen daraus eine privat function (CoolTux)
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $value = shift;

    my $def = {
        'EN' => {
            'require2'        => 'requires 2 arguments',
            'beginWithNumber' => 'must begin with a number',
            'question'        => 'a new question'
        },
        'DE' => {
            'require2'        => 'benötigt 2 Argumente',
            'beginWithNumber' => 'muss mit einer Ziffer beginnen',
            'question'        => 'Eine neue Frage'
        },
    };

    my $result = $def->{ AttrVal( 'global', 'language', 'EN' ) }->{$value};

    return ( $result ? $result : $value );
}

sub Get {
    my $hash = shift;
    my $aArg = shift;
    my $hArg = shift;

    my $name = shift @$aArg;
    my $cmd  = shift @$aArg
      // carp q[set Matrix Client needs at least one argument] && return;

    my $value = join( ' ', @{$aArg} );

    given ($cmd) {
        when ('wellknown') {
            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        when ('logintypes') {
            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        when ('sync') {
            $hash->{helper}->{softfail} = 0;
            $hash->{helper}->{hardfail} = 0;

            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        when ('filter') {
            return qq("get Matrix $cmd" needs a filterId to request);

            # return _PerformHttpRequest( $hash, $cmd, $value );
        }

        default {
            my $list = '';
            $list .= 'logintypes filter sync wellknown'
              if ( exists( $hash->{helper}->{passwdobj} )
                && defined(
                    $hash->{helper}->{passwdobj}->getReadPassword($name) ) );

            return 'Unknown argument ' . $cmd . ', choose one of ' . $list;
        }
    }
}

sub Set {
    my $hash = shift;
    my $aArg = shift;
    my $hArg = shift;

    my $name = shift @$aArg;
    my $cmd  = shift @$aArg
      // carp q[set Matrix Client needs at least one argument] && return;

    my $value = join( ' ', @{$aArg} );

    given ($cmd) {
        when ('msg') {
            return _PerformHttpRequest( $hash, $cmd, $value );
        }

        when ('pollFullstate') {
            readingsSingleUpdate( $hash, $cmd, $value, 1 );  # Readings erzeugen
        }

        when ('setPassword') {
            return qq(usage: $cmd pass=<password>)
              if ( scalar( @{$aArg} ) != 0
                || scalar( keys %{$hArg} ) != 1 );
            my ( $passResp, $passErr );

            ( $passResp, $passErr ) = $hash->{helper}->{passwdobj}
              ->setStorePassword( $name, $hArg->{'pass'} );

            return qq{error while saving the password - $passErr}
              if (!defined($passResp)
                && defined($passErr) );

            return _Init($hash)
              if ( defined($passResp)
                && !defined($passErr) );
        }

        when ('removePassword') {
            return 'usage: ' . $cmd
              if ( scalar( @{$aArg} ) != 0 );

            my ( $passResp, $passErr );
            ( $passResp, $passErr ) =
              $hash->{helper}->{passwdobj}->setDeletePassword($name);

            return qq{error while saving the password - $passErr}
              if (!defined($passResp)
                && defined($passErr) );

            return q{password successfully removed}
              if ( defined($passResp)
                && !defined($passErr) );
            return;
        }

        when ('filter') {
            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        when ('question') {
            return _PerformHttpRequest( $hash, $cmd, $value );
        }

        when ('questionEnd') {
            return _PerformHttpRequest( $hash, $cmd, $value );
        }

        when ('register') {
            return _PerformHttpRequest( $hash, $cmd, '' )
              ; # 2 steps (ToDo: 3 steps empty -> dummy -> registration_token o.a.)
        }

        when ('login') {
            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        when ('refresh') {
            return _PerformHttpRequest( $hash, $cmd, '' );
        }

        default {
            my $list = '';
            $list .= (
                exists( $hash->{helper}->{passwdobj} ) && defined(
                    $hash->{helper}->{passwdobj}->getReadPassword($name)
                  )
                ? 'removePassword:noArg '
                : 'setPassword '
            );

            $list .= 'msg login:noArg '
              if ( exists( $hash->{helper}->{passwdobj} )
                && defined(
                    $hash->{helper}->{passwdobj}->getReadPassword($name) ) );

            $list .=
'filter:noArg question questionEnd pollFullstate:0,1 msg register refresh:noArg'
              if ( ::AttrVal( $name, 'devel', 0 ) == 1
                && exists( $hash->{helper}->{passwdobj} )
                && defined(
                    $hash->{helper}->{passwdobj}->getReadPassword($name) ) );

            return 'Unknown argument ' . $cmd . ', choose one of ' . $list;
        }
    }

    return;
}

sub Attr {
    my ( $cmd, $name, $attr_name, $attr_value ) = @_;

    Log3( $name, 4,
        "Attr - $cmd - $name - $attr_name - "
          . ( defined($attr_value) && $attr_value ? $attr_value : '' ) );

    if ( $cmd eq 'set' ) {
        if ( $attr_name eq 'matrixQuestion_' ) {
            my @erg = split( / /, $attr_value, 2 );

            return qq("attr $name $attr_name" ) . _I18N('require2')
              if ( !$erg[1] );

            return
                qq("attr $name $attr_name" )
              . _I18N('question') . ' '
              . _I18N('beginWithNumber')
              if ( $erg[0] !~ /[0-9]/x );

            $_[2] = "matrixQuestion_$erg[0]";
            $_[3] = $erg[1];
        }

        if ( $attr_name eq 'matrixAnswer_' ) {
            my @erg = split( / /, $attr_value, 2 );

            return qq("attr $name $attr_name" ) . _I18N('require2')
              if ( !$erg[1] );

            return
                qq("attr $name $attr_name" )
              . _I18N('question') . ' '
              . _I18N('beginWithNumber')
              if ( $erg[0] !~ /[0-9]/x );

            $_[2] = "matrixAnswer_$erg[0]";
            $_[3] = $erg[1];
        }
    }

    return;
}

sub Login {
    my $hash = shift;

    return _PerformHttpRequest( $hash, 'login', '' );
}

sub _Get_Message {    # wir machen daraus eine privat function (CoolTux)
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $name    = shift;
    my $def     = shift;
    my $message = shift;

    Log3( $name, 3, "$name - $def - $message" );

    my $q         = AttrVal( $name, 'matrixQuestion_' . $def, '' );
    my $a         = AttrVal( $name, 'matrixAnswer_' . $def,   '' );
    my @questions = split( ':', $q );

    shift @questions if ( $def ne '99' );
    my @answers = split( ':', $a );

    Log3( $name, 3, "$name - $q - $a" );
    my $pos = 0;

    #my ($question, $answer);
    my $answer;

    # foreach my $question (@questions){
    foreach my $question (@questions) {
        Log3( $name, 3, "$name - $question - $answers[$pos]" );
        $answer = $answers[$pos] if ( $message eq $question );

        if ($answer) {
            Log3( $name, 3, "$name - $pos - $answer" );

            AnalyzeCommandChain( undef, $answer );
            last;
        }

        $pos++;
    }

    return;
}

sub _createParamRefForDataLogin {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return
qq({"type":"m.login.token", "token":"$createParamRefObj->{passwd}", "user": "$createParamRefObj->{hash}->{USER}", "txn_id": "z4567gerww", "session":"1234"})
      if (
        AttrVal( $createParamRefObj->{hash}->{NAME}, 'matrixLogin', '' ) eq
        'token' );

    return
'{"type":"m.login.password", "refresh_token": true, "identifier":{ "type":"m.id.user", "user":"'
      . $createParamRefObj->{hash}->{USER}
      . '" }, "password":"'
      . ( defined( $createParamRefObj->{passwd} )
          && $createParamRefObj->{passwd} ? $createParamRefObj->{passwd} : '' )
      . '"'
      . (
        defined( $createParamRefObj->{deviceId} )
          && $createParamRefObj->{deviceId}
        ? $createParamRefObj->{deviceId}
        : ''
      ) . '}';
}

sub _createParamRefForDataRegister {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return
      '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'
      . (
        defined( $createParamRefObj->{hash}->{USER} )
          && $createParamRefObj->{hash}->{USER}
        ? $createParamRefObj->{hash}->{USER}
        : ''
      )
      . '" }, "password":"'
      . (
        defined( $createParamRefObj->{passwd} )
          && $createParamRefObj->{passwd} ? $createParamRefObj->{passwd}
        : ''
      ) . '"}';
}

sub _createParamRefForDataReg1 {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return
      '{"type":"m.login.password", "identifier":{ "type":"m.id.user", "user":"'
      . (
        defined( $createParamRefObj->{hash}->{USER} )
          && $createParamRefObj->{hash}->{USER}
        ? $createParamRefObj->{hash}->{USER}
        : ''
      )
      . '" }, "password":"'
      . (
        defined( $createParamRefObj->{passwd} )
          && $createParamRefObj->{passwd} ? $createParamRefObj->{passwd}
        : ''
      ) . '"}';
}

sub _createParamRefForDataReg2 {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return '{"username":"'
      . (
        defined( $createParamRefObj->{hash}->{USER} )
          && $createParamRefObj->{hash}->{USER}
        ? $createParamRefObj->{hash}->{USER}
        : ''
      )
      . '", "password":"'
      . (
        defined( $createParamRefObj->{passwd} )
          && $createParamRefObj->{passwd} ? $createParamRefObj->{passwd}
        : ''
      )
      . '", "auth": {"session":"'
      . (
        defined( $createParamRefObj->{hash}->{helper}->{session} )
          && $createParamRefObj->{hash}->{helper}->{session}
        ? $createParamRefObj->{hash}->{helper}->{session}
        : ''
      ) . '","type":"m.login.dummy"}}';
}

sub _createParamRefForDataRefresh {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return '{"refresh_token": "'
      . (
        defined( $createParamRefObj->{hash}->{helper}->{refresh_token} )
          && $createParamRefObj->{hash}->{helper}->{refresh_token}
        ? $createParamRefObj->{hash}->{helper}->{refresh_token}
        : ''
      ) . '"}';
}

sub _createParamRefForUrlMsg {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    return
        'r0/rooms/'
      . AttrVal( $createParamRefObj->{hash}->{NAME}, 'matrixMessage', '!!' )
      . '/send/m.room.message?access_token='
      . (
          $createParamRefObj->{hash}->{helper}->{access_token}
        ? $createParamRefObj->{hash}->{helper}->{access_token}
        : ''
      );
}

sub _createParamRefForQuestionEnd {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;
    my $paramValue        = shift;

    my $value;
    $value = (
        exists( $createParamRefObj->{value} )
          && $createParamRefObj->{value}
        ? $createParamRefObj->{value}
        : ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'questionId', '' )
    );

    return
        'v3/rooms/'
      . AttrVal( $createParamRefObj->{hash}->{NAME}, 'matrixMessage', '!!' )
      . '/send/m.poll.end?access_token='
      . (
        defined(
            $createParamRefObj->{hash}->{helper}->{access_token}
              && $createParamRefObj->{hash}->{helper}->{access_token}
            ? $createParamRefObj->{hash}->{helper}->{access_token}
            : ''
        )
      ) if ( $paramValue eq 'urlPath' );

    return
        '{"m.relates_to": {"rel_type": "m.reference","eventId": "'
      . $value
      . '"},"org.matrix.msc3381.poll.end": {},'
      . '"org.matrix.msc1767.text": "Antort '
      . ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'answer', '' )
      . ' erhalten von '
      . ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'sender', '' ) . '"}'
      if ( $paramValue eq 'data' );

    return;
}

sub _createParamRefForFilter {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;
    my $paramValue        = shift;

    return
        'v3/user/'
      . ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'userId', 0 )
      . '/filter'
      . (
        exists( $createParamRefObj->{value} )
          && $createParamRefObj->{value} ? '/' . $createParamRefObj->{value}
        : ''
      )
      . '?access_token='
      . (
        defined( $createParamRefObj->{hash}->{helper}->{access_token} )
          && $createParamRefObj->{hash}->{helper}->{access_token}
        ? $createParamRefObj->{hash}->{helper}->{access_token}
        : ''
      ) if ( $paramValue eq 'urlPath' );

    return (
        $paramValue eq 'data'
          && exists( $createParamRefObj->{value} )
          && $createParamRefObj->{value}
        ? '{"event_fields": ["type","content","sender"],"event_format": "client", "presence": { "senders": [ "@xx:example.com"]}}'
        : ''
    );
}

sub _createParamRefForQuestion {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;
    my $paramValue        = shift;

    my $value = AttrVal( $createParamRefObj->{hash}->{NAME},
        'matrixQuestion_' . $createParamRefObj->{value}, '' )
      ;    #  if ($value =~ /[0-9]/);

    my @question = split( ':', $value );
    my $size     = @question;
    my $q        = shift @question;

    $value =~ s/:/<br>/gx;

    # min. question and one answer
    if ( int(@question) >= 2 ) {
        return
            'v3/rooms/'
          . AttrVal( $createParamRefObj->{hash}->{NAME}, 'matrixMessage', '!!' )
          . '/send/m.poll.start?access_token='
          . (
              $createParamRefObj->{hash}->{helper}->{access_token}
            ? $createParamRefObj->{hash}->{helper}->{access_token}
            : ''
          ) if ( $paramValue eq 'urlPath' );

        my $data =
            '{"org.matrix.msc3381.poll.start": {"max_selections": 1,'
          . '"question": {"org.matrix.msc1767.text": "'
          . $q . '"},'
          . '"kind": "org.matrix.msc3381.poll.undisclosed","answers": [';

        my $comma = '';

        for my $answer (@question) {
            $data .=
qq($comma {"id": "$answer", "org.matrix.msc1767.text": "$answer"});
            $comma = ',';
        }

        $data .=
qq(],"org.matrix.msc1767.text": "$value"}, "m.markup": [{"mimetype": "text/plain", "body": "$value"}]});

        return $data
          if ( $paramValue eq 'data' );
    }
    else {
        Log3( $createParamRefObj->{hash}->{NAME}, 5,
                'question: '
              . $value
              . $size
              . ( defined( $question[0] ) && $question[0] ? $question[0] : '' )
        );
        return;
    }

    return;
}

sub _createParamRefForUrlSync {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    my $since =
      ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'since', undef )
      ? '&since='
      . ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'since', undef )
      : '';

    my $full_state =
      ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'pollFullstate', undef );

    if ($full_state) {
        $full_state = '&full_state=true';
        readingsSingleUpdate( $createParamRefObj->{hash},
            'pollFullstate', 0, 1 );
    }
    else {
        $full_state = '';
    }

    return 'r0/sync?access_token='
      . (
          $createParamRefObj->{hash}->{helper}->{access_token}
        ? $createParamRefObj->{hash}->{helper}->{access_token}
        : ''
      )
      . $since
      . $full_state
      . '&timeout=50000&filter='
      . ReadingsVal( $createParamRefObj->{hash}->{NAME}, 'filterId', 0 );
}

sub _createParamRefForDef {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $def               = shift;
    my $paramValue        = shift;
    my $createParamRefObj = shift;

    my $paramref = {
        'logintypes' => {
            'urlPath' => 'r0/login',
            'method'  => 'GET',
        },

        'register' => {
            'urlPath' => 'v3/register',
            'data'    => _createParamRefForDataRegister($createParamRefObj),
        },

        'reg1' => {
            'urlPath' => 'v3/register',
            'data'    => _createParamRefForDataReg1($createParamRefObj),
        },

        'reg2' => {
            'urlPath' => 'v3/register',
            'data'    => _createParamRefForDataReg2($createParamRefObj),
        },

        'login' => {
            'urlPath' => 'v3/login',
            'data'    => _createParamRefForDataLogin($createParamRefObj),
        },

        'refresh' => {
            'urlPath' => 'v1/refresh',
            'data'    => _createParamRefForDataRefresh($createParamRefObj),
        },

        'wellknown' => {
            'urlPath' => '/.well-known/matrix/client',
            'data'    => undef,
        },

        'msg' => {
            'urlPath' => _createParamRefForUrlMsg($createParamRefObj),
            'data'    => '{"msgtype":"m.text", "body":"'
              . $createParamRefObj->{value} . '"}',
        },

        'questionEnd' => {
            'urlPath' =>
              _createParamRefForQuestionEnd( $createParamRefObj, 'urlPath' ),
            'data' =>
              _createParamRefForQuestionEnd( $createParamRefObj, 'data' ),
        },

        'filter' => {
            'urlPath' =>
              _createParamRefForFilter( $createParamRefObj, 'urlPath' ),
            'data' => _createParamRefForFilter( $createParamRefObj, 'data' ),
        },

        'question' => {
            'urlPath' =>
              _createParamRefForQuestion( $createParamRefObj, 'urlPath' ),
            'data' => _createParamRefForQuestion( $createParamRefObj, 'data' ),
        },

        'sync' => {
            'urlPath' => _createParamRefForUrlSync($createParamRefObj),
        },
    };

    return (
        exists( $paramref->{$def}->{$paramValue} )
          && $paramref->{$def}->{$paramValue}
        ? $paramref->{$def}->{$paramValue}
        : ''
    );
}

sub _createPerformHttpRequestHousekeepingParamObj {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)
    my $createParamRefObj = shift;

    my $param = {
        timeout => 10,
        hash    => $createParamRefObj->{hash}
        ,    # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
        def => $createParamRefObj->{def},  # sichern für eventuelle Wiederholung
        value => $createParamRefObj->{value}
        ,                                  # sichern für eventuelle Wiederholung
        method => 'POST',                  # standard, sonst überschreiben
        header => 'User-Agent: HttpUtils/2.2.3\r\nAccept: application/json'
        ,    # Den Header gemäß abzufragender Daten setzen
        msgnumber => $createParamRefObj->{msgnumber},    # lfd. Nummer Request
        callback  => \&ParseHttpResponse
        ,    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
    };

    return $param;
}

sub _PerformHttpRequest {    # wir machen daraus eine privat function (CoolTux)
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

#(CoolTux) hier solltest Du überlegen das Du die einzelnen Anweisung nach der Bedingung in einzelne Funktionen auslagerst
# Subroutine "_PerformHttpRequest" with high complexity score
#(Man-Fred) da ich noch nicht wusste wie ähnlich die Ergebnisse sind habe ich erst mal alles zusammen ausgewertet
    my $hash  = shift;
    my $def   = shift;
    my $value = shift;

    my $now  = gettimeofday();
    my $name = $hash->{NAME};
    my $passwd;

    Log3( $name, 4, "$name : Matrix::_PerformHttpRequest $hash" );

    $passwd =
      encode_utf8( $hash->{helper}->{passwdobj}->getReadPassword($name) )
      if ( $def eq 'login' || $def eq 'reg2' );

    $hash->{helper}->{msgnumber} =
      $hash->{helper}->{msgnumber} ? $hash->{helper}->{msgnumber} + 1 : 1;

    my $msgnumber = $hash->{helper}->{msgnumber};

    my $deviceId =
      ReadingsVal( $name, 'deviceId', undef )
      ? ', "device_id":"' . ReadingsVal( $name, 'deviceId', undef ) . '"'
      : '';

    $hash->{helper}->{busy} =
        $hash->{helper}->{busy}
      ? $hash->{helper}->{busy} + 1
      : 1;    # queue is busy until response is received

    $hash->{helper}->{sync} = 0
      if ( !$hash->{helper}->{sync} );

    $hash->{helper}->{LASTSEND} = $now;    # remember when last sent

    if (   $def eq "sync"
        && $hash->{helper}->{next_refresh} < $now
        && AttrVal( $name, 'matrixLogin', '' ) eq 'password' )
    {
        $def = 'refresh';

        Log3( $name, 5,
qq($name $hash->{helper}->{access_token} sync2refresh - $hash->{helper}->{next_refresh} < $now)
        );

        $hash->{helper}->{next_refresh} = $now + 300;
    }

    my $createParamRefObj = {
        hash      => $hash,
        def       => $def,
        value     => $value,
        now       => $now,
        passwd    => $passwd,
        msgnumber => $msgnumber,
        deviceId  => $deviceId,
    };

    my $param =
      _createPerformHttpRequestHousekeepingParamObj($createParamRefObj);

    given ($def) {
        when ('logintypes') {
            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );
            $param->{method} =
              _createParamRefForDef( $def, 'method', $createParamRefObj );
        }

        when ('login2') {
            $param->{url} = $hash->{URL} . 'v3/login';
            if ( AttrVal( $name, 'matrixLogin', '' ) eq 'token' ) {
                $param->{data} =
qq({"type":"m.login.token", "token":"$passwd", "user": "\@$hash->{USER}:matrix.org", "txn_id": "z4567gerww"});

            #$param->{'data'} = qq({"type":"m.login.token", "token":"$passwd"});
            }
        }

        when ('questionX') {
            $hash->{helper}->{question} = $value;
            $value = AttrVal( $name, 'matrixQuestion_' . $value, '' )
              ;    #  if ($value =~ /[0-9]/);

            my @question = split( ':', $value );
            my $size     = @question;
            my $q        = shift @question;

            $value =~ s/:/<br>/gx;

            # min. question and one answer
            if ( int(@question) >= 2 ) {
                $param->{url} =
                    $hash->{URL}
                  . 'v3/rooms/'
                  . AttrVal( $name, 'matrixMessage', '!!' )
                  . '/send/m.poll.start?access_token='
                  . $hash->{helper}->{access_token};

                $param->{data} =
'{"type":"m.poll.start", "content":{"m.poll": {"max_selections": 1,'
                  . '"question": {"org.matrix.msc1767.text": "'
                  . $q . '"},'
                  . '"kind": "org.matrix.msc3381.poll.undisclosed","answers": [';

                my $comma = '';

                for my $answer (@question) {
                    $param->{data} .=
qq($comma {"id": "$answer", "org.matrix.msc1767.text": "$answer"});
                    $comma = ',';
                }

                $param->{data} .=
qq(],"org.matrix.msc1767.text": "$value"}, "m.markup": [{"mimetype": "text/plain", "body": "$value"}]}});
            }
            else {
                Log3( $name, 5, "question: $value $size $question[0]" );
                return;
            }
        }

        when ('question') {
            $hash->{helper}->{question} = $value;

            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );
            $param->{data} =
              _createParamRefForDef( $def, 'data', $createParamRefObj );
        }

        when ('sync') {
            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );

            $param->{method}  = 'GET';
            $param->{timeout} = 60;
            $hash->{helper}->{sync}++;

            Log3( $name, 5,
qq($name $hash->{helper}->{access_token} syncBeg $param->{'msgnumber'}: $hash->{helper}->{next_refresh} > $now)
            );
        }

        when ('filter') {
            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );
            $param->{data} =
              _createParamRefForDef( $def, 'data', $createParamRefObj );

            $param->{method} = 'GET'
              if ($value);
        }

        when ('refresh') {
            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );
            $param->{data} =
              _createParamRefForDef( $def, 'data', $createParamRefObj );

            Log3( $name, 5,
qq($name $hash->{helper}->{access_token} refreshBeg $param->{'msgnumber'}: $hash->{helper}->{next_refresh} > $now)
            );
        }

        default {
            $param->{url} = $hash->{URL}
              . _createParamRefForDef( $def, 'urlPath', $createParamRefObj );
            $param->{data} =
              _createParamRefForDef( $def, 'data', $createParamRefObj );

            $param->{method} = 'GET'
              if ( $def eq 'filter' && $value );

        }
    }

    my $test =
        $param->{url} . ','
      . ( $param->{data}   ? "\r\ndata: $param->{data}, "   : '' )
      . ( $param->{header} ? "\r\nheader: $param->{header}" : '' );

#readingsSingleUpdate($hash, "fullRequest", $test, 1);                                                        # Readings erzeugen
    $test = "$name: Matrix sends with timeout $param->{timeout} to $test";
    Log3( $name, 5, $test );

    Log3( $name, 3,
qq($name $param->{'msgnumber'} $def Request Busy/Sync $hash->{helper}->{busy} / $hash->{helper}->{sync})
    );

    HttpUtils_NonblockingGet($param)
      ;    #  Starten der HTTP Abfrage. Es gibt keinen Return-Code.

    return;
}

sub _ParseHttpResponseWithError {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $hash  = shift;
    my $param = shift;
    my $err   = shift;

    my $name = $hash->{NAME};

    Log3( $name, 2, "error while requesting " . $param->{url} . " - $err" )
      ;    # Eintrag fürs Log

    readingsBulkUpdate( $hash, 'lastRespErr', $err );    # Reading erzeugen
    readingsBulkUpdate( $hash, 'state', 'Error - look lastRespErr reading' );
    $hash->{helper}->{softfail} = 3;
    $hash->{helper}->{hardfail}++;

    return;
}

sub _ParseHttpResponseErrorCodeCheck {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $param = shift;
    my $data  = shift;
    my $now   = shift;

    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if ( $param->{code} == 200 ) {
        $hash->{helper}->{softfail} = 0;
        $hash->{helper}->{hardfail} = 0;
    }
    else {
        $hash->{helper}->{softfail}++;
        $hash->{helper}->{hardfail}++
          if ( $hash->{helper}->{softfail} > 3 );
        readingsBulkUpdate( $hash, 'lastRespErr',
            qq(S $hash->{helper}->{'softfail'}: $data) );
        Log3( $name, 5,
qq($name $hash->{helper}->{access_token} $param->{def}End $param->{'msgnumber'}: $hash->{helper}->{next_refresh} > $now)
        );
    }

    return;
}

sub _ParseHttpResponseM_UNKNOWN_TOKEN {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $param       = shift;
    my $decoded     = shift;
    my $nextRequest = shift;

    my $hash = $param->{hash};

    my $errcode = $decoded->{'errcode'} ? $decoded->{'errcode'} : '';
    if ( $errcode eq 'M_UNKNOWN_TOKEN' ) {
        $hash->{helper}->{'repeat'} = $param
          if ( $param->{def} ne 'sync' );

        if ( $decoded->{'error'} eq 'Access token has expired' ) {
            if ( $decoded->{'soft_logout'} eq 'true' ) {
                $nextRequest = 'refresh';
            }
            else {
                $nextRequest = 'login';
            }
        }
        elsif ( $decoded->{'error'} eq 'refresh token does not exist' ) {
            $nextRequest = 'login';
        }
    }

    return $nextRequest;
}

sub _ParseHttpResponseReg2LoginRefresh {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $param   = shift;
    my $decoded = shift;
    my $now     = shift;

    my $hash = $param->{hash};
    my $name = $hash->{NAME};
    my $def  = $param->{def};

    readingsBulkUpdate( $hash, 'lastRegister', $param->{code} )
      if $def eq 'reg2';
    readingsBulkUpdate( $hash, 'lastLogin', $param->{code} )
      if $def eq 'login';
    readingsBulkUpdate( $hash, 'lastRefresh', $param->{code} )
      if $def eq 'refresh';

    if ( $param->{code} == 200 ) {
        readingsBulkUpdate( $hash, 'userId', $decoded->{user_id} )
          if ( $decoded->{user_id} );
        readingsBulkUpdate( $hash, 'homeServer', $decoded->{homeServer} )
          if ( $decoded->{homeServer} );
        readingsBulkUpdate( $hash, 'deviceId', $decoded->{device_id} )
          if ( $decoded->{device_id} );

        $hash->{helper}->{expires} = $decoded->{expires_in_ms}
          if ( $decoded->{expires_in_ms} );
        $hash->{helper}->{refresh_token} = $decoded->{refresh_token}
          if ( $decoded->{refresh_token} );
        $hash->{helper}->{access_token} = $decoded->{access_token}
          if ( $decoded->{access_token} );
        $hash->{helper}->{next_refresh} =
          $now + $hash->{helper}->{expires} / 1000 -
          60;    # refresh one minute before end
    }

    Log3( $name, 5,
qq($name $hash->{helper}->{access_token} refreshEnd $param->{msgnumber}: $hash->{helper}->{'next_refresh'} > $now)
    );

    return;
}

sub _ParseHttpResponseSync {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $param       = shift;
    my $decoded     = shift;
    my $nextRequest = shift;
    my $now         = shift;

    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    given ( $param->{code} ) {
        when (200) {
            Log3( $name, 5,
qq($name $hash->{helper}->{"access_token"} syncEnd $param->{msgnumber}: $hash->{helper}->{'next_refresh'} > $now)
            );
            readingsBulkUpdate( $hash, 'since', $decoded->{next_batch} )
              if ( $decoded->{next_batch} );

            # roomlist
            my $list = $decoded->{rooms}->{join};

            #my @roomlist = ();
            my $pos = 0;
            for my $id ( keys $list->%* ) {
                if ( ref $list->{$id} eq ref {} ) {
                    my $member = '';

                    #my $room = $list->{$id};
                    $pos = $pos + 1;

                    # matrixRoom ?
                    readingsBulkUpdate( $hash, 'room' . $pos . '.id', $id );

#for my $id ( $decoded->{'rooms'}->{'join'}->{AttrVal($name, 'matrixRoom', '!!')}->{'timeline'}->{'events'}->@* ) {
                    for my $ev ( $list->{$id}->{state}->{events}->@* ) {
                        readingsBulkUpdate(
                            $hash,
                            'room' . $pos . '.topic',
                            $ev->{content}->{topic}
                        ) if ( $ev->{type} eq 'm.room.topic' );

                        readingsBulkUpdate(
                            $hash,
                            'room' . $pos . '.name',
                            $ev->{content}->{name}
                        ) if ( $ev->{type} eq 'm.room.name' );

                        $member .= $ev->{sender} . ' '
                          if ( $ev->{type} eq 'm.room.member' );
                    }

                    readingsBulkUpdate( $hash,
                        'room' . $pos . '.member', $member );

                    for my $tl ( $list->{$id}->{timeline}->{events}->@* ) {
                        readingsBulkUpdate(
                            $hash,
                            'room' . $pos . '.topic',
                            $tl->{content}->{topic}
                        ) if ( $tl->{type} eq 'm.room.topic' );

                        readingsBulkUpdate(
                            $hash,
                            'room' . $pos . '.name',
                            $tl->{content}->{name}
                        ) if ( $tl->{type} eq 'm.room.name' );

                        if (   $tl->{type} eq 'm.room.message'
                            && $tl->{content}->{msgtype} eq 'm.text' )
                        {
                            my $sender = $tl->{sender};
                            my $message =
                              encode_utf8( $tl->{content}->{body} );

                            if ( AttrVal( $name, 'matrixSender', '' ) =~
                                $sender )
                            {
                                readingsBulkUpdate( $hash,
                                    "message", $message );
                                readingsBulkUpdate( $hash, "sender", $sender );

                                # command
                                _Get_Message( $name, '99', $message );
                            }

#else {
#    readingsBulkUpdate($hash, "message", 'ignoriert, nicht '.AttrVal($name, 'matrixSender', ''));
#    readingsBulkUpdate($hash, "sender", $sender);
#}
                        }
                        elsif (
                            $tl->{type} eq 'org.matrix.msc3381.poll.response' )
                        {
                            my $sender = $tl->{sender};
                            my $message =
                              encode_utf8( $tl->{content}
                                  ->{'org.matrix.msc3381.poll.response'}
                                  ->{answers}[0] );

                            if ( $tl->{content}->{'m.relates_to'} ) {
                                if (

                                    $tl->{content}->{'m.relates_to'}->{rel_type}
                                    eq 'm.reference'
                                  )
                                {
                                    readingsBulkUpdate( $hash, 'questionId',
                                        $tl->{content}->{'m.relates_to'}
                                          ->{event_id} );
                                }
                            }

                            if ( AttrVal( $name, 'matrixSender', '' ) =~
                                $sender )
                            {
                                readingsBulkUpdate( $hash,
                                    'message', $message );

                                readingsBulkUpdate( $hash, 'sender', $sender );
                                $nextRequest = 'questionEnd';

                                # command
                                _Get_Message( $name,
                                    $hash->{helper}->{question}, $message );
                            }
                        }
                    }

                    #push(@roomlist,"$id: ";
                }
            }
        }
    }

    return;
}

sub _ParseHttpResponseLogintypes {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $hash    = shift;
    my $decoded = shift;

    my $types = '';
    foreach my $flow ( $decoded->{'flows'}->@* ) {
        if ( $flow->{'type'} =~ /m\.login\.(.*)/x ) {

            #$types .= $flow->{'type'} . ' ';
            $types .= $1 . ' ';    # if ($flow->{'type'} );
        }
    }

    readingsBulkUpdate( $hash, 'logintypes', $types );

    return;
}

sub ParseHttpResponse {

#(CoolTux) hier solltest Du überlegen das Du die einzelnen Anweisung nach der Bedingung in einzelne Funktionen auslagerst
# Subroutine "_PerformHttpRequest" with high complexity score
#(Man-Fred) da ich noch nicht wusste wie ähnlich die Ergebnisse sind habe ich erst mal alles zusammen ausgewertet

    my $param = shift;
    my $err   = shift;
    my $data  = shift;

    my $hash        = $param->{hash};
    my $def         = $param->{def};
    my $value       = $param->{value};
    my $name        = $hash->{NAME};
    my $now         = gettimeofday();
    my $nextRequest = "";

    Log3( $name, 3,
        qq($name $param->{'msgnumber'} $def Result $param->{code}) );
    readingsBeginUpdate($hash);
    ###readingsBulkUpdate($hash, "httpHeader", $param->{httpheader});
    readingsBulkUpdate( $hash, 'httpStatus', $param->{code} );
    readingsBulkUpdate( $hash, 'state',      $def . ' - ' . $param->{code} );

    if ( $err ne '' ) {   # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        _ParseHttpResponseWithError( $hash, $param, $err );
    }

    elsif ( $data ne '' )
    { # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
        Log3( $name, 4, $def . " returned: $data" );    # Eintrag fürs Log

        my $decoded = eval { decode_json($data) };
        if ($@) {
            Log3( $name, 2, "$name: json error: $@ in data" );
        }

        _ParseHttpResponseErrorCodeCheck( $param, $data, $now );

        # readingsBulkUpdate($hash, "fullResponse", $data);

        # default next request
        $nextRequest = 'sync';

        # An dieser Stelle die Antwort parsen / verarbeiten mit $data

        # "errcode":"M_UNKNOWN_TOKEN: login or refresh
        $nextRequest =
          _ParseHttpResponseM_UNKNOWN_TOKEN( $param, $decoded, $nextRequest );

        given ($def) {

            when ('register') {
                $hash->{helper}->{session} = $decoded->{session};
                $nextRequest = '';                                  #'reg2';
            }

            $hash->{helper}->{session} = $decoded->{session}
              if ( $decoded->{'session'} );
            readingsBulkUpdate( $hash, 'session', $decoded->{session} )
              if ( $decoded->{'session'} );

            when (/^reg2|login|refresh$/x) {
                _ParseHttpResponseReg2LoginRefresh( $param, $decoded, $now );
            }

            when ('wellknown') {

                # https://spec.matrix.org/unstable/client-server-api/
            }

            when ('sync') {
                _ParseHttpResponseSync( $param, $decoded, $nextRequest, $now );
            }

            when ('logintypes') {
                _ParseHttpResponseLogintypes( $hash, $decoded );
            }

            when ('filter') {
                readingsBulkUpdate( $hash, 'filterId', $decoded->{'filter_id'} )
                  if ( $decoded->{'filter_id'} );
            }

            when ('msg') {
                readingsBulkUpdate( $hash, 'eventId', $decoded->{'event_id'} )
                  if ( $decoded->{'event_id'} );

                #m.relates_to
            }

            when ('question') {
                readingsBulkUpdate( $hash, 'questionId',
                    $decoded->{'event_id'} )
                  if ( $decoded->{'event_id'} );

                #m.relates_to
            }

            when ('questionEnd') {
                readingsBulkUpdate( $hash, 'eventId', $decoded->{'event_id'} )
                  if ( $decoded->{'event_id'} );
                readingsBulkUpdate( $hash, 'questionId', '' )
                  if ( $decoded->{'event_id'} );

                #m.relates_to
            }

        }
    }

    readingsEndUpdate( $hash, 1 );

    $hash->{helper}->{busy}
      --; # = $hash->{helper}->{busy} - 1;      # queue is busy until response is received

    $hash->{helper}->{sync}-- if ( $def eq "sync" );    # possible next sync
    $nextRequest = ''
      if ( $nextRequest eq 'sync' && $hash->{helper}->{sync} > 0 )
      ;    # only one sync at a time!

    # _PerformHttpRequest or InternalTimer if FAIL >= 3
    _PerformHttpRequestOrInternalTimerFAIL( $hash, $def, $value, $nextRequest );

    return;
}

sub _PerformHttpRequestOrInternalTimerFAIL {
    return 0
      unless ( __PACKAGE__ eq caller(0) )
      ;    # nur das eigene Package darf private Funktionen aufrufen (CoolTux)

    my $hash        = shift;
    my $def         = shift;
    my $value       = shift;
    my $nextRequest = shift;

    my $name = $hash->{NAME};

    Log3( $name, 4, "$name : Matrix::ParseHttpResponse $hash" );
    if ( AttrVal( $name, 'matrixPoll', 0 ) == 1 ) {
        if ( $nextRequest ne '' && $hash->{helper}->{softfail} < 3 ) {
            if ( $nextRequest eq 'sync' && $hash->{helper}->{repeat} ) {
                $def                      = $hash->{helper}->{repeat}->{def};
                $value                    = $hash->{helper}->{repeat}->{value};
                $hash->{helper}->{repeat} = undef;
                _PerformHttpRequest( $hash, $def, $value );
            }
            else {
                _PerformHttpRequest( $hash, $nextRequest, '' );
            }
        }
        elsif ( $hash->{helper}->{softfail} == 0 ) {

            # nichts tun, doppelter sync verhindert
        }
        else {
            my $pauseLogin;
            if ( $hash->{helper}->{hardfail} >= 3 ) {
                $pauseLogin = 300;    # lange Pause wenn zu viele Fehler
            }
            elsif ( $hash->{helper}->{softfail} >= 3 ) {
                $pauseLogin = 30; # kurze Pause nach drei Fehlern oder einem 400
            }
            else {
                $pauseLogin = 10;    # nach logischem Fehler ganz kurze Pause
            }

            RemoveInternalTimer($hash);
            InternalTimer( gettimeofday() + $pauseLogin,
                \&FHEM::Devices::Matrix::Client::Login, $hash );
        }
    }

    return;
}

1;    #(CoolTux) ein Modul endet immer mit 1;

__END__        #(CoolTux) Markiert im File das Ende des Programms. Danach darf beliebiger Text stehen. Dieser wird vom Perlinterpreter nicht berücksichtigt.
