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

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

