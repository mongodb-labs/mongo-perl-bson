use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use lib 't/lib';
use TestUtils;

use BSON qw/encode decode/;
use BSON::Types ':all';

my ( $bson, $expect, $hash );

my $now = time;

# test constructor
ok( bson_time() >= $now, "empty bson_time() is current time (or so)" );
ok( BSON::Time->new >= $now, "empty BSON::Time constructor is curren time (or so)" );

# test overloading
is( bson_time($now),    $now, "BSON::Time string overload" );
is( 0+ bson_time($now), $now, "BSON::Time string overload" );

# BSON::Time -> BSON::Time
$bson = $expect = encode( { A => bson_time($now) } );
$hash = decode($bson);
is( ref( $hash->{A} ), 'BSON::Time', "BSON::Time->BSON::Time" );
is( "$hash->{A}",      $now,         "value correct" );

# DateTime -> BSON::Time
SKIP: {
    eval { require DateTime };
    skip( "DateTime not installed", 2 )
      unless $INC{'DateTime.pm'};
    $bson = encode( { A => DateTime->from_epoch( epoch => $now ) } );
    $hash = decode($bson);
    is( ref( $hash->{A} ), 'BSON::Time', "DateTime->BSON::Time" );
    is( "$hash->{A}",      $now,         "value correct" );
    is( $bson,             $expect,      "BSON correct" );
}

# DateTime::Tiny -> BSON::Time
SKIP: {
    eval { require DateTime::Tiny };
    skip( "DateTime::Tiny not installed", 2 )
      unless $INC{'DateTime/Tiny.pm'};
    my ($s,$m,$h,$D,$M,$Y) = gmtime($now);
    my $dt = DateTime::Tiny->new(
        year => $Y + 1900, month => $M + 1, day => $D,
        hour => $h, minute => $m, second => $s
    );
    $bson = encode( { A => $dt } );
    $hash = decode($bson);
    is( ref( $hash->{A} ), 'BSON::Time', "DateTime::Tiny->BSON::Time" );
    is( "$hash->{A}",      $now,         "value correct" );
    is( $bson,             $expect,      "BSON correct" );
}

# Time::Moment -> BSON::Time
SKIP: {
    eval { require Time::Moment };
    skip( "Time::Moment not installed", 2 )
      unless $INC{'Time/Moment.pm'};
    $bson = encode( { A => Time::Moment->from_epoch( $now ) } );
    $hash = decode($bson);
    is( ref( $hash->{A} ), 'BSON::Time', "Time::Moment->BSON::Time" );
    is( "$hash->{A}",      $now,         "value correct" );
    is( $bson,             $expect,      "BSON correct" );
}

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:
