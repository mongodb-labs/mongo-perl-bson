use 5.008001;
use strict;
use warnings;

package BSON;
# ABSTRACT: BSON serialization and deserialization

use base 'Exporter';
our @EXPORT_OK = qw/encode decode/;

use version;
our $VERSION = 'v1.1.0';

use Carp;
use Config;
use Scalar::Util qw/blessed/;

use Moo 2.002004; # safer generated code
use Module::Runtime qw/require_module/;
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
    my $class;
    if ( $class = $ENV{PERL_BSON_BACKEND} ) {
        eval { require_module($class) };
        if ( my $err = $@ ) {
            $err =~ s{ at \S+ line .*}{};
            die "Error: PERL_BSON_BACKEND '$class' could not be loaded: $err\n";
        }
        unless ($class->can("_encode_bson") && $class->can("_decode_bson") ) {
            die "Error: PERL_BSON_BACKEND '$class' does not implement the correct API.\n";
        }
    }
    elsif ( eval { require_module( $class = "BSON::XS" ); $INC{'BSON/XS.pm'} } ) {
        # module loaded; nothing else to do
    }
    else {
        require_module( $class = "BSON::PP" );
    }

    *_encode_bson = $class->can("_encode_bson");
    *_decode_bson = $class->can("_decode_bson");
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
L<Time::Moment>, L<DateTime::Tiny>, L<Mango::BSON::Time>.

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

    use JSON::MaybeXS;
    $data = decode_json( $json_string );
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

    use BSON;
    use BSON::Types ':all';
    use boolean;

    my $codec = BSON->new;

    my $document = {
        _id             => bson_oid(),
        creation_time   => bson_time(),
        zip_code        => bson_string("08544"),
        hidden          => false,
    };

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
provides associated helper functions.  See L</PERL-BSON TYPE MAPPING>
for more details.

When decoding, type wrappers are used for any data that has no native Perl
representation.  Optionally, all data may be wrapped for precise control of
round-trip encoding.

Please read the configuration attributes carefully to understand more about
how to control encoding and decoding.

At compile time, this module will select an implementation backend.  It
will prefer C<BSON::XS> (released separately) if available, or will fall
back to L<BSON::PP> (bundled with this module).  See L</ENVIRONMENT> for
a way to control the selection of the backend.

=head1 PERL-BSON TYPE MAPPING

BSON has numerous data types and Perl does not.

When B<decoding>, each BSON type should result in a single, predictable
Perl type.  Where no native Perl type is appropriate, BSON decodes to an
object of a particular class (a "type wrapper").

When B<encoding>, for historical reasons, there may be many Perl
representations that should encode to a particular BSON type.  For example,
all the popular "boolean" type modules on CPAN should encode to the BSON
boolean type.  Likewise, as this module is intended to supersede the
type wrappers that have shipped with the L<MongoDB> module, those
type wrapper are supported by this codec.

The table below describes the BSON/Perl mapping for both encoding and
decoding.

