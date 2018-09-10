use 5.010001;
use strict;
use warnings;
use Test::More 0.96;

use B;
use Carp qw/croak/;
use Config;
use JSON::MaybeXS;
use JSON::PP ();
use Cpanel::JSON::XS ();

use base 'Exporter';
our @EXPORT = qw/
    sv_type packed_is bytes_are to_extjson to_myjson try_or_fail
    normalize_json
    INT64 INT32 FLOAT
/;

use constant {
    INT64 => 'q<',
    INT32 => 'l<',
    FLOAT => 'd<',
};

my $json_codec_pp = JSON::PP
    ->new
    ->ascii
    ->allow_blessed
    ->convert_blessed;

my $json_codec_xs = Cpanel::JSON::XS
    ->new
    ->ascii
    ->allow_blessed
    ->convert_blessed;

sub normalize_json {
    my $decoded = $json_codec_pp->decode(shift);
    return $json_codec_xs->encode($decoded);
}

sub to_extjson {
    local $ENV{BSON_EXTJSON} = 1;
    my $data = BSON->perl_to_extjson($_[0], { relaxed => $_[1] });
    return $json_codec_xs->encode($data);
}

sub to_myjson {
    local $ENV{BSON_EXTJSON} = 0;
    return $json_codec_xs->encode( shift );
}

sub sv_type {
    my $v     = shift;
    my $b_obj = B::svref_2object( \$v );
    my $type  = ref($b_obj);
    $type =~ s/^B:://;
    return $type;
}

sub packed_is {
    croak("Not enough args for packed_is()") unless @_ >= 3;
    my ( $template, $got, $exp, $label ) = @_;
    $label = '' unless defined $label;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ok;
    if ( $template eq INT64 && ! $Config{use64bitint} ) {
        if ( !ref($got) && !ref($exp) ) {
            # regular scalar will fit in 32 bits, so downgrade the template
            $template = INT32;
        }
        else {
            # something is a reference, so must be BigInt or equivalent
            $ok = ok( $got eq $exp, $label );
            diag "Got: $got, Expected: $exp" unless $ok;
            return $ok;
        }
    }

    $ok = ok( pack( $template, $got ) eq pack( $template, $exp ), $label );
    diag "Got: $got, Expected: $exp" unless $ok;

    return $ok;
}

sub bytes_are {
    croak("Not enough args for bytes_are()") unless @_ >= 2;
    my ( $got, $exp, $label ) = @_;
    $label = '' unless defined $label;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ok = ok( $got eq $exp, $label );
    diag "Got:\n", unpack( "H*", $got ), "\nExpected:\n", unpack( "H*", $exp )
      unless $ok;

    return $ok;
}

sub try_or_fail {
    my ($code, $label) = @_;
    eval { $code->() };
    if ( my $err = $@ ) {
        fail($label);
        diag "Error:\n$err";
        return;
    }
    return 1;
}


1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
