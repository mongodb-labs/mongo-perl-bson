use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use lib 't/lib';
use CleanEnv;

use BSON;

isa_ok(BSON->create_oid, 'BSON::OID');

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:


