use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Compare qw{is U};

InternalTimer(time()+1, sub() {
    my %hash;
    $hash{TEMPORARY} = 1;
    $hash{NAME}  = q{dummyMatrix};
    $hash{TYPE}  = q{Matrix server user};
    $hash{STAE}  = q{???};

    subtest "Matrix Test checking define" => sub {
        $hash{DEF}   = "pass";
        plan(2);
        my $ret = Matrix_Define(\%hash,qq{$hash{NAME} $hash{TYPE}});
        like ($ret, qr/too few parameters: define <name> Matrix <greet>/, 'check error message Matrix_Define');

        $ret = Matrix_Define(\%hash,qq{$hash{NAME} $hash{TYPE} $hash{DEF}});
        is ($ret, U(), 'check returnvalue Matrix_Define');
    };



    done_testing();
    exit(0);

}, 0);

1;