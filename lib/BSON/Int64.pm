use 5.008001;
use strict;
use warnings;

package BSON::Int64;
# ABSTRACT: BSON type wrapper for Int64

our $VERSION = '0.17';

use Carp;
use Config;
use Class::Tiny 'value';

use if !$Config{use64bitint}, "Math::BigInt";

# With long doubles or a 32-bit integer perl, we're able to directly check
# if a value exceeds the maximum bounds of an int64_t.  On a 64-bit Perl
# with only regular doubles, the loss of precision for doubles makes an
# exact check against the negative boundary impossible from pure-Perl.
# (The positive boundary isn't an issue because Perl will upgrade
# internally to uint64_t to do the comparision).  Fortunately, we can take
# advantage of a quirk in pack(), where a float that is in the ambiguous
# negative zone or that is too negative to fit will get packed like the
# smallest negative int64_t.

BEGIN {
    my $max_int64 = $Config{use64bitint} ? 9223372036854775807 : Math::BigInt->new("9223372036854775807");
    my $min_int64 = $Config{use64bitint} ? -9223372036854775808 : Math::BigInt->new("-9223372036854775808");
    my $packed_min_int64 = pack("q", $min_int64);
    if ( $Config{nvsize} == 16 || ! $Config{use64bitint} ) {
        *BUILD = sub {
            my $self = shift;

            my $value = defined $self->{value} ? int($self->{value}) : 0;

            if ( $value > $max_int64 ) {
                $value = $max_int64;
            }
            elsif ( $value < $min_int64 ) {
                $value = $min_int64;
            }

            return $self->{value} = $value;
        }
    }
    else {
        *BUILD = sub {
            my $self = shift;

            my $value = defined $self->{value} ? int($self->{value}) : 0;

            if ( $value >= 0 && $value > $max_int64 ) {
                $value = $max_int64;
            }
            elsif ( $value < 0 && pack("q", $value) eq $packed_min_int64 ) {
                $value = $min_int64;
            }

            return $self->{value} = $value;
        }
    }
}

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
