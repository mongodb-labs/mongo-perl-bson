use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use lib 't/lib';
use TestUtils;

use BSON;
use BSON::Types ':all';

sub _BSON { BSON->new(@_) }

subtest "error_callback" => sub {
    my $bad = "\x05\x00\x00\x00\x01";
    my @errs;
    my $obj = _BSON( error_callback => sub { push @errs, [@_] } );
    $obj->decode_one($bad);
    is( 0+ @errs, 1, "error_callback ran" );
    like( $errs[0][0], qr/not null terminated/, "error_callback arg 0" );
    is( ${ $errs[0][1] }, $bad,         "error_callback arg 1" );
    is( $errs[0][2],      'decode_one', "error_callback arg 2" );
};

subtest "invalid_char" => sub {
    my $obj = _BSON( invalid_chars => '.' );
    eval { $obj->encode_one( { "example.com" => 1 } ) };
    like(
        $@,
        qr/key 'example\.com' has invalid character\(s\) '\.'/,
        "invalid char throws exception"
    );

    $obj = _BSON( invalid_chars => '.$' );
    eval { $obj->encode_one( { "example.c\$om" => 1 } ) };
    like(
        $@,
        qr/key 'example\.c\$om' has invalid character\(s\) '\.\$'/,
        "multi-invalid chars throws exception"
    );
};

subtest "max_length" => sub {
    my $obj = _BSON( max_length => 20 );

    my $hash = { "example.com" => "a" x 100 };
    my $encoded = _BSON->encode_one($hash);

    eval { $obj->encode_one($hash) };
    like(
        $@,
        qr/encode_one.*Document exceeds maximum size 20/,
        "max_length exceeded during encode_one"
    );

    eval { $obj->decode_one($encoded) };
    like(
        $@,
        qr/decode_one.*Document exceeds maximum size 20/,
        "max_length exceeded during decode_one"
    );
};

subtest "op-char" => sub {
    my $obj = _BSON( op_char => '-' );

    my $hash = { -inc => { x => 1 } };
    my $expect = { '$inc' => { x => 1 } };
    my $got =$obj->decode_one( $obj->encode_one($hash) );

    is_deeply( $got, $expect, "op-char converts to '\$'" )
      or diag explain $got;
};

subtest "prefer_numeric" => sub {
    my $hash = { x => "42" };

    my $pn0 = _BSON( prefer_numeric => 0 );
    my $pn1 = _BSON( prefer_numeric => 1 );
    my $dec = _BSON( wrap_numbers   => 1, wrap_strings => 1 );

    is( ref( $dec->decode_one( $pn1->encode_one($hash) )->{x} ),
        'BSON::Int32', 'prefer_numeric => 1' );
    is( ref( $dec->decode_one( $pn0->encode_one($hash) )->{x} ),
        'BSON::String', 'prefer_numeric => 0' );
};

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

