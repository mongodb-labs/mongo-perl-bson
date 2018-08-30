use 5.010001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep qw/!blessed/;

use JSON::PP ();
use JSON::XS ();
#BEGIN { $ENV{PERL_JSON_BACKEND} = 'JSON::PP' };

use BSON;
use BSON::Types ':all';
use Config;
use Path::Tiny 0.054; # better basename
use Data::Dumper;

# from t/lib
use TestUtils;

use constant {
    IS_JSON_PP => ref( JSON::PP->new ) eq 'JSON::PP'
};

use base 'Exporter';
our @EXPORT = qw/test_corpus_file/;

binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

my $orig = JSON::PP->can("object")
    or die "Unable to find JSON::PP::object to override";
do {
    no warnings 'redefine';
    *JSON::PP::object = sub {
        tie my %hash, 'Tie::IxHash';
        my $value = $orig->(\%hash);
        return $value;
    };
};

my $JSON_PP = JSON::PP->new(
    ascii => 1,
    allow_blessed => 1,
    convert_blessed => 1,
);

my $JSON_XS = JSON::MaybeXS->new(
    ascii => 1,
    allow_blessed => 1,
    convert_blessed => 1,
);

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

    subtest 'JSON::PP Tie::IxHash injection' => sub {
        my $data = $JSON_PP->decode('{"x":23}');
        ok defined(tied %$data), 'JSON::PP returns tied objects';
    };

    _validity_tests($json);
    _decode_error_tests($json);
    _parse_error_tests($json);

    if ( $json->{deprecated} ) {
        subtest 'deprecated' => sub {
            $f = path( "corpus", "deprecated", $file );
            $json = eval { decode_json( $f->slurp ) };
            if ( my $err = $@ ) {
                fail("deprecaed/$base failed to load");
                diag($err);
                return;
            }

            _validity_tests($json);
            _decode_error_tests($json);
            _parse_error_tests($json);
        };
    }
    else {
        return;
    }
}

