use 5.008001;
use strict;
use warnings;

package BSON::Decimal128;
# ABSTRACT: BSON type wrapper for Decimal128

our $VERSION = '0.17';

use Carp;
use Math::BigInt;

use Class::Tiny qw/value/;

use constant {
    PLIM  => 34,    # precision limit, i.e. max coefficient chars
    EMAX  => 6144,  # for 9.999999999999999999999999999999999E+6144
    EMIN  => -6143, # for 1.000000000000000000000000000000000E-6143
    AEMAX => 6111,  # EMAX - (PLIM - 1); largest encodable exponent
    AEMIN => -6176, # EMIN - (PLIM - 1); smallest encodable exponent
    BIAS  => 6176,  # offset for encoding exponents
};

sub new_from_bytes {
    my ( $class, $bid ) = @_;
    return $class->new( defined($bid) ? ( value => _bid_to_string($bid) ) : () );
}

my $digits     = qr/[0-9]+/;
my $decimal_re = qr{
    ( [-+]? )                                        # maybe a sign
    ( (?:$digits \. $digits? ) | (?: \.? $digits ) ) # decimal-part
    ( (?:e [-+]? $digits)? )                         # maybe exponent
}ix;
my $strict_re = qr{
     (?: NaN )
  |  (?: -? Inf )                                  # infinities
  |  (?: -? [0-9]{1,34} )                          # integer form
  |  (?: -? 0\.[0-9]{1,6} )                        # short decimal form
  |  (?: -? [0-9]\.[0-9]{1,33} E ([+-] $digits) )  # exponential form
}x;

sub BUILD {
    my $self = shift;
    $self->{value} = "" unless defined $self->{value};

    # skip normalization if already in standar form
    if ( $self->{value} =~ /\A $strict_re \z/x ) {
        # but if $1 has a value, check that it's in range
        return if !$1 || ( $1 >= EMIN && $1 <= EMAX );
    }
    $self->{value} = _bid_to_string( _string_to_bid( $self->{value} ) );
}

sub bytes {
    my $self = shift;
    no warnings 'once';
    return _string_to_bid( $self->{value} ) if $BSON::Types::NoCache;
    return $self->{_bytes} if defined $self->{_bytes};
    return $self->{_bytes} = _string_to_bid( $self->{value} );
}

sub _bid_to_string {
    my $bid = shift;
    my $binary = unpack( "B*", scalar reverse($bid) );
    my ( $coef, $e );

    # sign bit
    my $pos = !substr( $binary, 0, 1 );

    # detect special values from first 5 bits after sign bit
    my $special = substr( $binary, 1, 5 );
    if ( $special eq "11111" ) {
        return "NaN";
    }
    if ( $special eq "11110" ) {
        return $pos ? "Inf" : "-Inf";
    }

    if ( substr( $binary, 1, 2 ) eq '11' ) {
        # Bits: 1*sign 2*ignored 14*exponent 111*significand.
        # Implicit 0b100 prefix in significand.
        $coef = "" . Math::BigInt->new( "0b100" . substr( $binary, 17 ) );
        $e = unpack( "n", pack( "B*", "00" . substr( $binary, 3, 14 ) ) ) - BIAS;
    }
    else {
        # Bits: 1*sign 14*exponent 113*significand
        $coef = "" . Math::BigInt->new( "0b" . substr( $binary, 15 ) );
        $e = unpack( "n", pack( "B*", "00" . substr( $binary, 1, 14 ) ) ) - BIAS;
    }

    # Out of range is treated as zero
    if ( length($coef) > PLIM ) {
        $coef = "0";
    }

    # Shortcut on zero
    if ( $coef == 0 && $e == 0 ) {
        return $pos ? "0" : "-0";
    }

    # convert to scientific form ( e.g. 123E+4 -> 1.23E6 )
    my $adj_exp = $e + length($coef) - 1;

    # exponential notation
    if ( $e > 0 || $adj_exp < -6 ) {
        # insert decimal if more than one digit
        if ( length($coef) > 1 ) {
            substr( $coef, 1, 0, "." );
        }

        return (
            ( $pos ? "" : "-" ) . $coef . "E" . ( $adj_exp >= 0 ? "+" : "" ) . $adj_exp );
    }

    # not exponential notation (integers or small negative exponents)
    else {
        # e == 0 means integer
        return $pos ? $coef : "-$coef"
          if $e == 0;

        # pad with leading zeroes if coefficient is too short
        if ( length($coef) < abs($e) ) {
            substr( $coef, 0, 0, "0" x ( abs($e) - length($coef) ) );
        }

        # maybe coefficient is exact length?
        return $pos ? "0.$coef" : "-0.$coef"
          if length($coef) == abs($e);

        # otherwise length(coef) > abs($e), so insert dot after first digit
        substr( $coef, 1, 0, "." );
        return $pos ? $coef : "-$coef";
    }
}

