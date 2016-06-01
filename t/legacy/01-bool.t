#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
BEGIN { $ENV{PERL_BSON_BACKEND} = undef }
BEGIN { $INC{"BSON/XS.pm"} = undef }
use BSON;

ok(BSON::Bool->new(1));
ok(!BSON::Bool->new(0));
ok(BSON::Bool->true);
ok(!BSON::Bool->false);

my $t = BSON::Bool->true;
my $f = BSON::Bool->false;

ok( $t && !$f );
