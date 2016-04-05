use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use lib 't/lib';
use TestUtils;

use BSON qw/encode decode/;
use BSON::Types ':all';

my ( $bson, $expect, $hash );

my $packed = BSON::OID::generate_oid();
my $hexoid = unpack( "H*", $packed );

# test constructor
is( length( bson_oid()->oid ), 12,      "empty bson_oid() generates new OID" );
is( bson_oid($packed)->oid,    $packed, "bson_oid(\$packed) returns packed" );
is( bson_oid($hexoid)->oid,    $packed, "bson_oid(\$hexoid) returns packed" );

is( length( BSON::OID->new()->oid ), 12,
    "empty BSON::OID->new() generates new OID" );
is( BSON::OID->new(oid => $packed)->oid,
    $packed, "BSON::OID->new(\$packed) returns packed" );

# test overloading
is( bson_oid($packed), $hexoid, "BSON::OID string overload" );

# BSON::OID -> BSON::OID
$bson = $expect = encode( { A => bson_oid($packed) } );
$hash = decode($bson);
is( ref( $hash->{A} ), 'BSON::OID', "BSON::OID->BSON::OID" );
is( "$hash->{A}",      $hexoid,     "value correct" );

# BSON::ObjectId (deprecated) -> BSON::OID
$hash = encode( { A => BSON::ObjectId->new($packed) } );
$hash = decode($bson);
is( ref( $hash->{A} ), 'BSON::OID', "BSON::ObjectId->BSON::OID" );
is( "$hash->{A}",      $hexoid,     "value correct" );
is( $bson,             $expect,     "BSON correct" );

# MongoDB::OID (deprecated) -> BSON::OID
SKIP: {
    eval { require MongoDB; require MongoDB::OID; };
    skip( "MongoDB::OID not installed", 2 )
      unless $INC{'MongoDB/OID.pm'};
    $bson = encode( { A => MongoDB::OID->new( value => $hexoid ) } );
    $hash = decode($bson);
    is( ref( $hash->{A} ), 'BSON::OID', "MongoDB::OID->BSON::OID" );
    is( "$hash->{A}",      $hexoid,     "value correct" );
    is( $bson,             $expect,     "BSON correct" );
}

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:
