use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;
BEGIN { $ENV{PERL_BSON_BACKEND} = "" }
BEGIN { $INC{"BSON/XS.pm"} = undef }

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use lib 't/lib';
use TestUtils;

use BSON qw/encode decode/;
use BSON::Types ':all';

my ( $bson, $expect, $hash );

my $packed = BSON::OID::_generate_oid();
my $hexoid = unpack( "H*", $packed );

# test constructors
is( length( bson_oid()->oid ), 12,      "empty bson_oid() generates new OID" );
is( length( bson_oid()->from_epoch(time)->oid ), 12,
    "from_epoch(time) generates new OID" );
is( length( bson_oid()->from_epoch(time, 0)->oid ), 12,
    "from_epoch(time, 0) generates new OID" );
is( length( bson_oid()->from_epoch(time, 1)->oid ), 12,
    "from_epoch(time, 1) generates new OID" );
is( bson_oid($packed)->oid,    $packed, "bson_oid(\$packed) returns packed" );
is( bson_oid($hexoid)->oid,    $packed, "bson_oid(\$hexoid) returns packed" );

is( length( BSON::OID->new()->oid ), 12,
    "empty BSON::OID->new() generates new OID" );
is( length( BSON::OID->from_epoch(time)->oid ), 12,
    "empty BSON::OID->from_epoch(time) generates new OID" );
is( BSON::OID->new(oid => $packed)->oid,
    $packed, "BSON::OID->new(\$packed) returns packed" );

# test overloading
is( bson_oid($packed), $hexoid, "BSON::OID string overload" );

# BSON::OID -> BSON::OID
$bson = $expect = encode( { A => bson_oid($packed) } );
$hash = decode($bson);
is( ref( $hash->{A} ), 'BSON::OID', "BSON::OID->BSON::OID" );
is( "$hash->{A}",      $hexoid,     "value correct" );

# BSON::OID from_epoch
my $epoch = 1467545180;
my $packed_zero = pack('N3', $epoch, 0, 0);
is( BSON::OID->from_epoch($epoch)->get_time, $epoch, "from_epoch roundtrip ok" );
is( BSON::OID->from_epoch($epoch, 0)->oid, $packed_zero,
    "from_epoch(time, 0) OID is correct" );
is( BSON::OID->from_epoch($epoch, 1)->get_time, $epoch,
    "from_epoch(time, 1) roundtrip ok" );
is( bson_oid->from_epoch($epoch, 1)->get_time, $epoch,
    "from_epoch(time, 1) roundtrip ok" );

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
