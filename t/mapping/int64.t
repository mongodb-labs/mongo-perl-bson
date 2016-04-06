use 5.0001;
use strict;
use warnings;

use Test::More 0.96;
use Math::BigInt;

use lib 't/lib';
use TestUtils;

use BSON qw/encode decode/;
use BSON::Types ':all';

my ($hash, $bson, $expect);

my $bigpos = Math::BigInt->new("9223372036854775808");
my $bigneg = Math::BigInt->new("-9223372036854775809");

# test constructor
packed_is( "q", bson_int64(), 0, "empty bson_int64() is 0" );
packed_is( "q", BSON::Int64->new, 0, "empty constructor is 0" );

# test constructor errors; these will wind up doubles
eval { bson_int64(2**63) };
like( $@, qr/can't fit/, "bson_int64(2**64) fails" );
eval { bson_int64(-2**63-1) };
like( $@, qr/can't fit/, "bson_int64(-2**64-1) fails" );

# test constructor errors with Math::BigInt
eval { bson_int64($bigpos) };
like( $@, qr/can't fit/, "bson_int64(big BigInt) fails" );
eval { bson_int64($bigneg) };
like( $@, qr/can't fit/, "bson_int64(-big BigInt) fails" );


# test overloading
packed_is( "q", bson_int64(2**32+1), 2**32+1, "overloading correct" );

subtest 'native' => sub {
    # int64 -> int64
    $bson = $expect = encode( { A => 2**32+1 } );
    $hash = decode( $bson );
    is( sv_type( $hash->{A} ), 'IV', "int64->int64" );
    packed_is( "q", $hash->{A}, 2**32+1, "value correct" );

    # BSON::Int64 -> int64
    $bson = encode( { A => bson_int64(2**32+1) } );
    $hash = decode( $bson );
    is( sv_type( $hash->{A} ), 'IV', "BSON::Int64->int64" );
    packed_is( "q", $hash->{A}, 2**32+1, "value correct" );
    bytes_are( $bson, $expect, "BSON correct" );

    # BSON::Int64(string) -> int64
    $bson = encode( { A => bson_int64("0") } );
    $hash = decode( $bson );
    is( sv_type( $hash->{A} ), 'IV', "BSON::Int64->int64" );
    packed_is( "q", $hash->{A}, 0, "value correct" );

    # Math::BigInt -> int64
    $bson = encode( { A => Math::BigInt->new("0") } );
    $hash = decode( $bson );
    is( sv_type( $hash->{A} ), 'IV', "Math::BigInt->int64" );
    packed_is( "q", $hash->{A}, 0, "value correct" );

    # Math::Int64 -> int64
    SKIP: {
        eval { require Math::Int64 };
        skip( "Math::Int64 not installed", 2 )
            unless $INC{'Math/Int64.pm'};
        $bson = encode( { A => Math::Int64::int64("0") } );
        $hash = decode( $bson );
        is( sv_type( $hash->{A} ), 'IV', "Math::Int64->int64" );
        packed_is( "q", $hash->{A}, 0, "value correct" );
    }

};

subtest 'wrapped' => sub {
    # int64 -> BSON::Int64
    $bson = $expect = encode( { A => 2**32+1 } );
    $hash = decode( $bson, wrap_numbers => 1 );
    is( ref( $hash->{A} ), 'BSON::Int64', "int64->BSON::Int64" );
    packed_is( "q", $hash->{A}, 2**32+1, "value correct" );

    # BSON::Int64 -> BSON::Int64
    $bson = encode( { A => bson_int64(2**32+1) } );
    $hash = decode( $bson, wrap_numbers => 1 );
    is( ref( $hash->{A} ), 'BSON::Int64', "int64->BSON::Int64" );
    packed_is( "q", $hash->{A}, 2**32+1, "value correct" );
    bytes_are( $bson, $expect, "BSON correct" );

    # BSON::Int64(string) -> BSON::Int64
    $bson = encode( { A => bson_int64("0") } );
    $hash = decode( $bson, wrap_numbers => 1 );
    is( ref( $hash->{A} ), 'BSON::Int64', "int64->BSON::Int64" );
    packed_is( "q", $hash->{A}, 0, "value correct" );

    # Math::BigInt -> BSON::Int64
    $bson = encode( { A => Math::BigInt->new("0") } );
    $hash = decode( $bson, wrap_numbers => 1 );
    is( ref( $hash->{A} ), 'BSON::Int64', "Math::BigInt->BSON::Int64" );
    packed_is( "q", $hash->{A}, 0, "value correct" );

    # Math::Int64 -> BSON::Int64
    SKIP: {
        eval { require Math::Int64 };
        skip( "Math::Int64 not installed", 2 )
            unless $INC{'Math/Int64.pm'};
        $bson = encode( { A => Math::Int64::int64("0") } );
        $hash = decode( $bson, wrap_numbers => 1 );
        is( ref( $hash->{A} ), 'BSON::Int64', "Math::Int64->BSON::Int64" );
        packed_is( "q", $hash->{A}, 0, "value correct" );
    }

};

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:
