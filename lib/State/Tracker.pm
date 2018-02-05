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
    my ($self, $states) = @_;

    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $self->{counter}{ $STATES{$state} } // ($self->{state} & $STATES{$state} ? 1 : 0);
    }

    return $total;
}

{
    my $current_integer_exponent = 0;
    sub new_state {
        return 2**$current_integer_exponent++;
    }
}

sub enable {
    my ($self, $states) = @_;

    my $changed_state = 0;
    my @changes;

    foreach my $state (ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if (~$self->{state} & $STATES{$state}) {
            $self->{state} |= $STATES{$state};
            delete($self->{counter}{ $STATES{$state} }) if $self->{counter}{ $STATES{$state} } // 1 <= 0;
            $changed_state |= $STATES{$state};
            push(@changes, $state);
        }
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $return;
}

sub disable {
    my ($self, $states) = @_;

    my $changed_state = 0;
    my @changes;

    foreach my $state (ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if ($self->{state} & $STATES{$state}) {
            $self->{state} &= ~$STATES{$state};
            delete($self->{counter}{ $STATES{$state} }) if $self->{counter}{ $STATES{$state} } // 0 > 0;
            $changed_state |= $STATES{$state};
            push(@changes, $state);
        }
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $return;
}

sub toggle {
    my ($self, $states) = @_;

    my $changed_state = 0;
    my @changes;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $self->{state} ^= $STATES{$state};
        if ($self->{state} & $STATES{$state}) { delete($self->{counter}{ $STATES{$state} }) if $self->{counter}{ $STATES{$state} } // 1 <= 0; }
        else                                  { delete($self->{counter}{ $STATES{$state} }) if $self->{counter}{ $STATES{$state} } // 0 >  0; }
        $changed_state |= $STATES{$state};
        push(@changes, $state);
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $return;
}

sub increment {
    my ($self, $states, $increment) = @_;

    if (ref($states) and (ref($states->[0]) or @_ == 2 or ($increment // '') eq '')) {
        ($states, $increment) = @$states;
    }

    $increment ||= 1;
    my $changed_state = 0;
    my @changes;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $increment;
        ($self->{counter}{ $STATES{$state} } //= $self->{state} & $STATES{$state} ? 1 : 0) += $increment;
        $self->{state} |= $STATES{$state} if $self->{counter}{ $STATES{$state} } > 0;
        $changed_state |= $STATES{$state};
        push(@changes, $state);
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $total;
}

sub decrement {
    my ($self, $states, $decrement) = @_;

    if (ref($states) and (ref($states->[0]) or @_ == 2 or ($decrement // '') eq '')) {
        ($states, $decrement) = @$states;
    }

    $decrement ||= 1;
    my $changed_state = 0;
    my @changes;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        $total += $decrement;
        ($self->{counter}{ $STATES{$state} } //= $self->{state} & $STATES{$state} ? 1 : 0) -= $decrement;
        $self->{state} &= ~$STATES{$state} if $self->{counter}{ $STATES{$state} } <= 0;
        $changed_state |= $STATES{$state};
        push(@changes, $state);
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $total;
}

sub set {
    my ($self, $states, $set) = @_;

    $set //= 0;
    my $changed_state = 0;
    my @changes;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } ref($states) ? @$states : split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if (($self->{counter}{ $STATES{$state} } // $self->{state} & $STATES{$state} ? 1 : 0) != $set) {
            $total += $set;
            $self->{counter}{ $STATES{$state} } = $set;
            if ($self->{counter}{ $STATES{$state} } > 0) { $self->{state} |= $STATES{$state}; }
            else                                         { $self->{state} &= ~$STATES{$state}; }
            $changed_state |= $STATES{$state};
            push(@changes, $state);
        }
    }

    my $return = ref($states) ? \@changes : join('|', @changes);

    $self->_trigger($changed_state, $return) if $changed_state;

    return $total;
}

sub track {
    my ($self, @args) = @_;
    my $cb = pop(@args);
    my %options = @args;

    my @check = (0, ~0, $cb);
    $self->{tracks}{$cb+0} = \@check;

    if (exists($options{enabled})) {
        foreach my $state (ref($options{enabled}) ? @{ $options{enabled} } : split(m{\|}, $options{enabled})) {
            $STATES{$state} //= $self->new_state;
            $check[CHECK_POSITIVE] |= $STATES{$state};
        }
    }

    if (exists($options{disabled})) {
        foreach my $state (ref($options{disabled}) ? @{ $options{disabled} } : split(m{\|}, $options{disabled})) {
            $STATES{$state} //= $self->new_state;
            $check[CHECK_NEGATIVE] &= ~$STATES{$state};
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

