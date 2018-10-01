use 5.010001;
use strict;
use warnings;

package BSON::Raw;
# ABSTRACT: BSON type wrapper for pre-encoded BSON documents

use version;
our $VERSION = 'v1.8.2';

use Moo;

=attr bson

A string containing a BSON-encoded document.  Default is C<undef>.

=attr metadata

A hash reference containing arbitrary metadata about the BSON document.
Default is C<undef>.

=cut

has [qw/bson metadata/] => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

1;

__END__

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $ordered = bson_raw( $bson_bytes );

=head1 DESCRIPTION

This module provides a BSON document wrapper for already-encoded BSON bytes.

Generally, end-users should have no need for this; it is provided for
optimization purposes for L<MongoDB> or other client libraries.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
