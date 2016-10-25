use 5.008001;
use strict;
use warnings;

package BSON::OID;
# ABSTRACT: BSON type wrapper for Object IDs

use version;
our $VERSION = 'v1.2.2';

use Carp;
use Config;
use Digest::MD5 'md5';
use Scalar::Util 'looks_like_number';
use Sys::Hostname;
use threads::shared; # NOP if threads.pm not loaded

use constant {
    HAS_INT64 => $Config{use64bitint},
    INT64_MAX => 9223372036854775807,
    INT32_MAX => 2147483647,
    ZERO_FILL => ("\0" x 8),
};

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
        my $time = defined $_[0] ? $_[0] : time;
        return pack(
            'Na3na3', $time, $_host, $$ % 0xFFFF,
            substr( pack( 'N', do { lock($_inc); $_inc++; $_inc %= 0xFFFFFF }), 1, 3)
        );
    }
    sub _packed_oid_special {
        my ($time, $fill) = @_;
        return pack('Na8', $time, $fill);
    }
    #>>>

    # see if we have XS OID generation
    BEGIN {
        if ( $INC{'BSON/XS.pm'} && BSON::XS->can('_generate_oid') ) {
            *_generate_oid = \&BSON::XS::_generate_oid;
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

=method new

    my $oid = BSON::OID->new;

    my $oid = BSON::OID->new( oid => $twelve_bytes );

This is the preferred way to generate an OID.  Without arguments, a
unique OID will be generated.  With a 12-byte string, an object can
be created around an existing OID byte-string.

=method from_epoch

    # generate a new OID

    my $oid = BSON::OID->from_epoch( $epoch, 0); # other bytes zeroed
    my $oid = BSON::OID->from_epoch( $epoch, $eight_more_bytes );

    # reset an existing OID

    $oid->from_epoch( $new_epoch, 0 );
    $oid->from_epoch( $new_epoch, $eight_more_bytes );

B<Warning!> You should not rely on this method for a source of unique IDs.
Use this method for query boundaries, only.

An OID is a twelve-byte string.  Typically, the first four bytes represent
integer seconds since the Unix epoch in big-endian format.  The remaining
bytes ensure uniqueness.

With this method, the first argument to this method is an epoch time (in
integer seconds).  The second argument is the remaining eight-bytes to
append to the string.

When called as a class method, it returns a new BSON::OID object.  When
called as an object method, it mutates the existing internal OID value.

As a special case, if the second argument is B<defined> and zero ("0"),
then the remaining bytes will be zeroed.

    my $oid = BSON::OID->from_epoch(1467545180, 0);

This is particularly useful when looking for documents by their insertion
date: you can simply look for OIDs which are greater or lower than the one
generated with this method.

For backwards compatibility with L<Mango>, if called without a second
argument, the method generates the remainder of the fields "like usual".
This is equivalent to calling C<< BSON::OID->new >> and replacing the first
four bytes with the packed epoch value.

    # UNSAFE: don't do this unless you have to

    my $oid = BSON::OID->from_epoch(1467545180);

If you insist on creating a unique OID with C<from_epoch>, set the
remaining eight bytes in a way that guarantees thread-safe uniqueness, such
as from a reliable source of randomness (see L<Crypt::URandom>).

  use Crypt::Random 'urandom';
  my $oid = BSON::OID->from_epoch(1467545180, urandom(8));

=cut

sub from_epoch {
    my ($self, $epoch, $fill) = @_;

    croak "BSON::OID::from_epoch expects an epoch in seconds, not '$epoch'"
      unless looks_like_number( $epoch );

    $fill = ZERO_FILL if defined $fill && looks_like_number($fill) && $fill == 0;

    croak "BSON::OID expects the second argument to be missing, 0 or an 8-byte string"
      unless @_ == 2 || length($fill) == 8;

    my $oid = defined $fill
      ? _packed_oid_special($epoch, $fill)
      : _packed_oid($epoch);

    if (ref $self) {
        $self->{oid} = $oid;
    }
    else {
        $self = $self->new(oid => $oid);
    }

    return $self;
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
    my $oid  = bson_oid->from_epoch(1467543496, 0); # for queries only

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
