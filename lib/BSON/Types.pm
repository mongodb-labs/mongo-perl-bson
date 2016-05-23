use 5.008001;
use strict;
use warnings;

package BSON::Types;
# ABSTRACT: Helper functions to wrap BSON type classes

our $VERSION = '0.17';

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

sub bson_bool {
    return boolean($_[0]);
}

sub bson_bytes {
    return BSON::Bytes->new(
        data => ( defined( $_[0] ) ? $_[0] : '' ),
        subtype => ( $_[1] || 0 ),
    );
}

sub bson_code {
    return BSON::Code->new unless defined $_[0];
    return BSON::Code->new( code => $_[0] ) unless defined $_[1];
    return BSON::Code->new( code => $_[0], scope => $_[1] );
}

sub bson_dbref {
    croak "Arguments to bson_dbref must an id and collection name"
      unless @_ == 2;
    return BSON::DBRef->new( id => $_[0], ref => $_[1] );
}

sub bson_decimal128 {
    return BSON::Decimal128->new( value => defined $_[0] ? $_[0] : 0 )
}

sub bson_doc {
    return BSON::Doc->new( @_ );
}

sub bson_double {
    return BSON::Double->new( value => $_[0] )
}

sub bson_int32 {
    return BSON::Int32->new unless defined $_[0];
    return BSON::Int32->new( value => $_[0] )
}

sub bson_int64 {
    return BSON::Int64->new unless defined $_[0];
    return BSON::Int64->new( value => $_[0] )
}

sub bson_maxkey {
    return BSON::MaxKey->new;
}

sub bson_minkey {
    return BSON::MinKey->new;
}

sub bson_oid {
    return BSON::OID->new unless defined $_[0];
    return BSON::OID->new( oid => $_[0] ) if length( $_[0] ) == 12;
    return BSON::OID->new( oid => pack( "H*", $_[0] ) )
      if $_[0] =~ m{\A[0-9a-f]{24}\z}i;
    croak "Arguments to bson_oid must be 12 packed bytes or 24 bytes of hex";
}

sub bson_raw {
    return BSON::Raw->new( bson => $_[0] );
}

sub bson_regex {
    return BSON::Regex->new unless defined $_[0];
    return BSON::Regex->new( pattern => $_[0] ) unless defined $_[1];
    return BSON::Regex->new( pattern => $_[0], flags => $_[1] );
}

sub bson_string {
    return BSON::String->new( value => $_[0] );
}

sub bson_time {
    return BSON::Time->new unless defined $_[0];
    return BSON::Time->new( value => 1000 * $_[0] );
}

sub bson_timestamp {
    return BSON::Timestamp->new unless defined $_[0];
    return BSON::Timestamp->new( seconds => $_[0] ) unless defined $_[1];
    return BSON::Timestamp->new( seconds => $_[0], increment => $_[1] );
}

1;

# vim: set ts=4 sts=4 sw=4 et tw=75:
