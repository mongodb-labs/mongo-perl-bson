use 5.008001;
use strict;
use warnings;

package BSON::OID;
# ABSTRACT: BSON type wrapper for Object IDs

use version;
our $VERSION = 'v1.1.0';

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

        croak "BSON::OID::from_epoch: second argument must be an interger"
          unless looks_like_number( $fill );

        # Zero-filled OID with custom time
        if ($fill == 0) {
            return pack('Na8', $time, "\0" x 8);
        }

        # Random OID with custom time
        if (HAS_INT64) {
           return pack( 'Nq', $time, (rand(INT64_MAX) + 1) );
        }

        sub randmax32 () { rand(INT32_MAX) + 1 }
        return pack('N3', $time, randmax32, randmax32);
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

=method from_epoch

Returns a new OID generated using the given epoch time (in seconds) to be
used in queries.

B<Warning!> You should never insert documents with an OID generated with
this method. It is unsafe because the uniqueness of the OID is no longer
guaranteed.

There are 3 ways to use this method:

  my $oid = BSON::OID->from_epoch(1467545180);

This generates a standard OID with given epoch. You should not use this
form in newly written code. It is here for compatibility.

  my $oid = BSON::OID->from_epoch(1467545180, 0);

The additional C<0> at the end means you want a zero-ed OID. All the fields
will be set to zero except the date. This is particularly useful when looking
for documents by their insertion date: you can simply look for OIDs which are
greater or lower than the one generated with this method.

  my $oid = BSON::OID->from_epoch(1467545180, 1);

Any value different from zero as a second argument means you want a randomized
OID: the date field is set to the given epoch but the rest of the OID is just
a 64 bit random number. This should be enough to avoid collisions in most cases.

=cut

sub from_epoch {
    my ($self, $epoch, $fill) = @_;

    croak "BSON::OID::from_epoch expects an epoch in seconds, not '$epoch'"
      unless looks_like_number( $epoch );

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
    my $oid  = bson_oid->from_epoch(1467543496);

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
