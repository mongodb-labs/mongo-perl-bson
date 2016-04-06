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
use Tie::IxHash;
use Math::Int64 qw/:native_if_available int64 int64_to_native native_to_int64/;

use BSON::Types ();
use boolean;

require re; # don't "use" or we get a "useless pragma" warning on old perls

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
    BSON_INT64 => "LL",
    BSON_TIMESTAMP => "LL",
    BSON_CODE_W_SCOPE => "l",
    BSON_REMAINING => 'a*',
    BSON_SKIP_4_BYTES => 'x4',
    BSON_OBJECTID => 'a12',
    BSON_BINARY_TYPE => 'C',
    BSON_CSTRING => 'Z*',
};

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

sub encode {
    my $doc = shift;

    return $doc->value if ref($doc) eq 'BSON::Raw';
    return $$doc if ref($doc) eq 'MongoDB::BSON::Raw';

    # XXX works for now, but should be optimized eventually
    $doc = $doc->_as_tied_hash if ref($doc) eq 'BSON::Doc';

    my $iter =
        ref($doc) eq 'BSON::Doc'   ? $doc->_iterator
      : ref($doc) eq 'Tie::IxHash' ? _ixhash_iterator($doc)
      :                              undef;

    my $bson = '';
    while ( my ( $key, $value ) = $iter ? $iter->() : (each %$doc) ) {
        last unless defined $key;

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
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . int64_to_native( $value->value );
        }
        elsif ( $type eq 'Time::Moment' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . int64_to_native( int($value->epoch * 1000 + $value->millisecond) );
        }
        elsif ( $type eq 'DateTime' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . int64_to_native( int($value->hires_epoch * 1000) );
        }
        elsif ( $type eq 'DateTime::Tiny' ) {
            require Time::Local;
            my $epoch = Time::Local::timegm(
                $value->second, $value->minute,    $value->hour,
                $value->day, $value->month - 1, $value->year,
            );
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . int64_to_native( $epoch * 1000 );
        }

        # Timestamp
        elsif ( $type eq 'BSON::Timestamp' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_TIMESTAMP, 0x11, $key, $value->increment, $value->seconds );
        }

        # MinKey
        elsif ( $type eq 'BSON::MinKey' ) {
            $bson .= pack( BSON_TYPE_NAME, 0xFF, $key );
        }

        # MaxKey
        elsif ( $type eq 'BSON::MaxKey' ) {
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
        elsif ( $type eq 'BSON::Int64' || $type eq 'Math::BigInt' || $type eq 'Math::Int64' ) {
            if ( $value > $max_int64 || $value < $min_int64 ) {
                croak("BSON can only handle 8-byte integers. Key '$key' is '$value'");
            }
            $bson .= pack( BSON_TYPE_NAME.BSON_REMAINING, 0x12, $key, int64_to_native( $value ) );
        }

        # Double (explicit)
        elsif ( $type eq 'BSON::Double' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_DOUBLE, 0x01, $key, $value/1.0 );
        }

        # Int (Int32 or arbitrary)
        elsif ( $type eq 'Math::Int64' || $value =~ $int_re ) {
            if ( $value > $max_int64 || $value < $min_int64 ) {
                croak("MongoDB can only handle 8-byte integers. Key '$key' is '$value'");
            }
            $bson .= $value > $max_int32 || $value < $min_int32 ? pack( BSON_TYPE_NAME.BSON_REMAINING, 0x12, $key, int64_to_native( $value ))
                                                                  : pack( BSON_TYPE_NAME.BSON_INT32, 0x10, $key, $value );
        }

        # Double
        elsif ( $value =~ $doub_re ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_DOUBLE, 0x01, $key, $value );
        }

        # String
        else {
            utf8::encode($value);
            $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x02, $key, $value );
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

sub decode {
    my $bson = shift;
    my $blen= length($bson);
    my $len = unpack( BSON_INT32, $bson );
    if ( length($bson) != $len ) {
        croak("Incorrect length of the bson string (got $blen, wanted $len)");
    }
    if ( chop($bson) ne "\x00" ) {
        croak("BSON document not null terminated");
    }
    my %opt = @_;
    $bson = substr $bson, 4;
    my @array = ();
    my %hash = ();
    tie( %hash, 'Tie::IxHash' ) if $opt{ixhash} || $opt{ordered};
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
            $value = BSON::Double->new( value => $value ) if $opt{wrap_numbers};
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
            $value = BSON::String->new( value => $value ) if $opt{wrap_strings};
        }

        # Document and Array
        elsif ( $type == 0x03 || $type == 0x04 ) {
            my $len = unpack( BSON_INT32, $bson );
            $value = decode( substr( $bson, 0, $len ), %opt, _decode_array => $type == 0x04 );
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
            my ($l1, $l2) = @_;
            ($l1, $l2, $bson) = unpack(BSON_INT64.BSON_REMAINING,$bson);
            my $dt = native_to_int64(pack(BSON_INT64,$l1, $l2));
            $value = BSON::Time->new( value => $dt );
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

            my $scope = decode( $codewscope, %opt, _decode_array => 0 );

            $value = BSON::Code->new( code => $code, scope => $scope );
        }

        # Int32
        elsif ( $type == 0x10 ) {
            ( $value, $bson ) = unpack( BSON_INT32.BSON_REMAINING, $bson );
            $value = BSON::Int32->new( value => $value ) if $opt{wrap_numbers};
        }

        # Timestamp
        elsif ( $type == 0x11 ) {
            ( my $sec, my $inc, $bson ) = unpack( BSON_INT64.BSON_REMAINING, $bson );
            $value = BSON::Timestamp->new( $inc, $sec );
        }

        # Int64
        elsif ( $type == 0x12 ) {
            my ($l1, $l2) = @_;
            ($l1, $l2, $bson) = unpack(BSON_INT64.BSON_REMAINING,$bson);
            $value = native_to_int64(pack(BSON_INT64,$l1, $l2));
            $value = BSON::Int64->new( value => $value ) if $opt{wrap_numbers};
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

        if ( $opt{_decode_array} ) {
            push @array, $value;
        }
        else {
            $hash{$key} = $value;
        }
    }
    return $opt{_decode_array} ? \@array : \%hash;
}

sub inflate_extjson {
    my ( $class, $hash ) = @_;

    for my $k ( keys %$hash ) {
        my $v = $hash->{$k};
        if ( substr( $k, 0, 1 ) eq '$' ) {
            croak "Dollar-prefixed key '$k' is not legal in top-level hash";
        }
        my $type = ref($v);
        $hash->{$k} =
            $type eq 'HASH'    ? $class->_inflate_hash($v)
          : $type eq 'ARRAY'   ? $class->_inflate_array($v)
          : $type =~ $bools_re ? boolean($v)
          :                      $v;
    }

    return $hash;
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
        return BSON::Int64->new( value => $hash->{'$numberLong'} );
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
        return undef;
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
        if (length($z))  {
            $z =~ tr[:][];
            $z .= "00" if length($z) < 5;
            my $zd = substr($z,0,1);
            my $zh = substr($z,1,2);
            my $zm = substr($z,3,2);
            $zone_offset = ($zd eq '-' ? -1 : 1 ) * (3600 * $zh + 60 * $zm);
        }
        my $frac = $s - int($s);
        my $epoch = Time::Local::timegm(int($s), $m, $h, $D, $M, $Y);
        return int( 1000 * ( $epoch - $zone_offset + $frac ) );
    }
    else {
        Carp::croak("Couldn't parse '\$date' field: $date\n");
    }
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
