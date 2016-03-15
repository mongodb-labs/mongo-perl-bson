use 5.008001;
use strict;
use warnings;

package BSON::Int64;
# ABSTRACT: BSON type wrapper for Int64

our $VERSION = '0.17';

use Class::Tiny qw/value/;

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
