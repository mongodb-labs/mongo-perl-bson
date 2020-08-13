use 5.010001;
use strict;
use warnings;

package BSON::Symbol;

# ABSTRACT: BSON type wrapper for symbol data (DEPRECATED)

our $VERSION = 'v1.12.3';

use Moo 2.002004;
use namespace::clean -except => 'meta';

extends 'BSON::String';

1;

__END__

=head1 DESCRIPTION

This module wraps the deprecated BSON "symbol" type.

You are strongly encouraged to use ordinary string data instead.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
