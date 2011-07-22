#!perl

use Test::More tests => 1;

use lib '../lib'; #TODO

BEGIN {
    use_ok( 'BSON' ) || print "Bail out!
";
}

diag( "Testing BSON $BSON::VERSION, Perl $], $^X" );
