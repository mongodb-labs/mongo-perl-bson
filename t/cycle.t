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

use BSON;
use BSON::Types ':all';

my $c = BSON->new;

my $q = {};
$q->{'q'} = $q;

eval {
    $c->encode_one($q);
};

like($@, qr/circular ref/, "circular hashref");

my %test;
tie %test, 'Tie::IxHash';
$test{t} = \%test;

eval {
    $c->encode_one(\%test);
};

like($@, qr/circular ref/, "circular tied hashref");

my $tie = Tie::IxHash->new;
$tie->Push("t" => $tie);

eval {
    $c->encode_one($tie);
};

like($@, qr/circular ref/, "circular Tie::IxHash object");

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

