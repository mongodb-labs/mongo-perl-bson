use 5.010001;
use strict;
use warnings;

package BSON::Symbol;

our $VERSION = 'v1.6.8';

use Moo 2.002004;
use namespace::clean -except => 'meta';

extends 'BSON::String';

1;
