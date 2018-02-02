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

subtest "enable & disable", sub {
    my $tracker = new_ok "State::Tracker";

    ok($tracker == 0);
    ok($tracker->enable($flag1));
    ok($tracker == 1);
    ok(!$tracker->enable($flag1));
    ok($tracker == 1);
    ok($tracker->disable($flag1));
    ok($tracker == 0);
    ok(!$tracker->disable($flag1));
    ok($tracker == 0);

    ok($tracker->enable("$flag2|$flag3"));
    ok($tracker == 6);

    ok($tracker->disable("$flag1|$flag3"));
    ok($tracker == 2);
};

subtest "toggle", sub {
    my $tracker = new_ok "State::Tracker";

    ok($tracker == 0);
    ok($tracker->toggle($flag1));
    ok($tracker == 1);
    ok($tracker->toggle($flag1));
    ok($tracker == 0);
    ok($tracker->toggle("$flag1|$flag1"));
    ok($tracker == 1);
    ok($tracker->toggle("$flag1|$flag2"));
    ok($tracker == 2);
};

subtest "counter", sub {
    my $tracker = new_ok "State::Tracker";

    ok($tracker == 0);
    is($tracker->increment($flag1), 1);
    ok($tracker == 1);
    is($tracker->counter($flag1), 1);
    is($tracker->increment($flag1), 1);
    ok($tracker == 1);
    is($tracker->counter($flag1), 2);
    is($tracker->increment($flag1, 2), 2);
    ok($tracker == 1);
    is($tracker->counter($flag1), 4);
    is($tracker->increment("$flag1|$flag2"), 2);
    ok($tracker == 3);
    is($tracker->counter($flag1), 5);
    is($tracker->decrement($flag1, 5), 5);
    ok($tracker == 2);
    is($tracker->counter($flag1), 0);
    is($tracker->decrement($flag1, 5), 5);
    ok($tracker == 2);
    is($tracker->counter($flag1), -5);

    # not sure if not changing the counter after enable is the best way
    ok($tracker->enable($flag1));
    ok($tracker == 3);
    is($tracker->counter($flag1), -5);
    is($tracker->increment($flag1), 1);
    ok($tracker == 3);
    is($tracker->counter($flag1), -4);
    is($tracker->decrement($flag1), 1);
    ok($tracker == 2);
    is($tracker->counter($flag1), -5);
};

subtest "overload", sub {
    my $tracker = new_ok "State::Tracker";

    ok($tracker == 0);
    ok($tracker < $flag1);
    ok($tracker == 1);
    ok(!($tracker < $flag1));
    ok($tracker == 1);
    ok($tracker > $flag1);
    ok($tracker == 0);
    ok(!($tracker > $flag1));
    ok($tracker == 0);
    ok($tracker * $flag1);
    ok($tracker == 1);
    ok($tracker * "$flag1|$flag2");
    ok($tracker == 2);

    ok($tracker + $flag1);
    is($tracker->counter($flag1), 1);

    ok($tracker + [ $flag1 => 2 ]);
    is($tracker->counter($flag1), 3);
};

subtest "argument", sub {
    my $tracker = new_ok "State::Tracker" => [$flag2];

    ok($tracker == 2);
};

subtest "stringify", sub {
    my $tracker = new_ok "State::Tracker";

    ok($tracker == 0);
    is($tracker->decrement($flag1, 5), 5);
    ok($tracker == 0);
    is("$tracker", "0;a=-5");
};



done_testing;

