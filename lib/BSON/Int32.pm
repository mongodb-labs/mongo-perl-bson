use 5.008001;
use strict;
use warnings;

package BSON::Int32;
# ABSTRACT: BSON type wrapper for Int32

our $VERSION = '0.17';

use Class::Tiny qw/value/;

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;
