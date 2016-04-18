use 5.008001;
use strict;
use warnings;

package BSON;
# ABSTRACT: Pure Perl implementation of MongoDB's BSON serialization

use base 'Exporter';
our @EXPORT_OK = qw/encode decode/;

our $VERSION = '0.17';

use Carp;
use Config;
use Scalar::Util 'blessed';
use Tie::IxHash;

use Moo;
use BSON::Types ();
use boolean;

use if $] ge '5.010000', 're', 'regexp_pattern';

use constant {
    HAS_INT64 => $Config{use64bitint},
};

use if !HAS_INT64, "Math::BigInt";

# Maximum size of a BSON record
our $MAX_SIZE = 16 * 1024 * 1024;

# Max integer sizes
my $max_int32 = 2147483647;
my $min_int32 = -2147483648;
my $max_int64 =
  HAS_INT64 ? 9223372036854775807 : Math::BigInt->new("9223372036854775807");
my $min_int64 =
  HAS_INT64 ? -9223372036854775808 : Math::BigInt->new("-9223372036854775808");

#<<<
my $int_re     = qr/^(?:(?:[+-]?)(?:[0123456789]+))$/;
my $doub_re    = qr/^(?:(?i)(?:NaN|-?Inf(?:inity)?)|(?:[+-]?)(?:(?=[0123456789]|[.])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))$/;
#>>>

my $bools_re = qr/::(?:Boolean|_Bool|Bool)\z/;

use constant {

    BSON_TYPE_NAME => "CZ*",
    BSON_DOUBLE => "d",
    BSON_STRING => "V/Z*",
    BSON_BOOLEAN => "C",
    BSON_REGEX => "Z*Z*",
    BSON_JSCODE => "",
    BSON_INT32 => "l",
    BSON_INT64 => "q",
    BSON_8BYTES => "a8",
    BSON_TIMESTAMP => "LL",
    BSON_CODE_W_SCOPE => "l",
    BSON_REMAINING => 'a*',
    BSON_SKIP_4_BYTES => 'x4',
    BSON_OBJECTID => 'a12',
    BSON_BINARY_TYPE => 'C',
    BSON_CSTRING => 'Z*',
};

use namespace::clean -except => 'meta';

#--------------------------------------------------------------------------#
# public attributes
#--------------------------------------------------------------------------#

=attr error_callback

This attribute specifies a function reference that will be called with
three positional arguments:

=for :list
* an error string argument describing the error condition
* a reference to the problematic document or byte-string
* the method in which the error occurred (e.g. C<encode_one> or C<decode_one>)

Note: for decoding errors, the byte-string is passed as a reference to avoid
copying possibly large strings.

If not provided, errors messages will be thrown with C<Carp::croak>.

=cut

has error_callback => (
    is      => 'ro',
    isa     => sub { die "not a code reference" if defined $_[0] && ! ref $_[0] eq 'CODE' },
);

=attr invalid_chars

A string containing ASCII characters that must not appear in keys.  The default
is the empty string, meaning there are no invalid characters.

=cut

has invalid_chars => (
    is      => 'ro',
    isa     => sub { die "not a string" if ! defined $_[0] || ref $_[0] },
    default => '',
);

=attr max_length

This attribute defines the maximum document size. The default is 0, which
disables any maximum.

If set to a positive number, it applies to both encoding B<and> decoding (the
latter is necessary for prevention of resource consumption attacks).

=cut

has max_length => (
    is      => 'ro',
    isa     => sub { die "not a non-negative number" unless defined $_[0] && $_[0] >= 0 },
    default => 0,
);

=attr op_char

This is a single character to use for special operators.  If a key starts
with C<op_char>, the C<op_char> character will be replaced with "$".

The default is "$".

=cut

has op_char => (
    is  => 'ro',
    isa => sub { die "not a single character" if defined $_[0] && length $_[0] > 1 },
);

=attr ordered

If set to a true value decoding will return a tied hash that preserves
key order. Otherwise, a regular unordered hash will be returned.

B<IMPORTANT CAVEATS>:

=for :list
* Users must not rely on the return value being any particular tied hash
  implementation.  It may change in the future for efficiency.
* Turning this option on entails a significant speed penalty as tied hashes
  are slower than regular Perl hashes.

The default is false.

=cut

has ordered => (
    is => 'ro',
    default => "",
);

=attr prefer_numeric

If set to true, scalar values that look like a numeric value will be
encoded as a BSON numeric type.  When false, if the scalar value was ever
used as a string, it will be encoded as a BSON UTF-8 string.

The default is false.

=cut

has prefer_numeric => (
    is => 'ro',
    default => "",
);

=attr wrap_numbers

If set to true, during decoding, numeric values will be wrapped into
BSON type-wrappers: L<BSON::Double>, L<BSON::Int64> or L<BSON::Int32>.
While very slow, this can help ensure fields can round-trip if unmodified.

The default is false.

=cut

has wrap_numbers => (
    is => 'ro',
    default => "",
);

=attr wrap_strings

If set to true, during decoding, string values will be wrapped into a BSON
type-wrappers, L<BSON::String>.  While very slow, this can help ensure
fields can round-trip if unmodified.

