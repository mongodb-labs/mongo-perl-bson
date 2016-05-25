use 5.008001;
use strict;
use warnings;

package BSON;
# ABSTRACT: BSON serialization and deserialization

use base 'Exporter';
our @EXPORT_OK = qw/encode decode/;

our $VERSION = '0.17';

use Carp;
use Config;
use Scalar::Util qw/blessed/;

use Moo;
use BSON::Types (); # loads types for extjson inflation
use boolean;

use constant {
    HAS_INT64 => $Config{use64bitint},
    HAS_LD    => $Config{uselongdouble},
};

use if !HAS_INT64, "Math::BigInt";

my $bools_re = qr/::(?:Boolean|_Bool|Bool)\z/;

use namespace::clean -except => 'meta';

BEGIN {
    require BSON::PP;
    *_encode_bson = \&BSON::PP::_encode_bson;
    *_decode_bson = \&BSON::PP::_decode_bson;
}

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
);

=attr op_char

This is a single character to use for special MongoDB-specific query
operators.  If a key starts with C<op_char>, the C<op_char> character will
be replaced with "$".

The default is "$", meaning that no replacement is necessary.

=cut

has op_char => (
    is  => 'ro',
    isa => sub { die "not a single character" if defined $_[0] && length $_[0] > 1 },
);

=attr ordered

If set to a true value, then decoding will return a reference to a tied
hash that preserves key order. Otherwise, a regular (unordered) hash
reference will be returned.

B<IMPORTANT CAVEATS>:

=for :list
* When 'ordered' is true, users must not rely on the return value being any
  particular tied hash implementation.  It may change in the future for
  efficiency.
* Turning this option on entails a significant speed penalty as tied hashes
  are slower than regular Perl hashes.

The default is false.

=cut

has ordered => (
    is => 'ro',
);

=attr prefer_numeric

If set to true, scalar values that look like a numeric value will be
encoded as a BSON numeric type.  When false, if the scalar value was ever
used as a string, it will be encoded as a BSON UTF-8 string, otherwise
it will be encoded as a numeric type.

B<IMPORTANT CAVEAT>: the heuristics for determining whether something is a
string or number are less accurate on older Perls.  See L<BSON::Types>
for wrapper classes that specify exact serialization types.

The default is false.

=cut

has prefer_numeric => (
    is => 'ro',
);

=attr wrap_dbrefs

If set to true, during decoding, documents with the fields C<'$id'> and
C<'$ref'> (literal dollar signs, not variables) will be wrapped as
L<BSON::DBRef> objects.  If false, they are decoded into ordinary hash
references (or ordered hashes, if C<ordered> is true).

The default is true.

=cut

has wrap_dbrefs  => (
    is => 'ro',
);

=attr wrap_numbers

If set to true, during decoding, numeric values will be wrapped into
BSON type-wrappers: L<BSON::Double>, L<BSON::Int64> or L<BSON::Int32>.
While very slow, this can help ensure fields can round-trip if unmodified.

The default is false.

=cut

has wrap_numbers => (
    is => 'ro',
);

=attr wrap_strings

If set to true, during decoding, string values will be wrapped into a BSON
type-wrappers, L<BSON::String>.  While very slow, this can help ensure
fields can round-trip if unmodified.

The default is false.

=cut

has wrap_strings => (
    is => 'ro',
);

=attr dt_type (Discouraged)

Sets the type of object which is returned for BSON DateTime fields. The
default is C<undef>, which returns objects of type L<BSON::Time>.  This is
overloaded to be the integer epoch value when used as a number or string,
so is somewhat backwards compatible with C<dt_type> in the L<MongoDB>
driver.

Other acceptable values are L<BSON::Time> (explicitly), L<DateTime>,
L<Time::Moment>, L<DateTime::Tiny>.

Because BSON::Time objects have methods to convert to DateTime,
Time::Moment or DateTime::Tiny, use of this field is discouraged.  Users
should use these methods on demand.  This option is provided for backwards
compatibility only.

=cut

has dt_type => (
    is      => 'ro',
    isa     => sub { return if !defined($_[0]); die "not a string" if ref $_[0] },
);

sub BUILD {
    my ($self) = @_;
    $self->{wrap_dbrefs} = 1 unless defined $self->{wrap_dbrefs};
    $self->{invalid_chars} = "" unless defined $self->{invalid_chars};
}

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

    $document = BSON::Doc->new(@$document)
      if ref($document) eq 'ARRAY';

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
hash reference representing the decoded document.

An optional hash reference of options may be provided.  Valid options include:

=for :list
* dt_type – overrides codec default
* error_callback – overrides codec default
* max_length – overrides codec default
* ordered - overrides codec default
* wrap_dbrefs - overrides codec default
* wrap_numbers - overrides codec default
* wrap_strings - overrides codec default

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
# public class methods
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

=func encode

    my $bson = encode({ bar => 'foo' }, \%options);

This is the legacy, functional interface and is only exported on demand.
It takes a hashref and returns a BSON string.
It uses an internal codec singleton with default attributes.

=func decode

    my $hash = decode( $bson, \%options );

This is the legacy, functional interface and is only exported on demand.
It takes a BSON string and returns a hashref.
It uses an internal codec singleton with default attributes.

=cut

{
    my $CODEC;

    sub encode {
        if ( defined $_[0] && ( $_[0] eq 'BSON' || ( blessed($_[0]) && $_[0]->isa('BSON') ) ) ) {
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
        if ( defined $_[0] && ( $_[0] eq 'BSON' || ( blessed($_[0]) && $_[0]->isa('BSON') ) ) ) {
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
        return BSON::DBRef->new( '$ref' => $hash->{'$ref'}, '$id' => $id );
    }

    if ( exists $hash->{'$numberDecimal'} ) {
        return BSON::Decimal128->new( value => $hash->{'$numberDecimal'} );
    }

    # Following extended JSON is non-standard

    if ( exists $hash->{'$numberDouble'} ) {
        if ( $hash->{'$numberDouble'} eq '-0' && $] lt '5.014' && ! HAS_LD ) {
            $hash->{'$numberDouble'} = '-0.0';
        }
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

1;

__END__

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    my $codec = BSON->new;

    my $bson = $codec->encode_one( $document );
    my $doc  = $codec->decode_one( $bson     );

=head1 DESCRIPTION

This class implements a BSON encoder/decoder ("codec").  It consumes
"documents" (typically hash references) and emits BSON strings and vice
versa in accordance with the L<BSON Specification|http://bsonspec.org>.

BSON is the primary data representation for L<MongoDB>.  While this module
has several features that support MongoDB-specific needs and conventions,
it can be used as a standalone serialization format.

The codec may be customized through attributes on the codec option as well
as encode/decode specific options on methods:

    my $codec = BSON->new( \%global_attributes );

    my $bson = $codec->encode_one( $document, \%encode_options );
    my $doc  = $codec->decode_one( $bson    , \%decode_options );

Because BSON is strongly-typed and Perl is not, this module supports
a number of "type wrappers" – classes that wrap Perl data to indicate how
they should serialize. The L<BSON::Types> module describes these and
provides associated helper functions.

When decoding, type wrappers are used for any data that has no native Perl
representation.  Optionally, all data may be wrapped for precise control of
round-trip encoding.

Please read the configuration attributes carefully to understand more about
how to control encoding and decoding.

=head1 THREADS

This module is thread safe.

=head1 HISTORY

This module was originally written by Stefan G.  In 2014, he graciously
transferred ongoing maintenance to MongoDB, Inc.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
