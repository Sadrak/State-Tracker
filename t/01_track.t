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
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        $flag1,
    );
                       is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker < $flag1; is($executed, 1);
    $tracker < $flag2; is($executed, 1);
    $tracker > $flag1; is($executed, 1);
    $tracker < $flag1; is($executed, 2);
};

subtest "direct", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        "~$flag1",
    );
    is($executed, 1);
};

subtest "stop", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            $executed++;
            return 0;
        },
        $flag1,
    );
                       is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker < $flag1; is($executed, 1);
    $tracker > $flag1; is($executed, 1);
    $tracker < $flag1; is($executed, 1);
};

subtest "negative", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        "~$flag1",
    );
                       is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker < $flag1; is($executed, 0);
    $tracker > $flag1; is($executed, 1);
};

subtest "both", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        $flag1,
        "~$flag2",
    );
                       is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker < $flag2; is($executed, 0);
    $tracker < $flag1; is($executed, 0);
    $tracker > $flag1; is($executed, 0);
    $tracker > $flag2; is($executed, 0);
    $tracker < $flag1; is($executed, 1);
};

subtest "counter", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        $flag1,
    );
                       is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker + $flag1; is($executed, 1);
    $tracker + $flag1; is($executed, 2);
    $tracker - $flag1; is($executed, 3);
    $tracker - $flag1; is($executed, 3);
};

subtest "complex", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->set($flag1, 4);
    $tracker->set($flag2, 2);
    $tracker->track(
        sub {
            $executed++;
            return 1;
        },
        "$flag1",
        "~$flag2",
    );

                                is($executed, 0);
    $tracker - "$flag1|$flag2"; is($executed, 0);
    $tracker - "$flag1|$flag2"; is($executed, 1);
    $tracker - "$flag1|$flag2"; is($executed, 2);
    $tracker - "$flag1|$flag2"; is($executed, 2);

    
};

subtest "tracker in tracker", sub {
    my $tracker = new_ok "State::Tracker";

    my $executed = 0;
    $tracker->track(
        sub {
            my ($self, $changed) = @_;
            $executed++;
            $self->track(
                sub {
                    $executed++;
                    return 0;
                },
                "~$flag2",
            );
            return 0;
        },
        $flag1,
    );

                       is($executed, 0);
    $tracker < $flag2; is($executed, 0);
    $tracker < $flag1; is($executed, 1);
    $tracker > $flag2; is($executed, 2);
};

done_testing;