The default is false.

=cut

has wrap_strings => (
    is => 'ro',
    default => "",
);

#--------------------------------------------------------------------------#
# public methods
#--------------------------------------------------------------------------#

=method encode_one

    $byte_string = $codec->encode_one( $doc );
    $byte_string = $codec->encode_one( $doc, \%options );

Takes a "document", typically a hash reference, an array reference, or a
Tie::IxHash object and returns a byte string with the BSON representation of
the document.

An optional hash reference of options may be provided.  Valid options include:

=for :list
* first_key – if C<first_key> is defined, it and C<first_value>
  will be encoded first in the output BSON; any matching key found in the
  document will be ignored.
* first_value - value to assign to C<first_key>; will encode as Null if omitted
* error_callback – overrides codec default
* invalid_chars – overrides codec default
* max_length – overrides codec default
* op_char – overrides codec default
* prefer_numeric – overrides codec default

=cut

sub encode_one {
    my ( $self, $document, $options ) = @_;

    my $merged_opts = { %$self, ( $options ? %$options : () ) };

    my $bson = eval { _encode_bson( $document, $merged_opts ) };
    # XXX this is a late max_length check -- it should be checked during
    # encoding after each key
    if ( $@ or ( $merged_opts->{max_length} && length($bson) > $merged_opts->{max_length} ) ) {
        my $msg = $@ || "Document exceeds maximum size $merged_opts->{max_length}";
        if ( $merged_opts->{error_callback} ) {
            $merged_opts->{error_callback}->( $msg, $document, 'encode_one' );
        }
        else {
            Carp::croak("During encode_one, $msg");
        }
    }

    return $bson;
}

=method decode_one

    $doc = $codec->decode_one( $byte_string );
    $doc = $codec->decode_one( $byte_string, \%options );

Takes a byte string with a BSON-encoded document and returns a
hash reference representin the decoded document.

An optional hash reference of options may be provided.  Valid options include:

=for :list
* dbref_callback – overrides codec default
* dt_type – overrides codec default
* error_callback – overrides codec default
* max_length – overrides codec default

=cut

sub decode_one {
    my ( $self, $string, $options ) = @_;

    my $merged_opts = { %$self, ( $options ? %$options : () ) };

    if ( $merged_opts->{max_length} && length($string) > $merged_opts->{max_length} ) {
        my $msg = "Document exceeds maximum size $merged_opts->{max_length}";
        if ( $merged_opts->{error_callback} ) {
            $merged_opts->{error_callback}->( $msg, \$string, 'decode_one' );
        }
        else {
            Carp::croak("During decode_one, $msg");
        }
    }

    my $document = eval { _decode_bson( $string, $merged_opts ) };
    if ( $@ ) {
        if ( $merged_opts->{error_callback} ) {
            $merged_opts->{error_callback}->( $@, \$string, 'decode_one' );
        }
        else {
            Carp::croak("During decode_one, $@");
        }
    }

    return $document;
}

=method clone

    $copy = $codec->clone( ordered => 1 );

Constructs a copy of the original codec, but allows changing
attributes in the copy.

=cut

sub clone {
    my ($self, @args) = @_;
    my $class = ref($self);
    if ( @args == 1 && ref( $args[0] ) eq 'HASH' ) {
        return $class->new( %$self, %{$args[0]} );
    }

    return $class->new( %$self, @args );
}


#--------------------------------------------------------------------------#
# public methods
#--------------------------------------------------------------------------#

=method inflate_extjson

    $bson->inflate_extjson( $data );

Given a hash reference, this method walks the hash, replacing any
L<MongoDB extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
items with BSON type-wrapper equivalents.  Additionally, any JSON
boolean objects (e.g. C<JSON::PP::Boolean>) will be replaced with
L<boolean.pm|boolean> true or false values.

=cut

sub inflate_extjson {
    my ( $self, $hash ) = @_;

    for my $k ( keys %$hash ) {
        my $v = $hash->{$k};
        if ( substr( $k, 0, 1 ) eq '$' ) {
            croak "Dollar-prefixed key '$k' is not legal in top-level hash";
        }
        my $type = ref($v);
        $hash->{$k} =
            $type eq 'HASH'    ? $self->_inflate_hash($v)
          : $type eq 'ARRAY'   ? $self->_inflate_array($v)
          : $type =~ $bools_re ? ( $v ? true : false )
          :                      $v;
    }

    return $hash;
}

#--------------------------------------------------------------------------#
# legacy functional interface
#--------------------------------------------------------------------------#

=function encode

    my $bson = encode({ bar => 'foo' }, \%options);

This is the legacy, functional interface and is only expored on demand.
It takes a hashref and returns a BSON string.

=function decode

    my $hash = decode( $bson, \%options );

This is the legacy, functional interface and is only exported on demand.
It takes a BSON string and returns a hashref.

=cut

