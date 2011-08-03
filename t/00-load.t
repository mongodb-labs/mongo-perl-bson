#!perl

use Test::More tests => 1;

diag("Using Perl $]");

BEGIN {
    use_ok( 'BSON' ) || print "Bail out!\n";
}

