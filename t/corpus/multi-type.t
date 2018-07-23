use 5.008001;
use strict;
use warnings;

use Test::More 0.96;
use Path::Tiny;

use lib 't/lib';
use lib 't/pvtlib';
use CleanEnv;
use CorpusTest;

test_corpus_file( path($0)->basename(".t") . ".json" );

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