{
    my $CODEC;

    sub encode {
        if ( $_[0] eq 'BSON' || ( blessed($_[0]) && $_[0]->isa('BSON') ) ) {
            Carp::croak("Error: 'encode' is a function, not a method");
        }
        my $doc = shift;
        $CODEC = BSON->new unless defined $CODEC;
        if ( @_ == 1 && ref( $_[0] ) eq 'HASH' ) {
            return $CODEC->encode_one( $doc, $_[0] );
        }
        elsif ( @_ % 2 == 0 ) {
            return $CODEC->encode_one( $doc, {@_} );
        }
        else {
            Carp::croak("Options for 'encode' must be a hashref or key-value pairs");
        }
    }

    sub decode {
        if ( $_[0] eq 'BSON' || ( blessed($_[0]) && $_[0]->isa('BSON') ) ) {
            Carp::croak("Error: 'decode' is a function, not a method");
        }
        my $doc = shift;
        $CODEC = BSON->new unless defined $CODEC;
        my $args;
        if ( @_ == 1 && ref( $_[0] ) eq 'HASH' ) {
            $args = shift;
        }
        elsif ( @_ % 2 == 0 ) {
            $args = { @_ };
        }
        else {
            Carp::croak("Options for 'decode' must be a hashref or key-value pairs");
        }
        $args->{ordered} = delete $args->{ixhash}
          if exists $args->{ixhash} && !exists $args->{ordered};
        return $CODEC->decode_one( $doc, $args );
    }
}

#--------------------------------------------------------------------------#
# private functions
#--------------------------------------------------------------------------#

sub _split_re {
    my $value = shift;
    if ( $] ge 5.010 ) {
        return re::regexp_pattern($value);
    }
    else {
        $value =~ s/^\(\?\^?//;
        $value =~ s/\)$//;
        my ( $opt, $re ) = split( /:/, $value, 2 );
        $opt =~ s/\-\w+$//;
        return ( $re, $opt );
    }
}

sub _ixhash_iterator {
    my $ixhash = shift;
    my $started = 0;
    return sub {
        my $k = $started ? $ixhash->NEXTKEY : do { $started++; $ixhash->FIRSTKEY };
        return unless defined $k;
        return ($k, $ixhash->FETCH($k));
    }
}

# XXX could be optimized down to only one substr to trim/pad
sub _bigint_to_int64 {
    my $bigint = shift;
    my $neg = $bigint < 0;
    if ( $neg ) {
        if ( $bigint < $min_int64 ) {
            return "\x80\x00\x00\x00\x00\x00\x00\x00";
        }
        $bigint = abs($bigint) - ($max_int64 + 1);
    }
    elsif ( $bigint > $max_int64 ) {
        return "\x7f\xff\xff\xff\xff\xff\xff\xff";
    }

    my $as_hex = $bigint->as_hex; # big-endian hex
    $as_hex =~ s{-?0x}{};
    my $len = length($as_hex);
    substr( $as_hex, 0, 0, "0" x ( 16 - $len ) ) if $len < 16; # pad to quad length
    my $pack = pack( "H*", $as_hex );
    $pack |= "\x80\x00\x00\x00\x00\x00\x00\x00" if $neg;
    return scalar reverse $pack;
}

sub _int64_to_bigint {
    my $bytes = reverse(shift);
    return Math::BigInt->new() if $bytes eq "\x00\x00\x00\x00\x00\x00\x00\x00";
    if ( unpack("c", $bytes) < 0 ) {
        if ( $bytes eq "\x80\x00\x00\x00\x00\x00\x00\x00" ) {
            return -1 * Math::BigInt->new( "0x" . unpack("H*",$bytes) );
        }
        else {
            return -1 * Math::BigInt->new( "0x" . unpack( "H*", ~$bytes ) ) - 1;
        }
    }
    else {
        return Math::BigInt->new( "0x" . unpack( "H*", $bytes ) );
    }
}

sub _pack_int64 {
    my $value = shift;
    my $type  = ref($value);

    # if no type, then on 64-big perl we can pack with 'q'; otherwise
    # we need to convert scalars to Math::BigInt and pack them that way.
    if ( ! $type ) {
        return pack(BSON_INT64,$value ) if HAS_INT64;
        $value = Math::BigInt->new($value);
        $type = 'Math::BigInt';
    }

    if ( $type eq 'Math::BigInt' ) {
        return _bigint_to_int64($value);
    }
    elsif ( $type eq 'Math::Int64' ) {
        return Math::Int64::int64_to_native($value);
    }
    else {
        croak "Don't know how to encode $type '$value' as an Int64.";
    }
}

