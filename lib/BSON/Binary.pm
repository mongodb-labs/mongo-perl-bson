use 5.010001;
use strict;
use warnings;

package BSON::Binary;
# ABSTRACT: Legacy BSON type wrapper for binary data (DEPRECATED)

use version;
our $VERSION = 'v1.2.3';

our $TYPE_SIMPLE       = 0x00;
our $TYPE_BYTES        = 0x02;
our $TYPE_UUID         = 0x03;
our $TYPE_MD5          = 0x05;
our $TYPE_USER_DEFINED = 0x80;

sub new {
    my ( $class, $data, $type ) = @_;
    $type ||= $TYPE_SIMPLE;
    my $self = bless { type => $type }, $class;
    $self->data($data);
    return $self;
}

sub data {
    my ( $self, $data ) = @_;
    if ( defined $data ) {
        $data = [ unpack( 'C*', $data ) ] unless ref $data eq 'ARRAY';
        $self->{data} = $data;
    }
    return $self->{data};
}

sub type {
    return $_[0]->{type};
}

# alias for compatibility with BSON::Bytes
sub subtype {
    return $_[0]->{type};
}

sub to_s {
    my $self = shift;
    my @data = @{ $self->data };
    return pack( 'l<C*', scalar(@data), $self->type, @data );
}

use overload '""' => \&to_s;

1;

__END__

=for Pod::Coverage new data type subtype to_s

=head1 DESCRIPTION

This module has been deprecated as it was horribly inefficient (unpacking
binary data to individual single-byte elements of an array!) and had a
weird API that was not compatible with the existing MongoDB Binary wrapper
implementation on CPAN.

You are strongly encouraged to use L<BSON::Bytes> instead.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
