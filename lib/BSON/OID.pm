use 5.008001;
use strict;
use warnings;

package BSON::OID;
# ABSTRACT: BSON type wrapper for Object IDs

our $VERSION = '0.17';

use Carp;
use Digest::MD5 'md5';
use Sys::Hostname;
use threads::shared; # NOP if threads.pm not loaded

use Moo;

=attr oid

A 12-byte (packed) Object ID (OID) string.  If not provided, a new OID
will be generated.

=cut

has 'oid' => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

# OID generation
{
    my $_inc : shared;
    {
        lock($_inc);
        $_inc = int( rand(0xFFFFFF) );
    }

    my $_host = substr( md5(hostname), 0, 3 );

    #<<<
    sub _packed_oid {
        return pack(
            'Na3na3', time, $_host, $$ % 0xFFFF,
            substr( pack( 'N', do { lock($_inc); $_inc++; $_inc %= 0xFFFFFF }), 1, 3)
        );
    }
    #>>>

    # see if v1.x MongoDB::BSON can do OIDs for us
    BEGIN {
        if ( $INC{'MongoDB'} && MongoDB::BSON->can('generate_oid') ) {
            *_generate_oid = sub { pack( "H*", MongoDB::BSON::generate_oid() ) };
        }
        else {
            *_generate_oid = \&_packed_oid;
        }
    }
}

sub BUILD {
    my ($self) = @_;

    $self->{oid} = _generate_oid() unless defined $self->{oid};
    croak "Invalid 'oid' field: OIDs must be 12 bytes"
      unless length( $self->oid ) == 12;
    return;
}

=method hex

Returns the C<oid> attributes as 24-byte hexadecimal value

=cut

sub hex {
    my ($self) = @_;
    return defined $self->{_hex}
      ? $self->{_hex}
      : ( $self->{_hex} = unpack( "H*", $self->{oid} ) );
}

=method get_time

Returns a number corresponding to the portion of the C<oid> value that
represents seconds since the epoch.

=cut

sub get_time {
    return unpack( "N", substr( $_[0]->{oid}, 0, 4 ) );
}

# for testing purposes
sub _get_pid {
    return unpack( "n", substr( $_[0]->{oid}, 7, 2 ) );
}

=method TO_JSON

Returns a string for this OID, with the OID given as 24 hex digits.

If the C<BSON_EXTJSON> option is true, it will instead be compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$oid" : "012345678901234567890123"}

=cut

sub TO_JSON {
    return $_[0]->hex unless $ENV{BSON_EXTJSON};
    return {'$oid' => $_[0]->hex };
}

# For backwards compatibility
*to_string = \&hex;
*value = \&hex;

use overload (
    '""'     => \&hex,
    fallback => 1,
);

1;

__END__

=for Pod::Coverage op_eq to_string value generate_oid BUILD

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $oid  = bson_oid();

    my $bytes = $oid->oid;
    my $hex   = $oid->hex;

=head1 DESCRIPTION

This module provides a wrapper around a BSON L<Object
ID|https://docs.mongodb.com/manual/reference/method/ObjectId/>.

=head1 OVERLOAD

The string operator is overloaded so any string operations will actually use
the 24-character hex value of the OID.  Fallback overloading is enabled.

=head1 THREADS

This module is thread safe.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
