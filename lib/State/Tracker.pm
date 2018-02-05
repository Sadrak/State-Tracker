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
use constant CHECK_COUNTER  => 2;
use constant CALLBACK       => 3;

use constant EXPONENT => 0;
use constant INTEGER  => 1;

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
        map { $STATES{$_}[EXPONENT] => $_ }
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
    my ($self, $state, $set) = @_;

    $STATES{$state} //= $self->new_state;

    $self->{counter}{ $STATES{$state}[EXPONENT] } if defined $set;

    $self->{counter}{ $STATES{$state}[EXPONENT] };
}

{
    my $current_integer_exponent = 0;
    sub new_state {
        # +0 is required, otherwise the first element will already be incremented
        my $new_state = [$current_integer_exponent+0, 2**$current_integer_exponent++];
        return $new_state;
    }
}

sub enable {
    my ($self, $states) = @_;

    my $change = 0;
    my $last_state = $self->{state};

    foreach my $state (split(m{\|}, $states)) {
        $STATES{$state} //= $self->new_state;

        if (~$self->{state} & $STATES{$state}[INTEGER]) {
            $self->{state} |= $STATES{$state}[INTEGER];
            $change |= $STATES{$state}[INTEGER];
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
        $STATES{$state} //= $self->new_state;

        if ($self->{state} & $STATES{$state}[INTEGER]) {
            $self->{state} &= ~$STATES{$state}[INTEGER];
            $change |= $STATES{$state}[INTEGER];
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
        $STATES{$state} //= $self->new_state;

        $self->{state} ^= $STATES{$state}[INTEGER];
        $change |= $STATES{$state}[INTEGER];
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
        $STATES{$state} //= $self->new_state;

        $total += $increment;
        $self->{counter}{ $STATES{$state}[EXPONENT] } += $increment;
        $self->{state} |= $STATES{$state}[INTEGER] if $self->{counter}{ $STATES{$state}[EXPONENT] } > 0;
        $change |= $STATES{$state}[INTEGER];
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
        $STATES{$state} //= $self->new_state;

        $total += $decrement;
        $self->{counter}{ $STATES{$state}[EXPONENT] } -= $decrement;
        $self->{state} &= ~$STATES{$state}[INTEGER] if $self->{counter}{ $STATES{$state}[EXPONENT] } <= 0;
        $change |= $STATES{$state}[INTEGER];
    }

    $self->change($change) if $change;

    return $total;
}

sub change {
    my ($self, $change) = @_;

    # FIXME don't check every track, build a hash lookup which state
    # can trigger which track
    TRACK: foreach my $cb (keys(%{ $self->{tracks} })) {
        my @check = @{ $self->{tracks}{$cb} };

        ($check[CHECK_POSITIVE] & $self->{state}) == $check[CHECK_POSITIVE] or next TRACK;
        ($check[CHECK_NEGATIVE] | $self->{state}) == $check[CHECK_NEGATIVE] or next TRACK;

        my $counter_changed = 0;
        foreach my $exponent (keys(%{ $check[CHECK_COUNTER] })) {
            foreach my $op (keys(%{ $check[CHECK_COUNTER]{$exponent} })) {
                if    ($op eq '<' ) { ($self->{counter}{ $exponent } // 0) <  $check[CHECK_COUNTER]{$exponent}{$op} or next TRACK; }
                elsif ($op eq '<=') { ($self->{counter}{ $exponent } // 0) <= $check[CHECK_COUNTER]{$exponent}{$op} or next TRACK; }
                elsif ($op eq '>' ) { ($self->{counter}{ $exponent } // 0) >  $check[CHECK_COUNTER]{$exponent}{$op} or next TRACK; }
                elsif ($op eq '>=') { ($self->{counter}{ $exponent } // 0) >= $check[CHECK_COUNTER]{$exponent}{$op} or next TRACK; }
                else                { ($self->{counter}{ $exponent } // 0) == $check[CHECK_COUNTER]{$exponent}{$op} or next TRACK; }
            }
            $counter_changed |= 1 << $exponent;
        }

        ($check[CHECK_POSITIVE] & $change)
            or (~$check[CHECK_NEGATIVE] & $change)
            or ($counter_changed and $counter_changed & $change)
            or next TRACK;

        $check[CALLBACK]->($self, $change)
            or delete($self->{tracks}{$cb+0});
    }

    return;
}

sub track {
    my ($self, $cb, @states) = @_;

    my @check = (0, ~0, {}, $cb);
    $self->{tracks}{$cb+0} = \@check;

    foreach my $state (@states) {

        if (ref($state)) {
            ($state, my $op, my $count) = @$state;
            if (not defined $count) {
                $count = $op;
                $op = '==';
            }

            # FIXME better to die?
            $OPS{$op} or return;

            $STATES{$state} //= $self->new_state;
            $check[CHECK_COUNTER]{ $STATES{$state}[EXPONENT] }{$op} = $count;
        }
        elsif (index($state,'~') == 0) {
            substr($state, 0, 1, '');
            $STATES{$state} //= $self->new_state;
            $check[CHECK_NEGATIVE] &= ~$STATES{$state}[INTEGER];
        }
        else {
            $STATES{$state} //= $self->new_state;
            $check[CHECK_POSITIVE] |= $STATES{$state}[INTEGER];
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
tracker for special predefined states.

=head1 LICENSE

Copyright (C) Sadrak.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Sadrak E<lt>sadrak@cpan.orgE<gt>

=cut

