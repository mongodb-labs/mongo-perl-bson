use 5.008001;
use strict;
use warnings;
use utf8;

use Test::More 0.96;
BEGIN { $ENV{PERL_BSON_BACKEND} = undef }
BEGIN { $INC{"BSON/XS.pm"} = undef }

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
    no warnings 'once';
    my $glob = *foo;
    eval { encode( { a => $glob } ) };
    like( $@, qr/For key 'a', can't encode value '\*main::foo'/, "encoding glob is fatal" );
}

{
    my $with_null= "Hello\0World";
    eval { encode( { $with_null => 123 } ) };
    like( $@, qr/Key 'Hello\\x00World' contains null character/, "encoding embedded null is fatal" );
}


done_testing;

# COPYRIGHT
#
# vim: set ts=4 sts=4 sw=4 et tw=75:

