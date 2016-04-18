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

{
    my $obj = bless {}, "Some::Random::Class";
    eval { encode( { a => $obj } ) };
    like( $@, qr/For key 'a', can't encode value of type 'Some::Random::Class'/, "encoding unknown type is fatal" );
}

{
    my $glob = *foo;
    eval { encode( { a => $glob } ) };
    like( $@, qr/For key 'a', can't encode value '\*main::foo'/, "encoding glob is fatal" );
}


done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

