use 5.008001;
use strict;
use warnings;

package BSON::Types;
# ABSTRACT: Helper functions to wrap BSON type classes

use version;
our $VERSION = 'v1.2.1';

use base 'Exporter';
our @EXPORT_OK = qw(
    bson_bool
    bson_bytes
    bson_code
    bson_dbref
    bson_decimal128
    bson_doc
    bson_double
    bson_int32
    bson_int64
    bson_maxkey
    bson_minkey
    bson_oid
    bson_raw
    bson_regex
    bson_string
    bson_time
    bson_timestamp
);
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

use Carp;

use boolean;            # bson_bool
use BSON::Bytes;        # bson_bytes
use BSON::Code;         # bson_code
use BSON::DBRef;        # bson_dbref
use BSON::Decimal128;   # bson_decimal128
use BSON::Doc;          # bson_doc
use BSON::Double;       # bson_double
use BSON::Int32;        # bson_int32
use BSON::Int64;        # bson_int64
use BSON::MaxKey;       # bson_maxkey
use BSON::MinKey;       # bson_minkey
use BSON::OID;          # bson_oid
use BSON::Raw;          # bson_raw
use BSON::Regex;        # bson_regex
use BSON::String;       # bson_string
use BSON::Time;         # bson_time
use BSON::Timestamp;    # bson_timestamp

# deprecated, but load anyway
use BSON::Bool;
use BSON::Binary;
use BSON::ObjectId;

=func bson_bytes

    $bytes = bson_bytes( $byte_string );
    $bytes = bson_bytes( $byte_string, $subtype );

This function returns a L<BSON::Bytes> object wrapping the provided string.
A numeric subtype may be provided as a second argument, but this is not
recommended for new applications.

=cut

sub bson_bytes {
    return BSON::Bytes->new(
        data => ( defined( $_[0] ) ? $_[0] : '' ),
        subtype => ( $_[1] || 0 ),
    );
}

=func bson_code

    $code = bson_code( $javascript );
    $code = bson_code( $javascript, $hashref );

This function returns a L<BSON::Code> object wrapping the provided Javascript
code.  An optional hashref representing variables in scope for the function
may be given as well.

=cut

sub bson_code {
    return BSON::Code->new unless defined $_[0];
    return BSON::Code->new( code => $_[0] ) unless defined $_[1];
    return BSON::Code->new( code => $_[0], scope => $_[1] );
}

=func bson_dbref

    $dbref = bson_dbref( $object_id, $collection_name );

This function returns a L<BSON::DBRef> object wrapping the provided Object ID
and collection name.

=cut

sub bson_dbref {
    croak "Arguments to bson_dbref must an id and collection name"
      unless @_ == 2;
    return BSON::DBRef->new( id => $_[0], ref => $_[1] );
}

=func bson_decimal128

    $decimal = bson_decimal128( "0.12" );
    $decimal = bson_decimal128( "1.23456789101112131415116E-412" );

This function returns a L<BSON::Decimal128> object wrapping the provided
decimal B<string>.  Unlike floating point values, this preserves exact
decimal precision.

=cut

sub bson_decimal128 {
    return BSON::Decimal128->new( value => defined $_[0] ? $_[0] : 0 )
}

