use strict;
use Test::More 0.98;

use_ok $_ for qw(
    State::Tracker
);

my $flag1 = "a";
my $flag2 = "b";
my $flag3 = "c";
use constant FLAGa => 1;
use constant FLAGb => 2;
use constant FLAGc => 4;

subtest "basic", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->callback(
        sub {
            $executed++;
            return 1;
        },
        $flag1,
    );
    $tracker < $flag1;
    is($executed, 1);
    $tracker < $flag1;
    is($executed, 1);
    $tracker < $flag2;
    is($executed, 1);
    $tracker > $flag1;
    is($executed, 1);
    $tracker < $flag1;
    is($executed, 2);
};

subtest "stop", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->callback(
        sub {
            $executed++;
            return 0;
        },
        $flag1,
    );
    $tracker < $flag1;
    is($executed, 1);
    $tracker > $flag1;
    is($executed, 1);
    $tracker < $flag1;
    is($executed, 1);
};

subtest "negative", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->callback(
        sub {
            $executed++;
            return 1;
        },
        "~$flag1",
    );
    $tracker < $flag1;
    is($executed, 0);
    $tracker > $flag1;
    is($executed, 1);
};

subtest "both", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->callback(
        sub {
            $executed++;
            return 1;
        },
        $flag1,
        "~$flag2",
    );
    $tracker < $flag2;
    is($executed, 0);
    $tracker < $flag1;
    is($executed, 0);
    $tracker > $flag1;
    is($executed, 0);
    $tracker > $flag2;
    is($executed, 0);
    $tracker < $flag1;
    is($executed, 1);
};

subtest "counter", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->callback(
        sub {
            $executed++;
            return 1;
        },
        [$flag1 => '<=' => 2],
    );
    $tracker + $flag1;
    is($executed, 0);
    $tracker + $flag1;
    is($executed, 1);
};

# subtest "callback", sub {
#     my $tracker = new_ok "State::Tracker";
# 
#     my $executed = 0;
#     $tracker->callback(
#         sub {
#             $executed++;
#         },
#         "$flag1",
#         "-$flag2",
# 
# 
#     );
#     $tracker << $flag1;
#     is($executed, 1);
#     $tracker << $flag1;
#     is($executed, 2);
# };



done_testing;
__END__

FLAG1,
~FLAG2,
{FLAG3 => 30},
{FLAG4 => { '<=' => -40 },

FLAG1|-FLAG2|FLAG3==30|-FLAG4<=-40

"$flag1|-$flag2|$flag3==30|-$flag4<=-40"
"$flag1|-$flag2|$flag3==30|-$flag4<=-40"
