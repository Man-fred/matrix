use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Compare qw{is U};

InternalTimer(time()+1, sub() {
    my %hash;
    $hash{TEMPORARY} = 1;
    $hash{NAME}  = q{hallo};
    $hash{TYPE}  = q{Hello};
    $hash{STAE}  = q{???};

    subtest "Demo Test checking define" => sub {
        $hash{DEF}   = "howdy";
        plan(2);
        my $ret = Hello_Define(\%hash,qq{$hash{NAME} $hash{TYPE}});
        like ($ret, qr/too few parameters: define <name> Hello <greet>/, 'check error message Hello_Define');

        $ret = Hello_Define(\%hash,qq{$hash{NAME} $hash{TYPE} $hash{DEF}});
        is ($ret, U(), 'check returnvalue Hello_Define');
    };



    done_testing();
    exit(0);

}, 0);

1;