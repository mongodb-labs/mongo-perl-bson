use 5.010001;
use strict;
use warnings;

package BSON::Bytes;
# ABSTRACT: BSON type wrapper for binary byte strings

use version;
our $VERSION = 'v1.6.8';

use MIME::Base64 ();
use Tie::IxHash;

use Moo;

=attr data

A scalar, interpreted as bytes.  (I.e. "character" data should be encoded
to bytes.)  It defaults to the empty string.

=attr subtype

A numeric BSON subtype between 0 and 255.  This defaults to 0 and generally
should not be modified.  Subtypes 128 to 255 are "user-defined".

=cut

has [qw/data subtype/] => (
    is      => 'ro',
);

use namespace::clean -except => 'meta';

sub BUILD {
    my ($self) = @_;
    $self->{data} = '' unless defined $self->{data};
    $self->{subtype} = 0 unless defined $self->{subtype};
}

=method TO_JSON

Returns Base64 encoded string equivalent to the data attribute.

If the C<BSON_EXTJSON> option is true, it will instead be compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$binary" : "<base64 data>", "$type" : "<type>"}

=cut

sub TO_JSON {
    return MIME::Base64::encode_base64($_[0]->{data}, "") unless $ENV{BSON_EXTJSON};

    my %data;
    tie( %data, 'Tie::IxHash' );
    $data{base64} = MIME::Base64::encode_base64($_[0]->{data}, "");
    $data{subType} = sprintf("%02x",$_[0]->{subtype});

    return {
        '$binary' => \%data,
    };
}

use overload (
    q{""}    => sub { $_[0]->{data} },
    fallback => 1,
);

# backwards compatibility alias
*type = \&subtype;

1;

__END__

=for Pod::Coverage BUILD type

=head1 SYNOPSIS

    use BSON::Types ':all';

    $bytes = bson_bytes( $bytestring );
    $bytes = bson_bytes( $bytestring, $subtype );

=head1 DESCRIPTION

This module provides a BSON type wrapper for binary data represented
as a string of bytes.

=head1 OVERLOADING

The stringification operator (C<"">) is overloaded to return the binary data
and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
