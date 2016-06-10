#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;
BEGIN { $ENV{PERL_BSON_BACKEND} = "" }
BEGIN { $INC{"BSON/XS.pm"} = undef }
use BSON;

my $ts = BSON::Timestamp->new(0x1234, 0x5678);
isa_ok( $ts, 'BSON::Timestamp' );
is( $ts->seconds, 0x1234 );
is( $ts->increment, 0x5678 );
