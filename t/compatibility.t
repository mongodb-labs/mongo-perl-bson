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

# Undeprecated BSON type wrappers need to be API compatible with previous
# versions and with MongoDB::* equivalents

my %apis = (
    "BSON::Bool" => {
        "BSON::Bool" => [ qw/true false value op_eq/ ],
    },
    "BSON::Bytes" => {
        "MongoDB::BSON::Binary" => [ qw/data subtype/ ],
    },
    "BSON::OID" => {
        "MongoDB::OID" => [ qw/value to_string get_time TO_JSON _get_pid/ ],
    },
    "BSON::Regex" => {
        "MongoDB::BSON::Regexp" => [ qw/pattern flags try_compile/ ],
    },
    "BSON::String" => {
        "BSON::String" => [ qw/value/ ],
    },
    "BSON::Time" => {
        "BSON::Time" => [ qw/value epoch op_eq/ ],
    },
    "BSON::Code" => {
        "BSON::Code" => [ qw/code scope length/ ],
        "MongoDB::Code" => [ qw/code scope/ ],
    },
    "BSON::Timestamp" => {
        "BSON::Timestamp" => [ qw/seconds increment/ ],
        "MongoDB::Timestamp" => [ qw/sec inc/ ],
    },
);

for my $k ( sort keys %apis ) {
    for my $t ( sort keys %{$apis{$k}} ) {
        can_ok( $k, @{$apis{$k}{$t}} );
    }
}

done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

