use 5.008001;
use strict;
use warnings;

package BSON::Time;
# ABSTRACT: Date and time data for BSON

our $VERSION = '0.17';

use Carp qw/croak/;
use Config;
use Time::HiRes qw/time/;
use Scalar::Util qw/looks_like_number/;
use overload;

use if !$Config{use64bitint}, 'Math::BigInt';

use Class::Tiny qw/value/; # value stores ms since epoch as integer

sub BUILDARGS {
    my $class = shift;
    my $n     = scalar(@_);

    my %args;
    if ( $n == 0 ) {
        $args{value} = 1000 * time();
    }
    elsif ( $n == 1 ) {
        croak "argument to BSON::Time::new must be epoch seconds, not '$_[0]'"
          unless looks_like_number( $_[0] );
        $args{value} = 1000 * shift;
    }
    elsif ( $n % 2 == 0 ) {
        %args = @_;
        if ( defined $args{value} ) {
            croak "argument to BSON::Time::new must be epoch seconds, not '$args{value}'"
              unless looks_like_number( $args{value} ) || overload::Overloaded($args{value});
        }
        else {
            $args{value} = 1000 * time();
        }
    }
    else {
        croak("Invalid number of arguments ($n) to BSON::Time::new");
    }

    # normalize all to integer ms
    $args{value} = int( $args{value} );

    if ( !$Config{use64bitint} && ref($args{value}) ne 'Math::BigInt' ) {
        $args{value} = Math::BigInt->new($args{value});
    }

    return \%args;
}

sub epoch {
    return int( $_[0]->value / 1000 );
}

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

sub as_datetime {
    require DateTime;
    return DateTime->from_epoch( epoch => $_[0]->{value} / 1000 );
}

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

Returns an ISO-8601 string for this date and time object in this form:
C<YYYY-MM-DDThh:mm:ss.sssZ>.  The fractional seconds will be omitted
if they are zero.

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

=for Pod::Coverage op_eq

=head1 SYNOPSIS

    use BSON;

    my $dt = BSON::Time->new( $epoch );

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's date element.

=head1 METHODS

=head2 new

Object constructor. Optional parameter specifies an epoch date.
If no parameters are passed it will use the current C<time>.

    my $t = BSON::Time->new;    # Time now
    my $d = BSON::Time->new(123456789);

=head2 value

Returns the stored time in milliseconds since the Epoch. 
To convert to seconds, divide by 1000.

=head2 epoch

Returns the stored time in seconds since the Epoch. 

=head1 SEE ALSO

L<BSON>

=cut
