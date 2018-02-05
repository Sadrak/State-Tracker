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

    subtest "$class: enable & disable", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);

        ok($tracker->enable($flag1));   ok($tracker == 1);
        ok(!$tracker->enable($flag1));  ok($tracker == 1);
        ok($tracker->disable($flag1));  ok($tracker == 0);
        ok(!$tracker->disable($flag1)); ok($tracker == 0);

        ok($tracker->enable($flag2a3));  ok($tracker == 6);
        ok($tracker->disable($flag1a3)); ok($tracker == 2);

        ok($tracker->enable([$flag2, $flag3]));  ok($tracker == 6);
        ok($tracker->disable([$flag1, $flag3])); ok($tracker == 2);
    };

    subtest "$class: toggle", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);

        ok($tracker->toggle($flag1)); ok($tracker == 1);
        ok($tracker->toggle($flag1)); ok($tracker == 0);

        ok($tracker->toggle($flag1a1)); ok($tracker == 1);
        ok($tracker->toggle($flag1a2)); ok($tracker == 2);

        ok($tracker->toggle([$flag1, $flag1])); ok($tracker == 3);
        ok($tracker->toggle([$flag1, $flag2])); ok($tracker == 0);
    };

    subtest "$class: increment & decrement", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);
        is($tracker->counter($flag1), 0);

        is($tracker->increment($flag1), 1);              ok($tracker == 1); is($tracker->counter($flag1), 1);
        is($tracker->increment($flag1), 1);              ok($tracker == 1); is($tracker->counter($flag1), 2);
        is($tracker->increment($flag1, 2), 2);           ok($tracker == 1); is($tracker->counter($flag1), 4);
        is($tracker->decrement($flag1a2, 4), 8);         ok($tracker == 0); is($tracker->counter($flag1), 0);  is($tracker->counter($flag2), -4);

        is($tracker->decrement([$flag1, $flag2], 2), 4); ok($tracker == 0); is($tracker->counter($flag1), -2); is($tracker->counter($flag2), -6);
        is($tracker->increment([$flag1, $flag2], 2), 4); ok($tracker == 0); is($tracker->counter($flag1), 0);  is($tracker->counter($flag2), -4);
    };

    subtest "$class: set", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);
        is($tracker->counter($flag1), 0);

        is($tracker->set($flag1, 3), 3);   ok($tracker == 1); is($tracker->counter($flag1), 3);
        is($tracker->set($flag1, -3), -3); ok($tracker == 0); is($tracker->counter($flag1), -3);
        is($tracker->set($flag1a2, 2), 4); ok($tracker == 3); is($tracker->counter($flag1a2), 4);
        is($tracker->set($flag1a2), 0);    ok($tracker == 0); is($tracker->counter($flag1a2), 0);

        is($tracker->set([$flag1, $flag2], 3), 6); ok($tracker == 3); is($tracker->counter([$flag1, $flag2]), 6);
        is($tracker->set([$flag1, $flag2]), 0);    ok($tracker == 0); is($tracker->counter([$flag1, $flag2]), 0);
    };

    subtest "$class: counter", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);
        is($tracker->counter($flag1), 0);
        is($tracker->counter($flag1a2), 0);

        is($tracker->increment($flag1a2), 2);    ok($tracker == 3); is($tracker->counter($flag1), 1); is($tracker->counter($flag1a2), 2);
        is($tracker->increment($flag1a1), 1);    ok($tracker == 3); is($tracker->counter($flag1), 2);
        is($tracker->increment($flag1a2, 2), 4); ok($tracker == 3); is($tracker->counter($flag1), 4);

        is($tracker->decrement($flag1, 4), 4); ok($tracker == 2); is($tracker->counter($flag1), 0);
        is($tracker->decrement($flag1, 5), 5); ok($tracker == 2); is($tracker->counter($flag1), -5);

        # enable|disable & counter are problematic
        ok(!$tracker->disable($flag1));     ok($tracker == 2); is($tracker->counter($flag1), -5);
        ok($tracker->enable($flag1));       ok($tracker == 3); is($tracker->counter($flag1), 1);
        is($tracker->decrement($flag1), 1); ok($tracker == 2); is($tracker->counter($flag1), 0);

        is($tracker->increment($flag1, 2), 2); ok($tracker == 3); is($tracker->counter($flag1), 2);
        ok(!$tracker->enable($flag1));         ok($tracker == 3); is($tracker->counter($flag1), 2);
        ok($tracker->disable($flag1));         ok($tracker == 2); is($tracker->counter($flag1), 0);

        ok(!$tracker->disable($flag3));     ok($tracker == 2); is($tracker->counter($flag3), 0);
        ok($tracker->enable($flag3));       ok($tracker == 6); is($tracker->counter($flag3), 1);
        is($tracker->increment($flag3), 1); ok($tracker == 6); is($tracker->counter($flag3), 2);

        ok($tracker->toggle($flag3));       ok($tracker == 2); is($tracker->counter($flag3), 0);
        is($tracker->decrement($flag3), 1); ok($tracker == 2); is($tracker->counter($flag3), -1);
        ok($tracker->toggle($flag3));       ok($tracker == 6); is($tracker->counter($flag3), 1);
    };

    subtest "$class: return", sub {
        my $tracker = new_ok $class;

        is_deeply($tracker->enable($flag1),           $flag1);
        is_deeply($tracker->enable([$flag1,$flag3]),  [$flag3]);
        is_deeply($tracker->disable($flag1a2),        $flag1);
        is_deeply($tracker->disable([$flag1,$flag3]), [$flag3]);
        is_deeply($tracker->toggle($flag1a2),         $flag1a2);
        is_deeply($tracker->toggle([$flag1,$flag3]),  [$flag1,$flag3]);
    };

    subtest "$class: overload", sub {
        my $tracker = new_ok $class;

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
        ok($tracker * $flag1a2);
        ok($tracker == 2);
        ok($tracker * [ $flag1, $flag2 ]);
        ok($tracker == 1);

        ok($tracker + $flag1);
        is($tracker->counter($flag1), 2);

        ok($tracker + [ $flag1 => 4 ]);
        is($tracker->counter($flag1), 6);

        ok($tracker - [ [$flag1] => 2 ]);
        is($tracker->counter($flag1), 4);

        ok($tracker + [ [$flag1, $flag2] => 2 ]);
        is($tracker->counter($flag1), 6);
        is($tracker->counter($flag2), 2);
    };

    subtest "$class: argument", sub {
        my $tracker = new_ok $class => [$flag2];

        ok($tracker == 2);
    };

    subtest "$class: stringify", sub {
        my $tracker = new_ok $class;

        ok($tracker == 0);
        is($tracker->decrement($flag1, 5), 5);
        ok($tracker == 0);
        is("$tracker", "0;$flag1=-5");
    };
}

done_testing;

