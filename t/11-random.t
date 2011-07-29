#!/usr/bin/perl

use strict;
use warnings;

my $RUNS = 500;    # Number of random documents to create
my $DEEP = 2;      # Max depth level of embedded hashes
my $KEYS = 20;     # Number of keys per hash

use Test::More;

plan tests => $RUNS;

use BSON qw/encode decode/;

srand;

my $level = 0;
my @codex = (
    \&int32, \&int64, \&doub, \&str, \&hash, \&arr,  \&dt,   \&bin,
    \&re,    \&oid,   \&min,  \&max, \&ts,   \&null, \&bool, \&code
);

for my $count ( 1 .. $RUNS ) {
    my $ar   = hash($KEYS);
    my $bson = encode($ar);
    my $ar1  = decode($bson);
    is_deeply( $ar, $ar1 );
}

sub int32 {
    return int( rand( 2**32 / 2 ) ) * ( int( rand(2) ) ? -1 : 1 );
}

sub int64 {
    return int( rand( 2**32 / 2 ) + 2**32 ) * ( int( rand(2) ) ? -1 : 1 );
}

sub doub {
    return rand( 2**64 ) * ( int( rand(2) ) ? -1 : 1 );
}

sub str {
    my $len = int( rand(255) ) + 1;
    my @a   = map {
        ( 'A' .. 'Z', 'a' .. 'z', ' ' )[ rand( 26 + 26 + 1 ) ]
    } 1 .. $len;
    return join '', @a;
}

sub dt  { BSON::Time->new( abs( int32() ) ) }
sub bin { BSON::Binary->new( str(), int( rand(5) ) ) }
sub re  { qr/\w\a+\s$/i }

sub oid { BSON::ObjectId->new }
sub min { BSON::MinKey->new }
sub max { BSON::MaxKey->new }

sub ts { BSON::Timestamp->new( abs( int32() ), abs( int32() ) ) }

sub null { undef }
sub bool { BSON::Bool->new( int( rand(2) ) ) }
sub code { BSON::Code->new( str(), hash() ) }

sub rnd {
    my $sub = $codex[ int( rand(@codex) ) ];
    return $sub->($level);
}

sub arr {
    return [] if $level > $DEEP;
    $level++;
    my $len = int( rand(20) ) + 1;
    my @a   = ();
    for ( 1 .. $len ) {
        push @a, rnd( $level + 1 );
    }
    $level--;
    return \@a;
}

sub hash {
    return {} if $level > $DEEP;
    $level++;
    my $hash = {};
    for my $idx ( 1 .. $KEYS ) {
        $hash->{"key_$idx"} = rnd( $level + 1 );
    }
    $level--;
    return $hash;
}

