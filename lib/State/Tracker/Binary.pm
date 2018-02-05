package State::Tracker::Binary;
use 5.010001;
use strict;
use warnings;

our $VERSION = "0.01";

use List::Util qw(reduce);

our %STATES;
our %OPS = map { $_ => 1 } qw/
    <
    <=
    >
    >=
    ==
/;

use constant CHECK_POSITIVE => 0;
use constant CHECK_NEGATIVE => 1;
use constant CALLBACK       => 2;

use overload
    '<' => 'enable',
    '>' => 'disable',
    '*' => 'toggle',
    '+' => 'increment',
    '-' => 'decrement',
    '==' => 'compare',
    '""' => 'to_string',
    '0+' => 'state',
;

sub new {
    my ($class, $state) = @_;

    my $self = bless(
        {
            state              => 0,
            state_with_counter => 0,
            counter            => {},
            tracks             => {},
        },
        $class,
    );

    $self->enable($state) if $state;

    return bless $self, $class;
}

sub to_string {
    my ($self) = @_;

    return join(
        ';',
        $_[0]->{state},
        map { $_.'='.$_[0]->{counter}{$_} }
        keys(%{ $_[0]->{counter} }),
    );
}

sub compare {
    my ($self, $state) = @_;

    return $self->{state} == $state;
}

sub state {
    my ($self) = @_;

    $self->{state};
}

sub counter {
    my ($self, $states) = @_;

    my $total = 0;

    foreach my $state (_active_bits(ref($states) ? reduce { $a | $b } @$states : $states)) {
        $total += $self->{counter}{ $state } // ($self->{state} & $state ? 1 : 0);
    }

    return $total;
}

