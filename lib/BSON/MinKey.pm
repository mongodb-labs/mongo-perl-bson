use 5.008001;
use strict;
use warnings;

package BSON::MinKey;
# ABSTRACT: MinKey data for BSON

our $VERSION = '0.17';

sub new {
    bless {}, $_[0];
}

1;

__END__

=head1 SYNOPSIS

    use BSON;

    my $key = BSON::MinKey->new;

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's MinKey element.

=head1 METHODS

=head2 new

Object constructor, takes no parameters.

=head1 SEE ALSO

L<BSON>

=cut
