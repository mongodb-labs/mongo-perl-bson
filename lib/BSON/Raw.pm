use 5.008001;
use strict;
use warnings;

package BSON::Raw;
# ABSTRACT: BSON type wrapper for pre-encoded BSON bytes

our $VERSION = '0.17';

use Class::Tiny qw/value/;

1;

__END__

=head1 SYNOPSIS

    use BSON::Types;

    my $ordered = bson_raw( $bson_bytes );

=head1 DESCRIPTION

This module provides a BSON document wrapper for already-encoded BSON bytes.

=head1 SEE ALSO

L<BSON>

=cut
