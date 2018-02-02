package State::Tracker;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

my $current_bit_exponent = 0;
our %STATES;

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
            state     => 0,
            counter   => {},
            callbacks => {},
        },
        $class,
    );

    $self->enable($state) if $state;

    return bless $self, $class;
}

sub to_string { join(';', $_[0]->{state}, map { $_.'='.$_[0]->{counter}{$_} } keys(%{ $_[0]->{counter} })) }
sub compare { $_[0]->{state} == $_[1] }

sub state { $_[0]->{state} }
sub counter { $_[0]->{counter}{ $_[1] } }

sub enable {
    my ($self, $states) = @_;

    my $change = 0;
    my $last_state = $self->{state};

    foreach my $state (split(m{\|}, $states)) {
        $STATES{$state} //= 2**$current_bit_exponent++;

        if (~$self->{state} & $STATES{$state}) {
            $self->{state} |= $STATES{$state};
            $change |= $STATES{$state};
        }
    }

    $self->change($change) if $change;

    return $last_state != $self->{state};
}

sub disable {
    my ($self, $states) = @_;

    my $change = 0;
    my $last_state = $self->{state};

    foreach my $state (split(m{\|}, $states)) {
        $STATES{$state} //= 2**$current_bit_exponent++;

        if ($self->{state} & $STATES{$state}) {
            $self->{state} &= ~$STATES{$state};
            $change |= $STATES{$state};
        }
    }

    $self->change($change) if $change;
    
    return $last_state != $self->{state};
}

sub toggle {
    my ($self, $states) = @_;

    my $change = 0;
    my $last_state = $self->{state};

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= 2**$current_bit_exponent++;

        $self->{state} ^= $STATES{$state};
        $change |= $STATES{$state};
    }

    $self->change($change) if $change;

    return 1;
}

sub increment {
    my ($self, $states, $increment) = @_;

    $increment ||= 1;
    my $change = 0;
    my $total = 0;

    if (ref($states)) {
        ($states, $increment) = @$states;
    }

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= 2**$current_bit_exponent++;

        $total += $increment;
        $self->{counter}{ $state } += $increment;
        $self->{state} |= $STATES{$state} if $self->{counter}{ $state } > 0;
        $change |= $STATES{$state};
    }

    $self->change($change) if $change;

    return $total;
}

sub decrement {
    my ($self, $states, $decrement) = @_;

    $decrement //= 1;
    my $change = 0;
    my $total = 0;

    my %uniq;
    foreach my $state (grep { ++$uniq{$_} == 1 } split(m{\|}, $states)) {
        $STATES{$state} //= 2**$current_bit_exponent++;

        $total += $decrement;
        $self->{counter}{ $state } -= $decrement;
        $self->{state} &= ~$STATES{$state} if $self->{counter}{ $state } <= 0;
        $change |= $STATES{$state};
    }

    $self->change($change) if $change;

    return $total;
}

sub change {
    my ($self, $change) = @_;

    # FIXME don't check every callback, build a hash lookup which state
    # can trigger which callback
    foreach my $cb (keys(%{ $self->{callbacks} })) {
        my @check = @{ $self->{callbacks}{$cb} };
#FIXME
#use Data::Dumper;
#print STDERR Dumper($change, \@check);
        ($check[CHECK_POSITIVE] & $self->{state}) == $check[CHECK_POSITIVE] or next;
        ($check[CHECK_NEGATIVE] | $self->{state}) == $check[CHECK_NEGATIVE] or next;

        ($check[CHECK_POSITIVE] & $change)
            or (~$check[CHECK_NEGATIVE] & $change)
            or next;

        $check[CALLBACK]->($self, $change)
            or delete($self->{callbacks}{$cb+0});
    }

    return;
}

sub callback {
    my ($self, $cb, @states) = @_;

    my @check = (0, ~0, $cb);
    $self->{callbacks}{$cb+0} = \@check;

    foreach my $state (@states) {

        if (ref($state)) {
            ($state, my $op, my $count) = @$state;
            if (not defined $count) {

            }
            my $op = '==';
            if (ref($count)) {
                ($count, $op) = @$count;
            }

        }
        elsif (index($state,'~') == 0) {
            substr($state, 0, 1, '');
            $STATES{$state} //= 2**$current_bit_exponent++;
            $check[CHECK_NEGATIVE] &= ~$STATES{$state};
        }
        else {
            $STATES{$state} //= 2**$current_bit_exponent++;
            $check[CHECK_POSITIVE] |= $STATES{$state};
        }
    }

    return $cb+0;
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
callbacks for special predefined states.

=head1 LICENSE

Copyright (C) Sadrak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Sadrak E<lt>sadrak@cpan.orgE<gt>

=cut

