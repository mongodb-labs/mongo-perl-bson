use 5.0001;
use strict;
use warnings;

use Test::More 0.96;
use Math::BigInt;

use lib 't/lib';
use lib 't/pvtlib';
use CleanEnv;
use TestUtils;
use Tie::IxHash;
use JSON::MaybeXS;

use BSON qw/encode decode/;
use BSON::Raw;

my ($bson, $expect, $hash);

# encode then get first key with unpack
$bson = $expect = encode( Tie::IxHash->new( 1234 => 314159, 1235 => 300 ) );
my $object = BSON::Raw->new(bson=>$bson);
my $return_key = $object->_get_first_key;
is($return_key, "1234");

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:
