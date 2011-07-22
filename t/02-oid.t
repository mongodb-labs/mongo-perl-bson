#!/usr/bin/perl

use strict;
use warnings;
use lib '../lib'; # TODO

use Test::More tests => 4;
use BSON;

my $o1 = BSON::ObjectId->new();
ok( $o1->is_legal($o1), 'oid generate' );

my $o2 = BSON::ObjectId->new( "$o1" );
is( $o1, $o2, 'oid from string' );

my $o3 = BSON::ObjectId->new('4e2766e6e1b8325d02000028');
my $a = [ unpack( 'C*', $o3->value ) ];
is_deeply( $a,
    [ 0x4e, 0x27, 0x66, 0xe6, 0xe1, 0xb8, 0x32, 0x5d, 0x02, 0x00, 0x00, 0x28 ],
    'oid value' );

my $o4 = BSON::ObjectId->new( $o3->value );
is( "$o4", "$o3", 'bin value' );