sub _encode_bson_pp {
    my ($doc, $opt) = @_;

    return $doc->value if ref($doc) eq 'BSON::Raw';
    return $$doc if ref($doc) eq 'MongoDB::BSON::Raw';

    # XXX works for now, but should be optimized eventually
    $doc = $doc->_as_tied_hash if ref($doc) eq 'BSON::Doc';

    my $iter =
        ref($doc) eq 'BSON::Doc'   ? $doc->_iterator
      : ref($doc) eq 'Tie::IxHash' ? _ixhash_iterator($doc)
      :                              undef;

    my $invalid =
      length( $opt->{invalid_chars} ) ? qr/[\Q$opt->{invalid_chars}\E]/ : undef;

    my $bson = '';
    while ( my ( $key, $value ) = $iter ? $iter->() : (each %$doc) ) {
        last unless defined $key;

        if ( $invalid && $key =~ $invalid ) {
            croak(
                sprintf(
                    "key '%s' has invalid character(s) '%s'",
                    $key, $opt->{invalid_chars}
                )
            );
        }

        my $type = ref $value;

        # Null
        if ( !defined $value ) {
            $bson .= pack( BSON_TYPE_NAME, 0x0A, $key );
        }

        # Array
        elsif ( $type eq 'ARRAY' ) {
            my $i = 0;
            tie( my %h, 'Tie::IxHash' );
            %h = map { $i++ => $_ } @$value;
            $bson .= pack( BSON_TYPE_NAME, 0x04, $key ) . encode( \%h );
        }

        # Document
        elsif ($type eq 'HASH'
            || $type eq 'BSON::Doc'
            || $type eq 'BSON::Raw'
            || $type eq 'Tie::IxHash'
            || $type eq 'MongoDB::BSON::Raw' )
        {
            $bson .= pack( BSON_TYPE_NAME, 0x03, $key ) . encode($value);
        }

        # Regex
        elsif ( $type eq 'Regexp' ) {
            my ( $re, $flags ) = _split_re($value);
            $bson .= pack( BSON_TYPE_NAME.BSON_REGEX, 0x0B, $key, $re, join( "", sort grep /^(i|m|x|l|s|u)$/, split( //, $flags ) ));
        }
        elsif ( $type eq 'BSON::Regex' || $type eq 'MongoDB::BSON::Regexp' ) {
            my ( $re, $flags ) = @{$value}{qw/pattern flags/};
            $bson .= pack( BSON_TYPE_NAME.BSON_REGEX, 0x0B, $key, $re, $flags) ;
        }

        # ObjectId
        elsif ( $type eq 'BSON::OID' || $type eq 'BSON::ObjectId' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_OBJECTID, 0x07, $key, $value->oid );
        }
        elsif ( $type eq 'MongoDB::OID' ) {
            $bson .= pack( BSON_TYPE_NAME."H*", 0x07, $key, $value->value );
        }

        # Datetime
        elsif ( $type eq 'BSON::Time' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . _pack_int64( $value->value );
        }
        elsif ( $type eq 'Time::Moment' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . _pack_int64( int( $value->epoch * 1000 + $value->millisecond ) );
        }
        elsif ( $type eq 'DateTime' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . _pack_int64( int( $value->hires_epoch * 1000 ) );
        }
        elsif ( $type eq 'DateTime::Tiny' ) {
            require Time::Local;
            my $epoch = Time::Local::timegm(
                $value->second, $value->minute,    $value->hour,
                $value->day,    $value->month - 1, $value->year,
            );
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . _pack_int64( $epoch * 1000 );
        }

        # Timestamp
        elsif ( $type eq 'BSON::Timestamp' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_TIMESTAMP, 0x11, $key, $value->increment, $value->seconds );
        }
        elsif ( $type eq 'MongoDB::Timestamp' ){
            $bson .= pack( BSON_TYPE_NAME.BSON_TIMESTAMP, 0x11, $key, $value->inc, $value->sec );
        }

        # MinKey
        elsif ( $type eq 'BSON::MinKey' || $type eq 'MongoDB::MinKey' ) {
            $bson .= pack( BSON_TYPE_NAME, 0xFF, $key );
        }

        # MaxKey
        elsif ( $type eq 'BSON::MaxKey' || $type eq 'MongoDB::MaxKey' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x7F, $key );
        }

        # Binary (XXX need to add string ref support)
        elsif ($type eq 'SCALAR'
            || $type eq 'BSON::Bytes'
            || $type eq 'BSON::Binary'
            || $type eq 'MongoDB::BSON::Binary' )
        {
            my $data =
                $type eq 'SCALAR'      ? $$value
              : $type eq 'BSON::Bytes' ? $value->data
              : $type eq 'MongoDB::BSON::Binary' ? $value->data
              :                          pack( "C*", @{ $value->data } );
            my $subtype = $type eq 'SCALAR' ? 0 : $value->subtype;
            my $len = length($data);
            if ( $subtype == 2 ) {
                $bson .=
                  pack( BSON_TYPE_NAME . BSON_INT32 . BSON_BINARY_TYPE . BSON_INT32 . BSON_REMAINING,
                    0x05, $key, $len + 4, $subtype, $len, $data );
            }
            else {
                $bson .= pack( BSON_TYPE_NAME . BSON_INT32 . BSON_BINARY_TYPE . BSON_REMAINING,
                    0x05, $key, $len, $subtype, $data );
            }
        }

        # Code
        elsif ( $type eq 'BSON::Code' || $type eq 'MongoDB::Code' ) {
            my $code = $value->code;
            utf8::encode($code);
            $code = pack(BSON_STRING,$code);
            if ( ref( $value->scope ) eq 'HASH' ) {
                my $scope = encode( $value->scope );
                $bson .= 
                    pack( BSON_TYPE_NAME.BSON_CODE_W_SCOPE, 0x0F, $key, (4 + length($scope) + length($code)) ) . $code . $scope;
            }
            else {
                $bson .= pack( BSON_TYPE_NAME, 0x0D, $key) . $code;
            }
        }

        # Boolean
        elsif ( $type eq 'boolean' || $type =~ $bools_re ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_BOOLEAN, 0x08, $key, ( $value ? 1 : 0 ) );
        }

        # String (explicit)
        elsif ( $type eq 'BSON::String' ) {
            $value = $value->value;
            utf8::encode($value);
            $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x02, $key, $value );
        }

        # Int64 (XXX and eventually BigInt)
        elsif ( $type eq 'BSON::Int64' || $type eq 'Math::BigInt' || $type eq 'Math::Int64' )
        {
            if ( $value > $max_int64 || $value < $min_int64 ) {
                croak("BSON can only handle 8-byte integers. Key '$key' is '$value'");
            }

            # unwrap BSON::Int64; it could be Math::BigInt, etc.
            if ( $type eq 'BSON::Int64' ) {
                $value = $value->value;
            }

            $bson .= pack( BSON_TYPE_NAME, 0x12, $key ) . _pack_int64($value);
        }

        # Double (explicit)
        elsif ( $type eq 'BSON::Double' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_DOUBLE, 0x01, $key, $value/1.0 );
        }

        # Int (BSON::Int32 or heuristic based on size)
        elsif ( $value =~ $int_re ) {
            if ( $value > $max_int64 || $value < $min_int64 ) {
                croak("BSON can only handle 8-byte integers. Key '$key' is '$value'");
            }
            elsif ( $value > $max_int32 || $value < $min_int32 ) {
                $bson .= pack( BSON_TYPE_NAME, 0x12, $key ) . _pack_int64($value);
            }
            else {
                $bson .= pack( BSON_TYPE_NAME . BSON_INT32, 0x10, $key, $value );
            }
        }

        # Double
        elsif ( $value =~ $doub_re ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_DOUBLE, 0x01, $key, $value );
        }

        # String
        elsif ( $type eq '' ) {
            utf8::encode($value);
            $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x02, $key, $value );
        }

        # Unsupported type
        else  {
            croak("For key '$key', can't encode value of type '$type'");
        }
    }

    return pack( BSON_INT32, length($bson) + 5 ) . $bson . "\0";
}

