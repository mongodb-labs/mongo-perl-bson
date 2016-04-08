use 5.008001;
use strict;
use warnings;

package BSON::Bool;
# ABSTRACT: Legacy BSON type wrapper for Booleans (DEPRECATED)

our $VERSION = '0.17';

use boolean ();
our @ISA = qw/boolean/;

sub new {
    my ( $class, $bool ) = @_;
    return bless \(my $dummy = $bool ? 1 : 0), $class;
}

sub value {
    ${$_[0]} ? 1 : 0;
}

sub true {
    return $_[0]->new(1);
}

sub false {
    return $_[0]->new(0);
}

sub op_eq {
    return !! $_[0] == !! $_[1];
}

1;

__END__

=for Pod::Coverage new value true false op_eq

=head1 DESCRIPTION

This module has been deprecated as it was not compatible with
other common boolean implmentations on CPAN.

Internally, this is now a thin wrapper around L<boolean>.

You are strongly encouraged to use L<boolean> directly instead.

Legacy methods have been preserved in as compatible a form as possible.

=head1 SEE ALSO

=for :list
* L<BSON>
* L<boolean>

=cut