my ( $bidNaN, $bidPosInf, $bidNegInf ) =
  map { scalar reverse pack( "B*", $_ . ( "0" x 118 ) ) } qw/ 011111 011110 111110 /;

sub _croak { croak("Couldn't parse '$_[0]' as valid Decimal128") }

sub _erange { croak("Value '$_[0]' is out of range for Decimal128") }

sub _string_to_bid {
    my $s = shift;
    # $s = "0" if $s eq "";

    # maybe special
    return $bidNaN    if $s =~ /\A NaN \z/ix;
    return $bidPosInf if $s =~ /\A \+?Inf(?:inity)? \z/ix;
    return $bidNegInf if $s =~ /\A -Inf(?:inity)? \z/ix;

    # parse string
    my ( $sign, $mant, $exp ) = $s =~ /\A $decimal_re \z/x;
    $sign = "" unless defined $sign;
    $exp = 0 unless defined $exp && length($exp);
    $exp =~ s{^e}{}i;

    _croak($s) unless defined $mant;

    # sign bit
    my $neg = defined($sign) && $sign eq '-' ? "1" : "0";

    # locate decimal, remove it and adjust the exponent
    my $dot = index( $mant, "." );
    $mant =~ s/\.//;
    $exp += $dot - length($mant) if $dot >= 0;

    # clamping
    if ( $exp > AEMAX && $exp - AEMAX <= PLIM - length($mant) ) {
        $mant .= "0" x ( $exp - AEMAX );
        $exp = AEMAX;
    }

    _erange($s) if $exp > AEMAX || $exp < AEMIN;

    # Get binary representation of coefficient
    my $coef = Math::BigInt->new($mant)->as_bin;
    $coef =~ s/^0b//;

    # Get 14-bit binary representation of biased exponent
    my $biased_exp = unpack( "B*", pack( "n", $exp + BIAS ) );
    substr( $biased_exp, 0, 2, "" );

    # Choose representation based on coefficient length
    my $coef_len = length($coef);
    if ( $coef_len <= 113 ) {
        substr( $coef, 0, 0, "0" x ( 113 - $coef_len ) );
        return scalar reverse pack( "B*", $neg . $biased_exp . $coef );
    }
    elsif ( $coef_len <= 114 ) {
        substr( $coef, 0, 3, "" );
        return scalar reverse pack( "B*", $neg . "11" . $biased_exp . $coef );
    }
    else {
        _croak($s);
    }
}

=method TO_JSON

Returns the value as a string.

If the C<BSON_EXTJSON> option is true, it will instead
be compatible with MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$numberDecimal" : "2.23372036854775807E+57"}

=cut

sub TO_JSON {
    return "$_[0]->{value}" unless $ENV{BSON_EXTJSON};
    return { '$numberDecimal' => "$_[0]->{value}" };
}

use overload (
    q{""}    => sub { "$_[0]->{value}" },
    fallback => 1,
);

1;
