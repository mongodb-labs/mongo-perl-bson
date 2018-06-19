use 5.010001;
use strict;
use warnings;

package BSON::Time;
# ABSTRACT: BSON type wrapper for date and time

use version;
our $VERSION = 'v1.6.5';

use Carp qw/croak/;
use Config;
use Time::HiRes qw/time/;
use Scalar::Util qw/looks_like_number/;

use if !$Config{use64bitint}, 'Math::BigInt';
use if !$Config{use64bitint}, 'Math::BigFloat';

use Moo;

=attr value

A integer representing milliseconds since the Unix epoch.  The default
is 0.

=cut

has 'value' => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

sub BUILDARGS {
    my $class = shift;
    my $n     = scalar(@_);

    my %args;
    if ( $n == 0 ) {
        if ( $Config{use64bitint} ) {
            $args{value} =  time() * 1000;
        }
        else {
            $args{value} = Math::BigFloat->new(time());
            $args{value}->bmul(1000);
            $args{value} = $args{value}->as_number('zero');
        }
    }
    elsif ( $n == 1 ) {
        croak "argument to BSON::Time::new must be epoch seconds, not '$_[0]'"
          unless looks_like_number( $_[0] );

        if ( !$Config{use64bitint} && ref($args{value}) ne 'Math::BigInt' ) {
            $args{value} = Math::BigFloat->new(shift);
            $args{value}->bmul(1000);
            $args{value} = $args{value}->as_number('zero');
        }
        else {
            $args{value} = 1000 * shift;
        }
    }
    elsif ( $n % 2 == 0 ) {
        %args = @_;
        if ( defined $args{value} ) {
            croak "argument to BSON::Time::new must be epoch seconds, not '$args{value}'"
              unless looks_like_number( $args{value} ) || overload::Overloaded($args{value});

            if ( !$Config{use64bitint} && ref($args{value}) ne 'Math::BigInt' ) {
                $args{value} = Math::BigInt->new($args{value});
            }
        }
        else {
            if ( !$Config{use64bitint} && ref($args{value}) ne 'Math::BigInt' ) {
                $args{value} = Math::BigFloat->new(shift);
                $args{value}->bmul(1000);
                $args{value} = $args{value}->as_number('zero');
            }
            else {
                $args{value} = 1000 * shift;
            }
        }
    }
    else {
        croak("Invalid number of arguments ($n) to BSON::Time::new");
    }

    # normalize all to integer ms
    $args{value} = int( $args{value} );

    return \%args;
}

=method epoch

Returns the number of seconds since the epoch (i.e. a floating-point value).

=cut

sub epoch {
    my $self = shift;
    if ( $Config{use64bitint} ) {
        return $self->value / 1000;
    }
    else {
        require Math::BigFloat;
        my $upgrade = Math::BigFloat->new($self->value->bstr);
        return 0 + $upgrade->bdiv(1000)->bstr;
    }
}

=method as_iso8601

Returns the C<value> as an ISO-8601 formatted string of the form
C<YYYY-MM-DDThh:mm:ss.sssZ>.  The fractional seconds will be omitted if
they are zero.

=cut

sub as_iso8601 {
    my $self = shift;
    my ($s, $m, $h, $D, $M, $Y) = gmtime($self->epoch);
    $M++;
    $Y+=1900;
    my $f = $self->{value} % 1000;
    return $f
      ? sprintf( "%4d-%02d-%02dT%02d:%02d:%02d.%03dZ", $Y, $M, $D, $h, $m, $s, $f )
      : sprintf( "%4d-%02d-%02dT%02d:%02d:%02dZ",      $Y, $M, $D, $h, $m, $s );
}

=method as_datetime

Loads L<DateTime> and returns the C<value> as a L<DateTime> object.

=cut

sub as_datetime {
    require DateTime;
    return DateTime->from_epoch( epoch => $_[0]->{value} / 1000 );
}

=method as_datetime_tiny

Loads L<DateTime::Tiny> and returns the C<value> as a L<DateTime::Tiny>
object.

=cut

sub as_datetime_tiny {
    my ($s, $m, $h, $D, $M, $Y) = gmtime($_[0]->epoch);
    $M++;
    $Y+=1900;

    require DateTime::Tiny;
    return DateTime::Tiny->new(
        year => $Y, month => $M, day => $D,
        hour => $h, minute => $m, second => $s
    );
}

=method as_mango_time

Loads L<Mango::BSON::Time> and returns the C<value> as a L<Mango::BSON::Time>
object.

=cut

sub as_mango_time {
    require Mango::BSON::Time;
    return Mango::BSON::Time->new( $_[0]->{value} );
}

=method as_time_moment

Loads L<Time::Moment> and returns the C<value> as a L<Time::Moment> object.

=cut

sub as_time_moment {
    require Time::Moment;
    return Time::Moment->from_epoch( $_[0]->{value} / 1000 );
}

sub _num_cmp {
    my ( $self, $other ) = @_;
    if ( ref($other) eq ref($self) ) {
        return $self->{value} <=> $other->{value};
    }
    return 0+ $self <=> 0+ $other;
}

sub _str_cmp {
    my ( $self, $other ) = @_;
    if ( ref($other) eq ref($self) ) {
        return $self->{value} cmp $other->{value};
    }
    return "$self" cmp "$other";
}

sub op_eq {
    my ( $self, $other ) = @_;
    return( ($self <=> $other) == 0 );
}

use overload (
    q{""}    => \&epoch,
    q{0+}    => \&epoch,
    q{<=>}   => \&_num_cmp,
    q{cmp}   => \&_str_cmp,
    fallback => 1,
);

=method TO_JSON

Returns a string formatted by L</as_iso8601>.

If the C<BSON_EXTJSON> option is true, it will instead be compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$date" : { "$numberLong": "22337203685477580" } }

=cut

sub TO_JSON {
    return $_[0]->as_iso8601 unless $ENV{BSON_EXTJSON};
    return { '$date' => { '$numberLong' => "$_[0]->{value}"} };
}

1;

__END__

=for Pod::Coverage op_eq BUILDARGS

=head1 SYNOPSIS

    use BSON::Types ':all';

    bson_time();        # now
    bson_time( $secs ); # floating point seconds since epoch

=head1 DESCRIPTION

This module provides a BSON type wrapper for a 64-bit date-time value in
the form of milliseconds since the Unix epoch (UTC only).

On a Perl without 64-bit integer support, the value must be a
L<Math::BigInt> object.

=head1 OVERLOADING

Both numification (C<0+>) and stringification (C<"">) are overloaded to
return the result of L</epoch>.  Numeric comparison and string comparison
are overloaded based on those and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