my %FIELD_SIZES = (
    0x01 => 8,
    0x02 => 5,
    0x03 => 5,
    0x04 => 5,
    0x05 => 5,
    0x06 => 0,
    0x07 => 12,
    0x08 => 1,
    0x09 => 8,
    0x0A => 0,
    0x0B => 2,
    0x0C => 17,
    0x0D => 5,
    0x0E => 5,
    0x0F => 11,
    0x10 => 4,
    0x11 => 8,
    0x12 => 8,
    0x7F => 0,
    0xFF => 0,
);

my $ERR_UNSUPPORTED = "Unsupported BSON type 0x%x for key '%s'.  Are you using the latest driver version?";
my $ERR_TRUNCATED = "Premature end of BSON field '%s' (type 0x%x)";
my $ERR_LENGTH = "BSON field '%s' (type 0x%x) has invalid length: wanted %d, got %d";
my $ERR_MISSING_NULL = "BSON field '%s' (type 0x%x) missing null terminator";
my $ERR_BAD_UTF8 = "BSON field '%s' (type 0x%x) contains invalid UTF-8";
my $ERR_NEG_LENGTH = "BSON field '%s' (type 0x%x) contains negative length";
my $ERR_BAD_OLDBINARY = "BSON field '%s' (type 0x%x, subtype 0x02) is invalid";

sub __dump_bson {
    my $bson = unpack("H*", shift);
    my @pairs = $bson=~ m/(..)/g;
    return join(" ", @pairs);
}

sub _decode_bson_pp {
    my ($bson, $opt) = @_;
    my $blen= length($bson);
    my $len = unpack( BSON_INT32, $bson );
    if ( length($bson) != $len ) {
        croak("Incorrect length of the bson string (got $blen, wanted $len)");
    }
    if ( chop($bson) ne "\x00" ) {
        croak("BSON document not null terminated");
    }
    $bson = substr $bson, 4;
    my @array = ();
    my %hash = ();
    tie( %hash, 'Tie::IxHash' ) if $opt->{ordered};
    my ($type, $key, $value);
    while ($bson) {
        ( $type, $key, $bson ) = unpack( BSON_TYPE_NAME.BSON_REMAINING, $bson );

        # Check type and truncation
        my $min_size = $FIELD_SIZES{$type};
        if ( !defined $min_size ) {
            croak( sprintf( $ERR_UNSUPPORTED, $type, $key ) );
        }
        if ( length($bson) < $min_size ) {
            croak( sprintf( $ERR_TRUNCATED, $key, $type ) );
        }

        # Double
        if ( $type == 0x01 ) {
            ( $value, $bson ) = unpack( BSON_DOUBLE.BSON_REMAINING, $bson );
            $value = BSON::Double->new( value => $value ) if $opt->{wrap_numbers};
        }

        # String and Symbol (deprecated); Symbol will be convert to String
        elsif ( $type == 0x02 || $type == 0x0E ) {
            ( $len, $bson ) = unpack( BSON_INT32 . BSON_REMAINING, $bson );
            if ( length($bson) < $len || substr( $bson, $len - 1, 1 ) ne "\x00" ) {
                croak( sprintf( $ERR_MISSING_NULL, $key, $type ) );
            }
            ( $value, $bson ) = unpack( "a$len" . BSON_REMAINING, $bson );
            chop($value); # remove trailing \x00
            if ( !utf8::decode($value) ) {
                croak( sprintf( $ERR_BAD_UTF8, $key, $type ) );
            }
            $value = BSON::String->new( value => $value ) if $opt->{wrap_strings};
        }

        # Document and Array
        elsif ( $type == 0x03 || $type == 0x04 ) {
            my $len = unpack( BSON_INT32, $bson );
            $value = _decode_bson_pp( substr( $bson, 0, $len ), { %$opt, _decode_array => $type == 0x04}  );
            $bson = substr( $bson, $len, length($bson) - $len );
        }

        # Binary
        elsif ( $type == 0x05 ) {
            my ( $len, $btype ) = unpack( BSON_INT32 . BSON_BINARY_TYPE, $bson );
            substr( $bson, 0, 5, '' );

            if ( $len < 0 ) {
                croak( sprintf( $ERR_NEG_LENGTH, $key, $type ) );
            }
            if ( $len > length($bson) ) {
                croak( sprintf( $ERR_TRUNCATED, $key, $type ) );
            }

            my $binary = substr( $bson, 0, $len, '' );

            if ( $btype == 2 ) {
                if ( $len < 4 ) {
                    croak( sprintf( $ERR_BAD_OLDBINARY, $key, $type ) );
                }

                my $sublen = unpack( BSON_INT32, $binary );
                if ( $sublen != length($binary) - 4 ) {
                    croak( sprintf( $ERR_BAD_OLDBINARY, $key, $type ) );
                }

                substr( $binary, 0, 4, '' );
            }

            $value = BSON::Bytes->new( subtype => $btype, data => $binary );
        }

        # Undef (deprecated)
        elsif ( $type == 0x06 ) {
            $value = undef;
        }

        # ObjectId
        elsif ( $type == 0x07 ) {
            ( my $oid, $bson ) = unpack( BSON_OBJECTID.BSON_REMAINING, $bson );
            $value = BSON::OID->new(oid => $oid);
        }

        # Boolean
        elsif ( $type == 0x08 ) {
            ( my $bool, $bson ) = unpack( BSON_BOOLEAN.BSON_REMAINING, $bson );
            croak("BSON boolean must be 0 or 1. Key '$key' is $bool")
                unless $bool == 0 || $bool == 1;
            $value = boolean( $bool );
        }

        # Datetime
        elsif ( $type == 0x09 ) {
            if ( HAS_INT64 ) {
                ($value, $bson) = unpack(BSON_INT64.BSON_REMAINING,$bson);
            }
            else {
                ($value, $bson) = unpack(BSON_8BYTES.BSON_REMAINING,$bson);
                $value = _int64_to_bigint($value);
            }
            $value = BSON::Time->new( value => $value );
        }

        # Null
        elsif ( $type == 0x0A ) {
            $value = undef;
        }

        # Regex
        elsif ( $type == 0x0B ) {
            ( my $re, my $op, $bson ) = unpack( BSON_CSTRING.BSON_CSTRING.BSON_REMAINING, $bson );
            $value = BSON::Regex->new( pattern => $re, flags => $op );
        }

        # DBPointer (deprecated)
        elsif ( $type == 0x0C ) {
            ( $len, $bson ) = unpack( BSON_INT32 . BSON_REMAINING, $bson );
            if ( length($bson) < $len || substr( $bson, $len - 1, 1 ) ne "\x00" ) {
                croak( sprintf( $ERR_MISSING_NULL, $key, $type ) );
            }
            ( my ($ref), $bson ) = unpack( "a$len" . BSON_REMAINING, $bson );
            chop($ref); # remove trailing \x00
            if ( !utf8::decode($ref) ) {
                croak( sprintf( $ERR_BAD_UTF8, $key, $type ) );
            }

            ( my ($oid), $bson ) = unpack( BSON_OBJECTID . BSON_REMAINING, $bson );
            $value = { '$ref' => $ref, '$id' => BSON::OID->new( oid => $oid ) };
        }

        # Code
        elsif ( $type == 0x0D ) {
            ( $len, $bson ) = unpack( BSON_INT32 . BSON_REMAINING, $bson );
            if ( length($bson) < $len || substr( $bson, $len - 1, 1 ) ne "\x00" ) {
                croak( sprintf( $ERR_MISSING_NULL, $key, $type ) );
            }
            ( $value, $bson ) = unpack( "a$len" . BSON_REMAINING, $bson );
            chop($value); # remove trailing \x00
            if ( !utf8::decode($value) ) {
                croak( sprintf( $ERR_BAD_UTF8, $key, $type ) );
            }
            $value = BSON::Code->new( code => $value );
        }

        # Code with scope
        elsif ( $type == 0x0F ) {
            my $len = unpack( BSON_INT32, $bson );

            # validate length
            if ( $len < 0 ) {
                croak( sprintf( $ERR_NEG_LENGTH, $key, $type ) );
            }
            if ( $len > length($bson) ) {
                croak( sprintf( $ERR_TRUNCATED, $key, $type ) );
            }
            if ( $len < 5 ) {
                croak( sprintf( $ERR_LENGTH, $key, $type, 5, $len ) );
            }

            # extract code and scope and chop off leading length
            my $codewscope = substr( $bson, 0, $len, '' );
            substr( $codewscope, 0, 4, '' );

            # extract code ( i.e. string )
            my $strlen = unpack( BSON_INT32, $codewscope );
            substr( $codewscope, 0, 4, '' );

            if ( length($codewscope) < $strlen || substr( $codewscope, -1, 1 ) ne "\x00" ) {
                croak( sprintf( $ERR_MISSING_NULL, $key, $type ) );
            }

            my $code = substr($codewscope, 0, $strlen, '' );
            chop($code); # remove trailing \x00
            if ( !utf8::decode($code) ) {
                croak( sprintf( $ERR_BAD_UTF8, $key, $type ) );
            }

            if ( length($codewscope) < 5 ) {
                croak( sprintf( $ERR_TRUNCATED, $key, $type ) );
            }

            # extract scope
            my $scopelen = unpack( BSON_INT32, $codewscope );
            if ( length($codewscope) < $scopelen || substr( $codewscope, $scopelen - 1, 1 ) ne "\x00" ) {
                croak( sprintf( $ERR_MISSING_NULL, $key, $type ) );
            }

            my $scope = _decode_bson_pp( $codewscope, { %$opt, _decode_array => 0} );

            $value = BSON::Code->new( code => $code, scope => $scope );
        }

        # Int32
        elsif ( $type == 0x10 ) {
            ( $value, $bson ) = unpack( BSON_INT32.BSON_REMAINING, $bson );
            $value = BSON::Int32->new( value => $value ) if $opt->{wrap_numbers};
        }

        # Timestamp
        elsif ( $type == 0x11 ) {
            ( my $sec, my $inc, $bson ) = unpack( BSON_INT32.BSON_INT32.BSON_REMAINING, $bson );
            $value = BSON::Timestamp->new( $inc, $sec );
        }

        # Int64
        elsif ( $type == 0x12 ) {
            if ( HAS_INT64 ) {
                ($value, $bson) = unpack(BSON_INT64.BSON_REMAINING,$bson);
            }
            else {
                ($value, $bson) = unpack(BSON_8BYTES.BSON_REMAINING,$bson);
                $value = _int64_to_bigint($value);
            }
            $value = BSON::Int64->new( value => $value ) if $opt->{wrap_numbers};
        }

        # MinKey
        elsif ( $type == 0xFF ) {
            $value = BSON::MinKey->new;
        }

        # MaxKey
        elsif ( $type == 0x7F ) {
            $value = BSON::MaxKey->new;
        }

        # ???
        else {
            croak "Unsupported type $type";
        }

        if ( $opt->{_decode_array} ) {
            push @array, $value;
        }
        else {
            $hash{$key} = $value;
        }
    }
    return $opt->{_decode_array} ? \@array : \%hash;
}