sub _validity_tests {
    my ($json) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # suppress caching that throws off Test::Deep
    local $BSON::Types::NoCache = 1;

    # aggressively force ext-json representation, even for int32 and double
    local $ENV{BSON_EXTJSON_FORCE} = 1;

    my $bson_type = $json->{bson_type};
    my $deprecated = $json->{deprecated};

    for my $case ( @{ $json->{valid} } ) {
#        next unless $case->{description}
#            eq 'Regular expression as value of $regex query operator with $options';
        subtest 'case: '.$case->{description} => sub {
            local $Data::Dumper::Useqq = 1;

            my $desc = $case->{description};
            ok 1, 'noop';
            my $wrap = $bson_type =~ /\A(?:0x00|0x01|0x10|0x12)\z/;
            my $codec = BSON->new( prefer_numeric => 1, wrap_numbers => $wrap, ordered => 1 );
            my $lossy = $case->{lossy};

            my $canonical_bson = $case->{canonical_bson} || $case->{bson};
            my $converted_bson = $case->{converted_bson};
            my $degenerate_bson = $case->{degenerate_bson};

            $canonical_bson = pack('H*', $canonical_bson);
            $converted_bson = pack('H*', $converted_bson)
                if defined $converted_bson;
            $degenerate_bson = pack('H*', $degenerate_bson)
                if defined $degenerate_bson;

            my $canonical_json = $case->{canonical_extjson};
            my $converted_json = $case->{converted_extjson};
            my $degenerate_json = $case->{degenerate_extjson};
            my $relaxed_json = $case->{relaxed_extjson};

            $canonical_json = _normalize(
                $canonical_json,
                '$desc: normalizing canonical extjson',
            );
            $converted_json = _normalize(
                $converted_json,
                '$desc: normalizing converted extjson',
            );
            $degenerate_json = _normalize(
                $degenerate_json,
                '$desc: normalizing degenerate extjson',
            );
            $relaxed_json = _normalize(
                $relaxed_json,
                '$desc: normalizing relaxed extjson',
            );

            my $has_canonical_bson = defined $canonical_bson;
            my $has_converted_bson = defined $converted_bson;
            my $has_degenerate_bson = defined $degenerate_bson;

            my $has_canonical_json = defined $canonical_json;
            my $has_converted_json = defined $converted_json;
            my $has_relaxed_json = defined $relaxed_json;
            my $has_degenerate_json = defined $degenerate_json;

            if (!$deprecated and $has_canonical_bson and $has_canonical_json) {
                local $ENV{BSON_EXTJSON} = 1;

                # localized variable
                my $canonical_json = $canonical_json;

                # fixes for digit tests
                $canonical_json =~ s{("\$numberDouble"):"-1.0"}{$1:"-1"}g;
                $canonical_json =~ s{("\$numberDouble"):"1.0"}{$1:"1"}g;
                $canonical_json =~ s{("\$numberDouble"):"-0.0"}{$1:"0"}g;
                $canonical_json =~ s{("\$numberDouble"):"0.0"}{$1:"0"}g;
                $canonical_json =~ s{-1\.23456789012345677E\+18}{-1.23456789012346e+18}g;
                $canonical_json =~ s{1\.23456789012345677E\+18}{1.23456789012346e+18}g;

                _bson_to_extjson(
                    $codec,
                    $canonical_bson,
                    $canonical_json,
                    'cB -> cEJ',
                    0,
                );
            }

            if (!$deprecated and $has_canonical_bson and $has_relaxed_json) {
                my $relaxed_json = $relaxed_json;
                $relaxed_json =~ s{:-1234567890123456768\}}{:-1.23456789012346e+18\}}g;
                $relaxed_json =~ s{:1234567890123456768\}}{:1.23456789012346e+18\}}g;
                _bson_to_extjson(
                    $codec,
                    $canonical_bson,
                    $relaxed_json,
                    'cB -> rEJ',
                    1,
                );
            }

            if ($has_canonical_json and $has_canonical_bson) {
                if (!$lossy) {
                    _extjson_to_bson(
                        $codec,
                        $canonical_json,
                        ($deprecated && $has_converted_bson)
                            ? $converted_bson
                            : $canonical_bson,
                        'cEJ -> cB',
                    );
                }
            }

            if (!$deprecated and $has_degenerate_bson and $has_canonical_json) {
                _bson_to_extjson(
                    $codec,
                    $degenerate_bson,
                    $canonical_json,
                    'dB -> cEJ',
                );
            }

            if (!$deprecated and $has_degenerate_bson and $has_relaxed_json) {
                _bson_to_extjson(
                    $codec,
                    $degenerate_bson,
                    $relaxed_json,
                    'dB -> rEJ',
                    1,
                );
            }

            if ($has_degenerate_json and $has_canonical_bson) {
                if (!$lossy) {
                    _extjson_to_bson(
                        $codec,
                        $degenerate_json,
                        ($deprecated && $has_converted_bson)
                            ? $converted_bson
                            : $canonical_bson,
                        'dEJ -> cB',
                    );
                }
            }

            if (!$deprecated and $has_relaxed_json) {
                $relaxed_json =~ s{\{"d":-0\}}{\{"d":0\}}g;
                _relaxed_extjson_bson_roundtrip(
                    $codec,
                    $relaxed_json,
                    'roundtrip',
                );
            }

        };
    }

    return;
}

# this handle special cases that just don't work will in perl
sub _extjson_ok {
    my ($type, $E) = @_;

    if ( $type eq "0x01" ) {
        return if $E =~ /\d\.0\D/; # trailing zeros wind up as integers
        return if $E =~ '-0(\.0)?'; # negative zero not preserved in Perl
    }

    # JSON::PP has trouble when TO_JSON returns a false value; in our case
    # it could stringify 0 as "0" rather than treat it as a number; see
    # https://github.com/makamaka/JSON-PP/pull/23
    if ( ( $type eq "0x10" || $type eq "0x12" ) && IS_JSON_PP ) {
        return if $E =~ /:\s*0/;
    }

    return 1;
}

sub _normalize {
    my ($json, $desc) = @_;
    return unless defined $json;

    try_or_fail(
        sub {
            $json = to_myjson( $JSON_PP->decode( $json ) );
        },
        $desc
    ) or next;

    return $json;
}

