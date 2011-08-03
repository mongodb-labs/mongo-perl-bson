#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use Config;
    use if $Config{useithreads}, 'threads';
    use if $Config{useithreads}, 'threads::shared';
}

use Config;
use Test::More tests => 44;

use BSON;

my $o1 = BSON::ObjectId->new();
ok( $o1->is_legal($o1), 'oid generate' );

my $o2 = BSON::ObjectId->new( "$o1" );
is( $o1, $o2, 'oid from string' );

my $o3 = BSON::ObjectId->new('4e2766e6e1b8325d02000028');
is_deeply(
    [ unpack( 'C*', $o3->value ) ],
    [ 0x4e, 0x27, 0x66, 0xe6, 0xe1, 0xb8, 0x32, 0x5d, 0x02, 0x00, 0x00, 0x28 ],
    'oid value'
);

my $o4 = BSON::ObjectId->new( $o3->value );
is( "$o4", "$o3", 'value' );

SKIP: {
    skip "No threads", 40 unless $Config{useithreads};
    my @threads = map {
        threads->create(
            sub {
                [ map { BSON::ObjectId->new } 0 .. 3 ];
            }
        );
    } 0 .. 9;

    my @oids = map { @{ $_->join } } @threads;

    my @inc =
      sort { $a <=> $b }
      map { unpack 'v', ( pack( 'H*', $_ ) . '\0' ) }
      map { substr $_, 20 } @oids;

    my $prev = -1;
    for (@inc) {
        ok( $prev < $_ );
        $prev = $_;
    }
};

