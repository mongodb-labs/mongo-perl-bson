use 5.008001;
use strict;
use warnings;

package BSON::Double;
# ABSTRACT: BSON type wrapper for Double

our $VERSION = '0.17';

use Carp;
use Class::Tiny 'value';

sub BUILD {
    my $self = shift;
    # coerce to NV internally
    $self->{value} = defined( $self->{value} ) ? $self->{value} / 1.0 : 0.0;
}

=method TO_JSON

Returns a double, unless the value is 'Inf', '-Inf' or NaN
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