sub _relaxed_extjson_bson_roundtrip {
    my ($codec, $input, $label) = @_;

    my ($decoded,$bson);

    try_or_fail(
        sub { $decoded = $codec->extjson_to_perl( $JSON_PP->decode( $input ) ) },
        "$label: Couldn't decode ExtJSON"
    ) or return;

    try_or_fail(
        sub { $bson = $codec->encode_one( $decoded ) },
        "$label: Couldn't encode BSON from BSON"
    ) or return;

    my ($got);

    try_or_fail(
        sub { $decoded = $codec->decode_one( $bson ) },
        "$label: Couldn't decode BSON"
    ) or return;

    try_or_fail(
        sub { $got = to_extjson( $decoded, 1 ) },
        "$label: Couldn't encode ExtJSON from BSON"
    ) or return;

    is($got, $input, $label.': rEJ -> cB -> rEJ');
}

sub _bson_to_bson {
    my ($codec, $input, $expected, $label) = @_;

    my ($decoded,$got);

    try_or_fail(
        sub { $decoded = $codec->decode_one( $input ) },
        "$label: Couldn't decode BSON"
    ) or return;

    try_or_fail(
        sub { $got = $codec->encode_one( $decoded ) },
        "$label: Couldn't encode BSON from BSON"
    ) or return;

    return bytes_are( $got, $expected, $label );
}

sub _bson_to_extjson {
    my ($codec, $input, $expected, $label, $relaxed) = @_;

    my ($decoded,$got);

    try_or_fail(
        sub { $decoded = $codec->decode_one( $input ) },
        "$label: Couldn't decode BSON"
    ) or return;

    try_or_fail(
        sub { $got = to_extjson( $decoded, $relaxed ) },
        "$label: Couldn't encode ExtJSON from BSON"
    ) or return;

    return is($got, $expected, $label);
}

sub _extjson_to_bson {
    my ($codec, $input, $expected, $label) = @_;

    $input = normalize_json($input);
    my $edata = $codec->decode_one($expected);

    my ($decoded,$got);

    local $ENV{BSON_EXTJSON} = 1;
    try_or_fail(
        sub {
#            my $json = decode_json($input);
            my $json = $JSON_PP->decode($input);
#            my $json = JSON::PP::decode_json($input);
            $json = $codec->extjson_to_perl($json);
            $decoded = $json;
        },
        "$label: Couldn't decode ExtJSON"
    ) or return;

    try_or_fail(
        sub { $got = $codec->encode_one( $decoded ) },
        "$label: Couldn't encode BSON from BSON"
    ) or return;

    my $data = $codec->decode_one($got);

    #my $unordered_codec = BSON->new( prefer_numeric => 1, wrap_numbers => 1);
    #$expected = $codec->encode_one($unordered_codec->decode_one($expected));
    #$got = $codec->encode_one($unordered_codec->decode_one($got));

    return bytes_are( $got, $expected, $label );
}

sub _extjson_to_extjson {
    my ($codec, $input, $expected, $label, $relaxed) = @_;

    my ($decoded,$got);

    try_or_fail(
        sub { $decoded = $codec->extjson_to_perl( $JSON_PP->decode( $input ) ) },
        "$label: Couldn't decode ExtJSON"
    ) or return;

    try_or_fail(
        sub { $got = to_extjson( $decoded, $relaxed ) },
        "$label: Couldn't encode ExtJSON from BSON"
    ) or return;

    return is($got, $expected, $label);
}

sub _decode_error_tests {
    my ($json) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    return unless $json->{decodeErrors};
    for my $case ( @{ $json->{decodeErrors} } ) {
        my $desc = $case->{description};
        my $bson = pack( "H*", $case->{bson} );

        eval { BSON::decode($bson) };
        ok( length($@), "Decode error: $desc:" );
    }
}

my %PARSER = (
    '0x00' => sub { bson_doc(shift) },
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
        eval { $parser->($case->{string}) };
        ok( $@, "$case->{description}: parse should throw an error " )
            or diag "Input was: $case->{string}";
    }
}

1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
