use 5.008001;
use strict;
use warnings;

package BSON::Bytes;
# ABSTRACT: BSON type wrapper for binary byte strings

our $VERSION = '0.17';

use Class::Tiny {
    data    => "",
    subtype => 0,
};

use overload (
    q{""}    => sub { $_[0]->{data} },
    fallback => 1,
);

BEGIN {
    *type = \&subtype;
}

1;
