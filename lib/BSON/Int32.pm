use 5.008001;
use strict;
use warnings;

package BSON::Int32;
# ABSTRACT: BSON type wrapper for Int32

our $VERSION = '0.17';

use Carp;
use Class::Tiny 'value';

my $max_int32 = 2147483647;
my $min_int32 = -2147483648;

sub BUILD {
    my $self = shift;
    # coerce to IV internally
    $self->{value} = defined( $self->{value} ) ? int( $self->{value} ) : 0;
    if ( $self->{value} > $max_int32 || $self->{value} < $min_int32 ) {
        croak("The value '$self->{value}' can't fit in a signed Int32");
    }
}

=method TO_JSON

Returns the value as an integer.

=cut

sub TO_JSON { return int($_[0]->{value}) }

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