sub _inflate_hash {
    my ( $class, $hash ) = @_;

    if ( exists $hash->{'$oid'} ) {
        return BSON::OID->new( oid => pack( "H*", $hash->{'$oid'} ) );
    }

    if ( exists $hash->{'$numberInt'} ) {
        return BSON::Int32->new( value => $hash->{'$numberInt'} );
    }

    if ( exists $hash->{'$numberLong'} ) {
        if (HAS_INT64) {
            return BSON::Int64->new( value => $hash->{'$numberLong'} );
        }
        else {
            return BSON::Int64->new( value => Math::BigInt->new($hash->{'$numberLong'}) );
        }
    }

    if ( exists $hash->{'$binary'} ) {
        require MIME::Base64;
        return BSON::Bytes->new(
            data    => MIME::Base64::decode_base64($hash->{'$binary'}),
            subtype => hex( $hash->{'$type'} || 0 )
        );
    }

    if ( exists $hash->{'$date'} ) {
        my $v = $hash->{'$date'};
        $v = ref($v) eq 'HASH' ? BSON->_inflate_hash($v) : _iso8601_to_epochms($v);
        return BSON::Time->new( value => $v );
    }

    if ( exists $hash->{'$minKey'} ) {
        return BSON::MinKey->new;
    }

    if ( exists $hash->{'$maxKey'} ) {
        return BSON::MaxKey->new;
    }

    if ( exists $hash->{'$timestamp'} ) {
        return BSON::Timestamp->new(
            seconds   => $hash->{'$timestamp'}{t},
            increment => $hash->{'$timestamp'}{i},
        );
    }

    if ( exists $hash->{'$regex'} ) {
        return BSON::Regex->new(
            pattern => $hash->{'$regex'},
            ( exists $hash->{'$options'} ? ( flags => $hash->{'$options'} ) : () ),
        );
    }

    if ( exists $hash->{'$code'} ) {
        return BSON::Code->new(
            code => $hash->{'$code'},
            ( exists $hash->{'$scope'} ? ( scope => $hash->{'$scope'} ) : () ),
        );
    }

    if ( exists $hash->{'$undefined'} ) {
        return undef; ## no critic
    }

    if ( exists $hash->{'$ref'} ) {
        my $id = $hash->{'$id'};
        $id = BSON->_inflate_hash($id) if ref($id) eq 'HASH';
        return { '$ref' => $hash->{'$ref'}, '$id' => $id };
    }

    # Following extended JSON is non-standard

    if ( exists $hash->{'$numberDouble'} ) {
        return BSON::Double->new( value => $hash->{'$numberDouble'} );
    }

    if ( exists $hash->{'$symbol'} ) {
        return $hash->{'$symbol'};
    }

    return $hash;
}

