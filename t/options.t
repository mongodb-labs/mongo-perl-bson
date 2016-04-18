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
    my $b = _BSON( error_callback => sub { push @errs, [@_] } );
    $b->decode_one($bad);
    is( 0+ @errs, 1, "error_callback ran" );
    like( $errs[0][0], qr/not null terminated/, "error_callback arg 0" );
    is( ${$errs[0][1]}, $bad, "error_callback arg 1" );
    is( $errs[0][2], 'decode_one', "error_callback arg 2" );
};

subtest "invalid_char" => sub {
    my $b = _BSON( invalid_chars => '.' );
    eval { $b->encode_one( { "example.com" => 1 } ) };
    like( $@, qr/key 'example\.com' has invalid character\(s\) '\.'/, "invalid char throws exception");

    $b = _BSON( invalid_chars => '.$' );
    eval { $b->encode_one( { "example.c\$om" => 1 } ) };
    like( $@, qr/key 'example\.c\$om' has invalid character\(s\) '\.\$'/, "multi-invalid chars throws exception");
};

subtest "max_length" => sub {
    my $b = _BSON( max_length => 20 );

    my $hash = { "example.com" => "a" x 100 };
    my $encoded = _BSON->encode_one($hash);

    eval { $b->encode_one( $hash ) };
    like( $@, qr/encode_one.*Document exceeds maximum size 20/, "max_length exceeded during encode_one" );

    eval { $b->decode_one( $encoded ) };
    like( $@, qr/decode_one.*Document exceeds maximum size 20/, "max_length exceeded during decode_one" );
};

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

