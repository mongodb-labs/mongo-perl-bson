use 5.010001;
use strict;
use warnings;

package BSON::Symbol;

use Moo 2.002004;
use namespace::clean -except => 'meta';

extends 'BSON::String';

sub TO_JSON {
    return { '$symbol' => $_[0]->{value} };
}

1;
