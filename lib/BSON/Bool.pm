use 5.008001;
use strict;
use warnings;

package BSON::Bool;
# ABSTRACT: Legacy BSON type wrapper for Booleans (DEPRECATED)

use version;
our $VERSION = 'v0.999.1';

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
other common boolean implementations on CPAN.

You are strongly encouraged to use L<boolean> directly instead.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
