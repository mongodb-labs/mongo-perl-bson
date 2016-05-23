use 5.008001;
use strict;
use warnings;

package BSON::Double;
# ABSTRACT: BSON type wrapper for Double

our $VERSION = '0.17';

use Carp;
use Class::Tiny 'value';

=attr value

A numeric scalar (or the special strings "Inf", "-Inf" or "NaN").  This
will be coerced to Perl's numeric type.  The default is 0.0.

=cut

sub BUILD {
    my $self = shift;
    # coerce to NV internally
    $self->{value} = defined( $self->{value} ) ? $self->{value} / 1.0 : 0.0;
}

=method TO_JSON

Returns a double, unless the value is 'Inf', '-Inf' or 'NaN'
(which are illegal in JSON), in which case an exception is thrown.

=cut

sub TO_JSON {
    my $copy = "$_[0]->{value}"; # avoid changing value to PVNV
    return $_[0]->{value}/1.0 unless $copy =~ /^(?:Inf|-Inf|NaN)/i;

    croak( "The value '$copy' is illegal in JSON" );
}

use overload (
    q{0+}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;

__END__

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $bytes = bson_double( $number );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a numeric value that
would be represented in BSON as a double.

=head1 OVERLOADING

The numification operator, C<0+> is overloaded to return the C<value>
and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
