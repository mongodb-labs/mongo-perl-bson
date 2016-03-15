use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep qw/!blessed/;

use BSON;
use Path::Tiny;
use JSON::MaybeXS;
use Data::Dumper;

use base 'Exporter';
our @EXPORT = qw/test_corpus_file/;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

sub test_corpus_file {
    my ($file) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $f = path( "corpus", $file );
    my $base = $f->basename;

    my $json = eval { decode_json( $f->slurp ) };
    if ( my $err = $@ ) {
        fail("$base failed to load");
        diag($err);
        return;
    }

    _validity_tests($json);
    _decode_error_tests($json);
    _parse_error_tests($json);
}

sub _validity_tests {
    my ($json) = @_;
    return unless $json->{valid};
    for my $case ( @{ $json->{valid} } ) {
        my $desc = $case->{description};
        my $bson = pack( "H*", $case->{subject} );
        my $wrap = $json->{bson_type} =~ /\A(?:0x01|0x10|0x12)\z/;

        my $decoded = eval { BSON::decode( $bson, wrap_numbers => $wrap ) };
        if ( my $err = $@ ) {
            fail("$desc: Couldn't decode");
            diag "Error:\n$err";
            next;
        }

        # decoding test
        {
            my $expect = BSON->inflate_extjson( decode_json( $case->{extjson} ) );
            local $Data::Dumper::Useqq = 1;
            cmp_deeply( $decoded, $expect, "$desc: Decode to inflated extjson" )
              or diag "Got:\n", Dumper($decoded), "Wanted:\n", Dumper($expect);
        }

        # roundtrip test
        if ( !$case->{decodeOnly} ) {
            my $got = eval {
                unpack( "H*",
                    BSON::encode( BSON::decode( $bson, wrap_numbers => $wrap, ixhash => 1 ) ) );
            };
            if ( my $err = $@ ) {
                fail("$desc: Couldn't roundtrip");
                diag "Error:\n$err";
            }
            else {
                is( lc($got), lc( $case->{subject} ), "$desc: Roundtrip" )
                    or diag "ExtJSON: $case->{extjson}";
            }
        }
    }
}

sub _decode_error_tests {
    my ($json) = @_;
    return unless $json->{decodeErrors};
    for my $case ( @{ $json->{decodeErrors} } ) {
        my $desc = $case->{description};
        my $bson = pack( "H*", $case->{subject} );

        eval { BSON::decode($bson) };
        ok( length($@), "Decode error: $desc:" );
    }
}

sub _parse_error_tests {
    my ($json) = @_;
    return unless $json->{parseErrors};
    for my $case ( @{ $json->{parseErrors} } ) {
    }
}

1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
