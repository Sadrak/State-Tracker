use strict;
use Test::More 0.98;

my $class_normal = "State::Tracker";
my $class_binary = "State::Tracker::Binary";

use_ok $_ for $class_normal, $class_binary;

foreach my $class ($class_normal, $class_binary) {

    my $flag1     = $class eq $class_normal ? "a"     : 1;
    my $flag2     = $class eq $class_normal ? "b"     : 2;
    my $flag3     = $class eq $class_normal ? "c"     : 4;
    my $flag1a1   = $class eq $class_normal ? "a|a"   : 1|1;
    my $flag1a2   = $class eq $class_normal ? "a|b"   : 1|2;
    my $flag1a3   = $class eq $class_normal ? "a|c"   : 1|4;
    my $flag2a3   = $class eq $class_normal ? "b|c"   : 2|4;
    my $flag1a2a3 = $class eq $class_normal ? "a|b|c" : 1|2|4;

    subtest "basic", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            enabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );
                           is($executed, 0);
        $tracker < $flag1; is($executed, 1);
        $tracker < $flag1; is($executed, 1);
        $tracker < $flag2; is($executed, 1);
        $tracker > $flag1; is($executed, 1);
        $tracker < $flag1; is($executed, 2);
    };

    subtest "argument", sub {
        my $tracker = new_ok $class;

        my $executed;
        $tracker->track(
            enabled => $flag1,
            sub {
                $executed = pop;
                return 1;
            },
        );
                                    is_deeply($executed, undef);
        $tracker < $flag1;          is_deeply($executed, $flag1);
        $tracker > $flag1;          is_deeply($executed, $flag1);
        $tracker < [$flag1,$flag2]; is_deeply($executed, [$flag1, $flag2]);

    };

    subtest "not direct", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            disabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );
                           is($executed, 0);
        $tracker < $flag1; is($executed, 0);
        $tracker > $flag1; is($executed, 1);
    };

    subtest "not changed", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            disabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );
                           is($executed, 0);
        $tracker < $flag2; is($executed, 0);
        $tracker < $flag1; is($executed, 0);
        $tracker > $flag1; is($executed, 1);
    };

    subtest "stop", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            enabled => $flag1,
            sub {
                $executed++;
                return 0;
            },
        );
                           is($executed, 0);
        $tracker < $flag1; is($executed, 1);
        $tracker > $flag1; is($executed, 1);
        $tracker < $flag1; is($executed, 1);
    };

    subtest "negative", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            disabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );
        $tracker < $flag1; is($executed, 0);
        $tracker < $flag1; is($executed, 0);
        $tracker > $flag1; is($executed, 1);
    };

    subtest "both", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            enabled  => $flag1,
            disabled => $flag2,
            sub {
                $executed++;
                return 1;
            },
        );
                           is($executed, 0);
        $tracker < $flag1; is($executed, 1);
        $tracker < $flag2; is($executed, 1);
        $tracker < $flag1; is($executed, 1);
        $tracker > $flag1; is($executed, 1);
        $tracker < $flag1; is($executed, 1);
        $tracker > $flag2; is($executed, 2);
    };

    subtest "counter", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            enabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );
                           is($executed, 0);
        $tracker < $flag1; is($executed, 1);
        $tracker + $flag1; is($executed, 2);
        $tracker + $flag1; is($executed, 3);
        $tracker - $flag1; is($executed, 4);
        $tracker - $flag1; is($executed, 5);
        $tracker - $flag1; is($executed, 5);
    };

    subtest "complex", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->set($flag1, 4);
        $tracker->set($flag2, 2);
        $tracker->track(
            enabled  => $flag1,
            disabled => $flag2,
            sub {
                $executed++;
                return 1;
            },
        );

                                    is($executed, 0);
        $tracker - $flag1a2; is($executed, 0);
        $tracker - $flag1a2; is($executed, 1);
        $tracker - $flag1a2; is($executed, 2);
        $tracker - $flag1a2; is($executed, 2);
    };

    subtest "set", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->set($flag1, 1);
        $tracker->track(
            enabled => $flag1,
            sub {
                $executed++;
                return 1;
            },
        );

                                  is($executed, 0);
        $tracker->set($flag1, 1); is($executed, 0);
        $tracker->set($flag1, 2); is($executed, 1);
        $tracker->set($flag1, 0); is($executed, 1);
    };

    subtest "tracker in tracker", sub {
        my $tracker = new_ok $class;

        my $executed = 0;
        $tracker->track(
            enabled => $flag1,
            sub {
                my ($self, $changed) = @_;
                $executed++;
                $self->track(
                    disabled => $flag2,
                    sub {
                        $executed++;
                        return 0;
                    },
                );
                return 0;
            },
        );

                           is($executed, 0);
        $tracker < $flag2; is($executed, 0);
        $tracker < $flag1; is($executed, 1);
        $tracker > $flag2; is($executed, 2);
    };
}

done_testing;

