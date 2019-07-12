use 5.010001;
use strict;
use warnings;

package BSON::Array;
# ABSTRACT: BSON type wrapper for a list of elements

use version;
our $VERSION = 'v1.12.1';

sub new {
    my ( $class, @args ) = @_;
    return bless [@args], $class;
}

1;

__END__

=for Pod::Coverage new

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $array = bson_array(...);

=head1 DESCRIPTION

This module provides a BSON type wrapper representing a list of elements.
It is currently read-only.

Wrapping is usually not necessary as an ordinary array reference is usually
sufficient.  This class is helpful for cases where an array reference could
be ambiguously interpreted as a top-level document container.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