sub enable {
    my ($self, $states) = @_;

    my $has_changed = ~$self->{state} & (ref($states) ? reduce { $a | $b } @$states : $states)
        or return;

    $self->{state} |= $has_changed;

    # delete all affected counter which are currently 0 or negative
    if (my $has_counter = $self->{state_with_counter} & $has_changed) {
        delete(
            @{ $self->{counter} }{
                grep { $self->{counter}{ $_ } // 1 <= 0 }
                _active_bits($has_changed)
            }
        );
        $self->{state_with_counter} &= ~$has_counter;
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $return;
}

sub disable {
    my ($self, $states) = @_;

    my $has_changed = $self->{state} & (ref($states) ? reduce { $a | $b } @$states : $states)
        or return;

    $self->{state} &= ~$has_changed;

    # delete all affected counter which are currently positive
    if (my $has_counter = $self->{state_with_counter} & $has_changed) {
        delete(
            @{ $self->{counter} }{
                grep { $self->{counter}{ $_ } // 0 > 0 }
                _active_bits($has_changed)
            }
        );
        $self->{state_with_counter} &= ~$has_counter;
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $return;
}

sub toggle {
    my ($self, $states) = @_;

    my $has_changed = ref($states) ? reduce { $a | $b } @$states : $states;

    $self->{state} ^= $has_changed;

    if (my $has_counter = $self->{state_with_counter} & $has_changed) {
        delete(
            @{ $self->{counter} }{
                grep { $self->{state} & $_ ? $self->{counter}{ $_ } // 1 <= 0 : $self->{counter}{ $_ } // 0 > 0 }
                _active_bits($has_changed)
            }
        );
        $self->{state_with_counter} &= ~$has_counter;
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $return;
}

sub increment {
    my ($self, $states, $increment) = @_;

    if (ref($states) and (ref($states->[0]) or @_ == 2 or ($increment // '') eq '')) {
        ($states, $increment) = @$states;
    }

    my $has_changed = ref($states) ? reduce { $a | $b } @$states : $states;

    $increment ||= 1;
    my $total = 0;
    
    foreach my $state (_active_bits($has_changed)) {
        $total += $increment;
        ($self->{counter}{ $state } //= $self->{state} & $state ? 1 : 0) += $increment;
        $self->{state} |= $state if $self->{counter}{ $state } > 0;
        $self->{state_with_counter} |= $state;
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $total;
}

sub decrement {
    my ($self, $states, $decrement) = @_;

    if (ref($states) and (ref($states->[0]) or @_ == 2 or ($decrement // '') eq '')) {
        ($states, $decrement) = @$states;
    }

    my $has_changed = ref($states) ? reduce { $a | $b } @$states : $states;

    $decrement ||= 1;
    my $total = 0;
    
    foreach my $state (_active_bits($has_changed)) {
        $total += $decrement;
        ($self->{counter}{ $state } //= $self->{state} & $state ? 1 : 0) -= $decrement;
        $self->{state} &= ~$state if $self->{counter}{ $state } <= 0;
        $self->{state_with_counter} |= $state;
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $total;
}

sub set {
    my ($self, $states, $set) = @_;

    my $has_changed = 0;

    $set //= 0;
    my $total = 0;
    
    foreach my $state (_active_bits(ref($states) ? reduce { $a | $b } @$states : $states)) {
        if (($self->{counter}{ $state } // $self->{state} & $state ? 1 : 0) != $set) {
            $total += $set;
            $self->{counter}{ $state } = $set;
            if ($self->{counter}{ $state } > 0) { $self->{state} |= $state; }
            else                                { $self->{state} &= ~$state; }
            $self->{state_with_counter} |= $state;
            $has_changed |= $state;
        }
    }

    my $return = ref($states) ? [_active_bits($has_changed)] : $has_changed;

    $self->_trigger($has_changed, $return) if $has_changed;

    return $total;
}

sub track {
    my ($self, @args) = @_;
    my $cb = pop(@args);
    my %options = @args;

    my @check = (0, ~0, $cb);
    $self->{tracks}{$cb+0} = \@check;

    if ($options{enabled}) {
        foreach my $state (ref($options{enabled}) ? @{ $options{enabled} } : $options{enabled}) {
            $check[CHECK_POSITIVE] |= $state;
        }
    }

    if ($options{disabled}) {
        foreach my $state (ref($options{disabled}) ? @{ $options{disabled} } : $options{disabled}) {
            $check[CHECK_NEGATIVE] &= ~$state;
        }
    }

    return $cb+0;
}

sub _trigger {
    my ($self, $changed_state, $return) = @_;

    # FIXME don't check every track, build a hash lookup which state
    # can trigger which track when adding tracks
    TRACK: foreach my $cb (keys(%{ $self->{tracks} })) {
        my @check = @{ $self->{tracks}{$cb} };

        ($check[CHECK_POSITIVE] & $self->{state}) == $check[CHECK_POSITIVE] or next TRACK;
        ($check[CHECK_NEGATIVE] | $self->{state}) == $check[CHECK_NEGATIVE] or next TRACK;

        ($check[CHECK_POSITIVE] & $changed_state)
            or (~$check[CHECK_NEGATIVE] & $changed_state)
            or next TRACK;

        $check[CALLBACK]->($self, $return)
            or delete($self->{tracks}{$cb+0});
    }

    return;
}

sub _active_bits {
    my ($state) = @_;

    # $state hat nur ein bit gesetzt
    return $state if not $state & ($state - 1);

    # alle durchgehen
    my $bytes = int(log($state) / log(2));
    return grep $_, map { $state & (1<<$_) } 0..$bytes;
}
# FIXME benchmark
#    my ($state) = @_;
#    my @active;
#    my $bit = 1;
#    while ($bit <= $state) {
#        $state & $bit and push(@active, $bit);
#        $bit += $bit;
#    }
#    return \@active;
# (15:28:58) shmem: sub bits{ $max = length(sprintf"%b",$_[0]);grep$_,map{$_[0]&(1<<$_)}0..$max-1 }
# (16:21:29) moritz: $max = int log($number)/log(2)

1;

