use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep qw/!blessed/;

use BSON;
use BSON::Types ':all';
use Path::Tiny;
use JSON::MaybeXS;
use Data::Dumper;

# from t/lib
use TestUtils;

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
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # suppress caching that throws off Test::Deep
    local $BSON::Types::NoCache = 1;

    # aggressively force ext-json representation, even for int32 and double
    local $ENV{BSON_EXTJSON_FORCE} = 1;

    return unless $json->{valid};

    for my $case ( @{ $json->{valid} } ) {
        local $Data::Dumper::Useqq = 1;

        my $desc = $case->{description};
        my $bson = pack( "H*", $case->{subject} );
        my $wrap = $json->{bson_type} =~ /\A(?:0x01|0x10|0x12)\z/;

        my $codec = BSON->new( wrap_numbers => $wrap, ordered => 1 );

        my $from_bson = eval { $codec->decode_one( $bson ) };
        if ( my $err = $@ ) {
            fail("$desc: Couldn't decode BSON");
            diag "Error:\n$err";
            next;
        }

        my $from_extjson = eval { $codec->inflate_extjson( decode_json( $case->{extjson} ) ) };
        if ( my $err = $@ ) {
            fail("$desc: Couldn't decode ExtJSON");
            diag "Error:\n$err";
            next;
        }

        # decoding test: E->N == B->N'   (N == N')
        {
            cmp_deeply( $from_extjson, $from_bson, "$desc: [E -> N == B -> N']" )
              or diag "Got:\n", Dumper($from_extjson), Dumper($from_bson), "Wanted:\n", ;
        }

        # BSON encoding tests:
        # a) N -> B' == B
        # b) N -> B' -> N'' == N (only if (a) fails)
        {
            my $bson_2 = $codec->encode_one( $from_bson );
            if ( $bson_2 eq $bson ) {
                pass("$desc: [N -> B' == B]");
            }
            else {
                my $from_bson_2 = $codec->decode_one( $bson_2 );
                cmp_deeply( $from_bson_2, $from_bson, "$desc: [N -> B' -> N'' == N]" )
                  or diag "Got:\n", Dumper($from_bson_2), "Wanted:\n", Dumper($from_bson);
            }
        }

        # ExtJSON encoding tests:
        # a) N -> E' == E
        # b) N -> E' -> N''' == N (only if (a) fails)
        {
            # eliminate white space
            (my $extjson = $case->{extjson}) =~ s{\s+}{}g;
            (my $extjson_2 = to_extjson( $from_bson )) =~ s{\s+}{}g;
            if ( $extjson_2 eq $extjson ) {
                pass("$desc: [N -> E' == E]");
            }
            else {
                my $from_extjson_2 = $codec->inflate_extjson( decode_json( $extjson_2 ) );
                cmp_deeply( $from_extjson_2, $from_extjson, "$desc: [N -> E' -> N''' == N]" )
                  or diag "Got:\n", Dumper($from_extjson_2), "Wanted:\n", Dumper($from_extjson);
            }
        }
    }
}

sub _decode_error_tests {
    my ($json) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    return unless $json->{decodeErrors};
    for my $case ( @{ $json->{decodeErrors} } ) {
        my $desc = $case->{description};
        my $bson = pack( "H*", $case->{subject} );

        eval { BSON::decode($bson) };
        ok( length($@), "Decode error: $desc:" );
    }
}

my %PARSER = (
    '0x13' => sub { bson_decimal128(shift) },
);

sub _parse_error_tests {
    my ($json) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $parser = $PARSER{$json->{bson_type}};
    if ( $json->{parseErrors} && !$parser  ) {
        BAIL_OUT("No parseError parser available for $json->{bson_type}");
    }

    for my $case ( @{ $json->{parseErrors} } ) {
        eval { $parser->($case->{subject}) };
        ok( $@, "$case->{description}: parse should throw an error " );
    }
}

1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
