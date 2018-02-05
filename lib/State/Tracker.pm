package State::Tracker;
use 5.010001;
use strict;
use warnings;

our $VERSION = "0.01";

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
            state   => 0,
            counter => {},
            tracks  => {},
        },
        $class,
    );

    $self->enable($state) if $state;

    return bless $self, $class;
}

sub to_string {
    my ($self) = @_;

    my %state_for =
        map { $STATES{$_} => $_ }
        keys(%STATES);

    return join(
        ';',
        $_[0]->{state},
        map { $state_for{$_}.'='.$_[0]->{counter}{$_} }
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
    my ($self, $state) = @_;

    $STATES{$state} //= $self->new_state;

    return $self->{counter}{ $STATES{$state} };
}

{
    my $current_integer_exponent = 0;
    sub new_state {
        return 2**$current_integer_exponent++;
    }
}

sub enable {
    my ($self, $states) = @_;

    my $has_changed = 0;
    my $last_state = $self->{state};

    foreach my $state (split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if (~$self->{state} & $STATES{$state}) {
            $self->{state} |= $STATES{$state};
            $self->{counter}{ $STATES{$state} } = 1 if $self->{counter}{ $STATES{$state} } // 1 <= 0;
            $has_changed |= $STATES{$state};
        }
    }

    $self->_trigger($has_changed) if $has_changed;

    return $last_state != $self->{state};
}

sub disable {
    my ($self, $states) = @_;

    my $has_changed = 0;
    my $last_state = $self->{state};

    foreach my $state (split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if ($self->{state} & $STATES{$state}) {
            $self->{state} &= ~$STATES{$state};
            $self->{counter}{ $STATES{$state} } = 0 if $self->{counter}{ $STATES{$state} } // 0 > 0;
            $has_changed |= $STATES{$state};
        }
    }

    $self->_trigger($has_changed) if $has_changed;

    return $last_state != $self->{state};
}

sub toggle {
    my ($self, $states) = @_;

    my $has_changed = 0;
    my $last_state = $self->{state};

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $self->{state} ^= $STATES{$state};
        $has_changed |= $STATES{$state};
    }

    $self->_trigger($has_changed) if $has_changed;

    return 1;
}

sub increment {
    my ($self, $states, $increment) = @_;

    $increment ||= 1;
    my $has_changed = 0;
    my $total = 0;

    if (ref($states)) {
        ($states, $increment) = @$states;
    }

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $increment;
        $self->{counter}{ $STATES{$state} } += $increment;
        $self->{state} |= $STATES{$state} if $self->{counter}{ $STATES{$state} } > 0;
        $has_changed |= $STATES{$state};
    }

    $self->_trigger($has_changed) if $has_changed;

    return $total;
}

sub decrement {
    my ($self, $states, $decrement) = @_;

    $decrement ||= 1;
    my $has_changed = 0;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $decrement;
        $self->{counter}{ $STATES{$state} } -= $decrement;
        $self->{state} &= ~$STATES{$state} if $self->{counter}{ $STATES{$state} } <= 0;
        $has_changed |= $STATES{$state};
    }

    $self->_trigger($has_changed) if $has_changed;

    return $total;
}

sub set {
    my ($self, $states, $set) = @_;

    $set //= 0;
    my $has_changed = 0;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $set;
        $self->{counter}{ $STATES{$state} } = $set;
        $self->{state} |= $STATES{$state}  if $self->{counter}{ $STATES{$state} } > 0;
        $self->{state} &= ~$STATES{$state} if $self->{counter}{ $STATES{$state} } <= 0;
        $has_changed |= $STATES{$state};
    }

    $self->_trigger($has_changed) if $has_changed;

    return $total;
}

sub track {
    my ($self, $cb, @states) = @_;

    my @check = (0, ~0, $cb);
    $self->{tracks}{$cb+0} = \@check;

    foreach my $state (@states) {

        if (index($state,'~') == 0) {
            substr($state, 0, 1, '');
            $STATES{$state} //= $self->new_state;
            $check[CHECK_NEGATIVE] &= ~$STATES{$state};
        }
        else {
            $STATES{$state} //= $self->new_state;
            $check[CHECK_POSITIVE] |= $STATES{$state};
        }
    }

    return $cb+0;
}

sub _trigger {
    my ($self, $has_changed) = @_;

    # FIXME don't check every track, build a hash lookup which state
    # can trigger which track
    TRACK: foreach my $cb (keys(%{ $self->{tracks} })) {
        my @check = @{ $self->{tracks}{$cb} };

        ($check[CHECK_POSITIVE] & $self->{state}) == $check[CHECK_POSITIVE] or next TRACK;
        ($check[CHECK_NEGATIVE] | $self->{state}) == $check[CHECK_NEGATIVE] or next TRACK;

        ($check[CHECK_POSITIVE] & $has_changed)
            or (~$check[CHECK_NEGATIVE] & $has_changed)
            or next TRACK;

        $check[CALLBACK]->($self, $has_changed)
            or delete($self->{tracks}{$cb+0});
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

State::Tracker - Keep track of your programmstate

=head1 SYNOPSIS

    use State::Tracker;

=head1 DESCRIPTION

State::Tracker is module to set and check states and additional register
tracker for special predefined states.

=head1 LICENSE

Copyright (C) Sadrak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Sadrak E<lt>sadrak@cpan.orgE<gt>

=cut

