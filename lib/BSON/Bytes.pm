use 5.008001;
use strict;
use warnings;

package BSON::Bytes;
# ABSTRACT: BSON type wrapper for binary byte strings

our $VERSION = '0.17';

use MIME::Base64 ();

use Class::Tiny qw/data subtype/;

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
    return {
        '$binary' => MIME::Base64::encode_base64($_[0]->{data}, ""),
        '$type' => sprintf("%02x",$_[0]->{subtype}),
    };
}

use overload (
    q{""}    => sub { $_[0]->{data} },
    fallback => 1,
);

BEGIN {
    *type = \&subtype;
}

1;