On the left are all the Perl types or classes this BSON codec
knows how to serialize to BSON.  The middle column is the BSON type for
each class.  The right-most column is the Perl type or class that the BSON
type deserializes to.  Footnotes indicate variations or special behaviors.

    Perl type/class ->          BSON type        -> Perl type/class
    -------------------------------------------------------------------
    float[1]                    0x01 DOUBLE         float[2]
    BSON::Double
    -------------------------------------------------------------------
    string[3]                   0x02 UTF8           string[2]
    BSON::String
    -------------------------------------------------------------------
    hashref                     0x03 DOCUMENT       hashref[4][5]
    BSON::Doc
    BSON::Raw
    MongoDB::BSON::Raw[d]
    Tie::IxHash
    Hash::Ordered
    -------------------------------------------------------------------
    arrayref                    0x04 ARRAY          arrayref
    -------------------------------------------------------------------
    BSON::Bytes                 0x05 BINARY         BSON::Bytes
    scalarref
    BSON::Binary[d]
    MongoDB::BSON::Binary[d]
    -------------------------------------------------------------------
    n/a                         0x06 UNDEFINED[d]   undef
    -------------------------------------------------------------------
    BSON::OID                   0x07 OID            BSON::OID
    BSON::ObjectId[d]
    MongoDB::OID[d]
    -------------------------------------------------------------------
    boolean                     0x08 BOOL           boolean
    BSON::Bool[d]
    JSON::XS::Boolean
    JSON::PP::Boolean
    JSON::Tiny::_Bool
    Mojo::JSON::_Bool
    Cpanel::JSON::XS::Boolean
    Types::Serialiser::Boolean
    -------------------------------------------------------------------
    BSON::Time                  0x09 DATE_TIME      BSON::Time
    DateTime
    DateTime::Tiny
    Time::Moment
    Mango::BSON::Time
    -------------------------------------------------------------------
    undef                       0x0a NULL           undef
    -------------------------------------------------------------------
    BSON::Regex                 0x0b REGEX          BSON::Regex
    qr// reference
    MongoDB::BSON::Regexp[d]
    -------------------------------------------------------------------
    n/a                         0x0c DBPOINTER[d]   BSON::DBRef
    -------------------------------------------------------------------
    BSON::Code[6]               0x0d CODE           BSON::Code
    MongoDB::Code[6]
    -------------------------------------------------------------------
    n/a                         0x0e SYMBOL[d]      string
    -------------------------------------------------------------------
    BSON::Code[6]               0x0f CODEWSCOPE     BSON::Code
    MongoDB::Code[6]
    -------------------------------------------------------------------
    integer[7][8]               0x10 INT32          integer[2]
    BSON::Int32
    -------------------------------------------------------------------
    BSON::Timestamp             0x11 TIMESTAMP      BSON::Timestamp
    MongoDB::Timestamp[d]
    -------------------------------------------------------------------
    integer[7]                  0x12 INT64          integer[2][9]
    BSON::Int64
    Math::BigInt
    Math::Int64
    -------------------------------------------------------------------
    BSON::MaxKey                0x7F MAXKEY         BSON::MaxKey
    MongoDB::MaxKey[d]
    -------------------------------------------------------------------
    BSON::MinKey                0xFF MINKEY         BSON::MinKey
    MongoDB::MinKey[d]

    [d] Deprecated or soon to be deprecated.
    [1] Scalar with "NV" internal representation no "PV"
        representation, or a string that looks like a float if the
        'prefer_numeric' option is true.
    [2] If the 'wrap_numbers' option is true, numeric types will be wrapped
        as BSON::Double, BSON::Int32 or BSON::Int64 as appropriate to ensure
        round-tripping. If the 'wrap_strings' option is true, strings will
        be wrapped as BSON::String, likewise.
    [3] Scalar with "PV" representation and not identified as a number
        by notes [1] or [7].
    [4] If 'ordered' option is set, will return a tied hash that preserves
        order (deprecated 'ixhash' option still works).
    [5] If the document appears to contain a DBRef and a 'dbref_callback'
        exists, that callback is executed with the deserialized document.
    [6] Code is serialized as CODE or CODEWSCOPE depending on whether a
        scope hashref exists in BSON::Code/MongoDB::Code.
    [7] Scalar with "IV" internal representation and no "PV"
        representation, or a string that looks like an integer if the
        'prefer_numeric' option is true.
    [8] Only if the integer fits in 32 bits.
    [9] On 32-bit platforms, 64-bit integers are deserialized to
        Math::BigInt objects (even if subsequently wrapped into
        BSON::Int64 if 'wrap_scalars' is true).

=head1 THREADS

Threads are never recommended in Perl, but this module is thread safe for
Perl 5.8.5 or later.  Threads are not supported on older Perls.

=head1 ENVIRONMENT

=for :list
* PERL_BSON_BACKEND – if set at compile time, this will be treated
  as a module name.  The module will be loaded and used as the BSON
  backend implementation.  It must implement the same API as
  C<BSON::PP>.

=head1 SEMANTIC VERSIONING SCHEME

Starting with BSON C<v0.999.0>, this module is using a "tick-tock"
three-part version-tuple numbering scheme: C<vX.Y.Z>

=for :list
* In stable releases, C<X> will be incremented for incompatible API
  changes.
* Even-value increments of C<Y> indicate stable releases with new
  functionality.  C<Z> will be incremented for bug fixes.
* Odd-value increments of C<Y> indicate unstable ("development") releases
  that should not be used in production.  C<Z> increments have no semantic
  meaning; they indicate only successive development releases.  Development
  releases may have API-breaking changes, usually indicated by C<Y> equal
  to "999".

=head1 HISTORY AND ROADMAP

This module was originally written by Stefan G.  In 2014, he graciously
transferred ongoing maintenance to MongoDB, Inc.

The C<bson_xxxx> helper functions in L<BSON::Types> were inspired by similar
work in L<Mango::BSON> by Sebastian Riedel.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