sub _inflate_array {
    my ($class, $array) = @_;
    if (@$array) {
        for my $i ( 0 .. $#$array ) {
            my $v = $array->[$i];
            $array->[$i] =
                ref($v) eq 'HASH'  ? BSON->_inflate_hash($v)
              : ref($v) eq 'ARRAY' ? _inflate_array($v)
              :                       $v;
        }
    }
    return $array;
}

my $iso8601_re = qr{
    (\d{4}) - (\d{2}) - (\d{2}) T               # date
    (\d{2}) : (\d{2}) : ( \d+ (?:\. \d+ )? )    # time
    (?: Z | ([+-] \d{2} :? (?: \d{2} )? ) )?    # maybe TZ
}x;

sub _iso8601_to_epochms {
    my ($date) = shift;
    require Time::Local;

    my $zone_offset = 0;;
    if ( substr($date,-1,1) eq 'Z' ) {
        chop($date);
    }

    if ( $date =~ /\A$iso8601_re\z/ ) {
        my ($Y,$M,$D,$h,$m,$s,$z) = ($1,$2-1,$3,$4,$5,$6,$7);
        if (defined($z) && length($z))  {
            $z =~ tr[:][];
            $z .= "00" if length($z) < 5;
            my $zd = substr($z,0,1);
            my $zh = substr($z,1,2);
            my $zm = substr($z,3,2);
            $zone_offset = ($zd eq '-' ? -1 : 1 ) * (3600 * $zh + 60 * $zm);
        }
        my $frac = $s - int($s);
        my $epoch = Time::Local::timegm(int($s), $m, $h, $D, $M, $Y) - $zone_offset;
        $epoch = HAS_INT64 ? 1000 * $epoch : Math::BigInt->new($epoch) * 1000;
        $epoch += $frac * 1000;
        return $epoch;
    }
    else {
        Carp::croak("Couldn't parse '\$date' field: $date\n");
    }
}

BEGIN {
    *_encode_bson = \&_encode_bson_pp;
    *_decode_bson = \&_decode_bson_pp;
}

1;

__END__

=head1 SYNOPSIS

    use BSON qw/encode decode/;
    use boolean;

    my $document = {
        _id      => BSON::ObjectId->new,
        date     => BSON::Time->new,
        name     => 'James Bond',
        age      => 45,
        amount   => 24587.45,
        badass   => true,
        password => BSON::String->new('12345')
    };

    my $bson = encode( $document );
    my $doc2 = decode( $bson, %options );

=head1 DESCRIPTION

This module implements BSON serialization and deserialization as described at
L<http://bsonspec.org>. BSON is the primary data representation for MongoDB.

=head1 EXPORT

The module does not export anything. You have to request C<encode> and/or
C<decode> manually.

    use BSON qw/encode decode/;

=head1 SUBROUTINES

=head2 encode

Takes a hashref and returns a BSON string.

    my $bson = encode({ bar => 'foo' });

=head2 decode

Takes a BSON string and returns a hashref.

    my $hash = decode( $bson, ixhash => 1 );

The options after C<$bson> are optional and they can be any of the following:

=head3 options

=over

=item 1

ixhash => 1|0

If set to 1 C<decode> will return a L<Tie::IxHash> ordered hash. Otherwise,
a regular unordered hash will be returned. Turning this option on entails a
significant speed penalty as Tie::IxHash is slower than a regular Perl hash.
The default value for this option is 0.

=back

=head1 THREADS

This module is thread safe.

=head1 LIMITATION

MongoDB sets a limit for any BSON record to 16MB. This module does not enforce this
limit and you can use it to C<encode> and C<decode> structures as large as you
please.

=head1 CAVEATS

BSON uses zero terminated strings and Perl allows the \0 character to be anywhere
in a string. If you expect your strings to contain \0 characters, use L<BSON::Binary>
instead.

=head1 HISTORY AND ROADMAP

This module was originally written by minimalist.  In 2014, he graciously
transferred ongoing maintenance to MongoDB, Inc.

Going forward, work will focus on restoration of a pure-Perl dependency chain,
harmonization with L<MongoDB driver|MongoDB> BSON classes and some API
enhancements so this can provide a pure-Perl alternative serializer for the
MongoDB driver.

=head1 SEE ALSO

L<BSON::String>, L<BSON::Time>, L<BSON::ObjectId>, L<BSON::Code>,
L<BSON::Binary>, L<BSON::Bool>, L<BSON::MinKey>, L<BSON::MaxKey>,
L<BSON::Timestamp>, L<Tie::IxHash>, L<MongoDB>

=cut
