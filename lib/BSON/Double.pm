use 5.008001;
use strict;
use warnings;

package BSON::Double;
# ABSTRACT: BSON type wrapper for Double

our $VERSION = '0.17';

use Class::Tiny qw/value/;

sub BUILD {
    my $self = shift;
    $self->{value} = $self->{value}/1.0; # coerce to NV internally
}

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
