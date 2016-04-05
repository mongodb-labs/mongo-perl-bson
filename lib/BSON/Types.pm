use 5.008001;
use strict;
use warnings;

package BSON::Types;
# ABSTRACT: Helper functions to wrap BSON type classes

our $VERSION = '0.17';

use base 'Exporter';
our @EXPORT_OK = qw(
    bson_bytes
    bson_doc
    bson_double
    bson_int32
    bson_int64
    bson_maxkey
    bson_minkey
    bson_oid
    bson_raw
    bson_string
    bson_time
);
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

use Carp;
use Tie::IxHash;

use BSON::Bool;
use BSON::Bytes;
use BSON::Code;
use BSON::Doc;
use BSON::Double;
use BSON::Int32;
use BSON::Int64;
use BSON::MaxKey;
use BSON::MinKey;
use BSON::OID;
use BSON::Raw;
use BSON::Regex;
use BSON::String;
use BSON::Time;
use BSON::Timestamp;

# deprecated, but load anyway
use BSON::Binary;
use BSON::ObjectId;

sub bson_bytes {
    return BSON::Bytes->new(
        data => ( defined( $_[0] ) ? $_[0] : '' ),
        subtype => ( $_[1] || 0 ),
    );
}

sub bson_doc {
    return BSON::Doc->new( @_ );
}

sub bson_double {
    return BSON::Double->new( value => $_[0] )
}

sub bson_int32 {
    return BSON::Int32->new( value => $_[0] )
}

sub bson_int64 {
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
    return BSON::Raw->new( value => $_[0] );
}

sub bson_string {
    return BSON::String->new( value => $_[0] );
}

sub bson_time {
    return BSON::Time->new( value => 1000 * $_[0] );
}

1;
