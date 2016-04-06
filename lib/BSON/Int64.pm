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

my $max_int64 =
  $Config{use64bitint} ? 9223372036854775807 : Math::BigInt->new("9223372036854775807");
my $min_int64 =
  $Config{use64bitint} ? -9223372036854775808 : Math::BigInt->new("-9223372036854775808");

sub BUILD {
    my $self = shift;
    # coerce to IV internally
    $self->{value} = defined( $self->{value} ) ? int( $self->{value} ) : 0;
    if ( $self->{value} > $max_int64 || $self->{value} < $min_int64 ) {
        croak("The value '$self->{value}' can't fit in a signed Int64");
    }
}

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