=func bson_doc

    $doc = bson_doc( first => "hello, second => "world" );

This function returns a L<BSON::Doc> object, which preserves the order
of the provided key-value pairs.

=cut

sub bson_doc {
    return BSON::Doc->new( @_ );
}

=func bson_double

    $double = bson_double( 1.0 );

This function returns a L<BSON::Double> object wrapping a native
double value.  This ensures it serializes to BSON as a double rather
than a string or integer given Perl's lax typing for scalars.

=cut

sub bson_double {
    return BSON::Double->new( value => $_[0] )
}

=func bson_int32

    $int32 = bson_int32( 42 );

This function returns a L<BSON::Int32> object wrapping a native
integer value.  This ensures it serializes to BSON as an Int32 rather
than a string or double given Perl's lax typing for scalars.

=cut

sub bson_int32 {
    return BSON::Int32->new unless defined $_[0];
    return BSON::Int32->new( value => $_[0] )
}

=func bson_int64

    $int64 = bson_int64( 0 ); # 64-bit zero

This function returns a L<BSON::Int64> object, wrapping a native
integer value.  This ensures it serializes to BSON as an Int64 rather
than a string or double given Perl's lax typing for scalars.

=cut

sub bson_int64 {
    return BSON::Int64->new unless defined $_[0];
    return BSON::Int64->new( value => $_[0] )
}

=func bson_maxkey

    $maxkey = bson_maxkey();

This function returns a singleton representing the "maximum key"
BSON type.

=cut

sub bson_maxkey {
    return BSON::MaxKey->new;
}

=func bson_minkey

    $minkey = bson_minkey();

This function returns a singleton representing the "minimum key"
BSON type.

=cut

sub bson_minkey {
    return BSON::MinKey->new;
}

=func bson_oid

    $oid = bson_oid();         # generate a new one
    $oid = bson_oid( $bytes ); # from 12-byte packed OID
    $oid = bson_oid( $hex   ); # from 24 hex characters

This function returns a L<BSON::OID> object wrapping a 12-byte MongoDB Object
ID.  With no arguments, a new, unique Object ID is generated instead.  If
24 hexadecimal characters are given, they will be packed into a 12-byte
Object ID.

=cut

sub bson_oid {
    return BSON::OID->new unless defined $_[0];
    return BSON::OID->new( oid => $_[0] ) if length( $_[0] ) == 12;
    return BSON::OID->new( oid => pack( "H*", $_[0] ) )
      if $_[0] =~ m{\A[0-9a-f]{24}\z}i;
    croak "Arguments to bson_oid must be 12 packed bytes or 24 bytes of hex";
}

=func bson_raw

    $raw = bson_raw( $bson_encoded );

This function returns a L<BSON::Raw> object wrapping an already BSON-encoded
document.

=cut

sub bson_raw {
    return BSON::Raw->new( bson => $_[0] );
}

=func bson_regex

    $regex = bson_regex( $pattern );
    $regex = bson_regex( $pattern, $flags );

This function returns a L<BSON::Regex> object wrapping a PCRE pattern and
optional flags.

=cut

sub bson_regex {
    return BSON::Regex->new unless defined $_[0];
    return BSON::Regex->new( pattern => $_[0] ) unless defined $_[1];
    return BSON::Regex->new( pattern => $_[0], flags => $_[1] );
}

=func bson_string

    $string = bson_string( "08544" );

This function returns a L<BSON::String> object, wrapping a native
string value.  This ensures it serializes to BSON as a UTF-8 string rather
than an integer or double given Perl's lax typing for scalars.

=cut

sub bson_string {
    return BSON::String->new( value => $_[0] );
}

=func bson_time

    $time = bson_time( $seconds_from_epoch );

This function returns a L<BSON::Time> object representing a UTC date and
time to millisecond precision.  The argument must be given as a number of
seconds relative to the Unix epoch (positive or negative).  The number may
be a floating point value for fractional seconds.  If no argument is
provided, the current time from L<Time::HiRes> is used.

=cut

sub bson_time {
    return BSON::Time->new unless defined $_[0];
    return BSON::Time->new( value => 1000 * $_[0] );
}

=func bson_timestamp

    $timestamp = bson_timestamp( $seconds_from_epoch, $increment );

This function returns a L<BSON::Timestamp> object.  It is not recommended
for general use.

=cut

sub bson_timestamp {
    return BSON::Timestamp->new unless defined $_[0];
    return BSON::Timestamp->new( seconds => $_[0] ) unless defined $_[1];
    return BSON::Timestamp->new( seconds => $_[0], increment => $_[1] );
}

=func bson_bool (DISCOURAGED)

    # for consistency with other helpers
    $bool = bson_bool( $expression );

    # preferred for efficiency
    use boolean;
    $bool = boolean( $expression );

This function returns a L<boolean> object (true or false) based on the
provided expression (or false if no expression is provided).  It is
provided for consistency so that all BSON types have a corresponding helper
function.

For efficiency, use C<boolean::boolean()> directly, instead.

=cut

sub bson_bool {
    return boolean($_[0]);
}

1;

__END__

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use BSON::Types ':all';

    $int32   = bson_int32(42);
    $double  = bson_double(3.14159);
    $decimal = bson_decimal("24.01");
    $time    = bson_time(); # now
    ...

=head1 DESCRIPTION

This module provides helper functions for BSON type wrappers.  Type
wrappers use objects corresponding to BSON types to represent data that
would have ambiguous type or don't have a native Perl representation

For example, because Perl scalars can represent strings, integers or
floating point numbers, the serialization rules depend on various
heuristics.  By wrapping a Perl scalar with a class, such as
L<BSON::Int32>, users can specify exactly how a scalar should serialize to
BSON.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
