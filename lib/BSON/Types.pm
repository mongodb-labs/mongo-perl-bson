use 5.008001;
use strict;
use warnings;

package BSON::Types;
# ABSTRACT: Helper functions to wrap BSON type classes

our $VERSION = '0.17';

use base 'Exporter';
our @EXPORT_OK = qw(
    bson_bytes
    bson_double
    bson_int32
    bson_int64
    bson_maxkey
    bson_minkey
    bson_string
    bson_time
);

use Carp;
use Tie::IxHash;

use BSON::Bool;
use BSON::Bytes;
use BSON::Code;
use BSON::Double;
use BSON::Int32;
use BSON::Int64;
use BSON::MaxKey;
use BSON::MinKey;
use BSON::OID;
use BSON::Regex;
use BSON::String;
use BSON::Time;
use BSON::Timestamp;

# deprecated, but load anyway
use BSON::Binary;
use BSON::ObjectId;

sub bson_bytes {
    return BSON::Bytes->new( data => $_[0], subtype => ( $_[1] || 0 ) );
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

sub bson_string {
    return BSON::String->new( value => $_[0] );
}

sub bson_time {
    return BSON::Time->new( value => 1000 * $_[0] );
}

1;
