use 5.008001;
use strict;
use warnings;

package BSON;
# ABSTRACT: Pure Perl implementation of MongoDB's BSON serialization

use base 'Exporter';
our @EXPORT_OK = qw/encode decode/;

our $VERSION = '0.16'; # TRIAL

use Carp;
use Tie::IxHash;
use Math::Int64 qw/:native_if_available int64 int64_to_native native_to_int64/;

use BSON::Time;
use BSON::Timestamp;
use BSON::MinKey;
use BSON::MaxKey;
use BSON::Binary;
use BSON::ObjectId;
use BSON::Code;
use BSON::Bool;
use BSON::String;

# Maximum size of a BSON record
our $MAX_SIZE = 16 * 1024 * 1024;

# Max integer sizes
our $min_int_32 = -(1<<31);
our $max_int_32 =  (1<<31) - 1;
our $min_int_64 = -(int64(1)<<63);
our $max_int_64 =  (int64(1)<<63) - 1;

#<<<
my $int_re     = qr/^(?:(?:[+-]?)(?:[0123456789]+))$/;
my $doub_re    = qr/^(?:(?i)(?:[+-]?)(?:(?=[0123456789]|[.])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))$/;
#>>>

use constant {

    BSON_TYPE_NAME => "CZ*",
    BSON_DOUBLE => "d",
    BSON_STRING => "V/Z*",
    BSON_BOOLEAN => "C",
    BSON_REGEX => "Z*a*",
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
    $value =~ s/^\(\?\^?//;
    $value =~ s/\)$//;
    my ( $opt, $re ) = split( /:/, $value, 2 );
    $opt =~ s/\-\w+$//;
    return ( $re, $opt );
}

sub encode {
    my $doc = shift;

    my $bson = '';
    while ( my ( $key, $value ) = each %$doc ) {

        # Null
        if ( !defined $value ) {
            $bson .= pack( BSON_TYPE_NAME, 0x0A, $key );
        }

        # Array
        elsif ( ref $value eq 'ARRAY' ) {
            my $i = 0;
            tie( my %h, 'Tie::IxHash' );
            %h = map { $i++ => $_ } @$value;
            $bson .= pack( BSON_TYPE_NAME, 0x04, $key ) . encode( \%h );
        }

        # Document
        elsif ( ref $value eq 'HASH' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x03, $key ) . encode($value);
        }

        # Regex
        elsif ( ref $value eq 'Regexp' ) {
            my ( $re, $opt ) = _split_re($value);
            $bson .= pack( BSON_TYPE_NAME.BSON_REGEX, 0x0B, $key, $re, sort grep /^(i|m|x|l|s|u)$/, split( //, $opt ) ) . "\0";
        }

        # ObjectId
        elsif ( ref $value eq 'BSON::ObjectId' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_OBJECTID, 0x07, $key, $value->value );
        }

        # Datetime
        elsif ( ref $value eq 'BSON::Time' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x09, $key ) . int64_to_native( $value->value );
        }

        # Timestamp
        elsif ( ref $value eq 'BSON::Timestamp' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_TIMESTAMP, 0x11, $key, $value->increment, $value->seconds );
        }

        # MinKey
        elsif ( ref $value eq 'BSON::MinKey' ) {
            $bson .= pack( BSON_TYPE_NAME, 0xFF, $key );
        }

        # MaxKey
        elsif ( ref $value eq 'BSON::MaxKey' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x7F, $key );
        }

        # Binary
        elsif ( ref $value eq 'BSON::Binary' ) {
            $bson .= pack( BSON_TYPE_NAME, 0x05, $key ) . $value;
        }

        # Code
        elsif ( ref $value eq 'BSON::Code' ) {
            if ( ref $value->scope eq 'HASH' ) {
                my $scope = encode( $value->scope );
                my $code  = pack( BSON_STRING, $value->code );
                $bson .= 
                    pack( BSON_TYPE_NAME.BSON_CODE_W_SCOPE, 0x0F, $key, (4 + length($scope) + length($code)) ) . $code . $scope;
            }
            else {
                $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x0D, $key, $value->code );
            }
        }

        # Boolean
        elsif ( ref $value eq 'BSON::Bool' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_BOOLEAN, 0x08, $key, ( $value ? 1 : 0 ) );
        }

        # String (explicit)
        elsif ( ref $value eq 'BSON::String' ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x02, $key, $value );
        }

        # Int (32 and 64)
        elsif ( ref $value eq 'Math::Int64' || $value =~ $int_re ) {
            if ( $value > $max_int_64 || $value < $min_int_64 ) {
                croak("MongoDB can only handle 8-byte integers. Key '$key' is '$value'");
            }
            $bson .= $value > $max_int_32 || $value < $min_int_32 ? pack( BSON_TYPE_NAME.BSON_REMAINING, 0x12, $key, int64_to_native( $value ))
                                                                  : pack( BSON_TYPE_NAME.BSON_INT32, 0x10, $key, $value );
        }

        # Double
        elsif ( $value =~ $doub_re ) {
            $bson .= pack( BSON_TYPE_NAME.BSON_DOUBLE, 0x01, $key, $value );
        }

        # String
        else {
            $bson .= pack( BSON_TYPE_NAME.BSON_STRING, 0x02, $key, $value );
        }
    }

    return pack( BSON_INT32, length($bson) + 5 ) . $bson . "\0";
}

sub decode {
    my $bson = shift;
    my $len = unpack( BSON_INT32, $bson );
    if ( length($bson) != $len ) {
        croak("Incorrect length of the bson string");
    }
    my %opt = @_;
    $bson = substr( $bson, 4, -1 );
    my %hash = ();
    tie( %hash, 'Tie::IxHash' ) if $opt{ixhash};
    while ($bson) {
        my $value;
        ( my $type, my $key, $bson ) = unpack( BSON_TYPE_NAME.BSON_REMAINING, $bson );

        # Double
        if ( $type == 0x01 ) {
            ( $value, $bson ) = unpack( BSON_DOUBLE.BSON_REMAINING, $bson );
        }

        # String and Symbol
        elsif ( $type == 0x02 || $type == 0x0E ) {
            ( $value, $bson ) = unpack( BSON_SKIP_4_BYTES.BSON_CSTRING.BSON_REMAINING, $bson );
        }

        # Document and Array
        elsif ( $type == 0x03 || $type == 0x04 ) {
            my $len = unpack( BSON_INT32, $bson );
            $value = decode( substr( $bson, 0, $len ), %opt );
            if ( $type == 0x04 ) {
                my @a =
                  map { $value->{$_} } ( 0 .. scalar( keys %$value ) - 1 );
                $value = \@a;
            }
            $bson = substr( $bson, $len, length($bson) - $len );
        }

        # Binary
        elsif ( $type == 0x05 ) {
            my $len = unpack( BSON_INT32, $bson ) + 5;
            my @a = unpack( BSON_SKIP_4_BYTES.BSON_BINARY_TYPE.BSON_REMAINING, substr( $bson, 0, $len ) );
            $value = BSON::Binary->new( $a[1], $a[0] );
            $bson = substr( $bson, $len, length($bson) - $len );
        }

        # Undef
        elsif ( $type == 0x06 ) {
            $value = undef;
        }

        # ObjectId
        elsif ( $type == 0x07 ) {
            ( my $oid, $bson ) = unpack( BSON_OBJECTID.BSON_REMAINING, $bson );
            $value = BSON::ObjectId->new($oid);
        }

        # Boolean
        elsif ( $type == 0x08 ) {
            ( my $bool, $bson ) = unpack( BSON_BOOLEAN.BSON_REMAINING, $bson );
            $value = BSON::Bool->new($bool);
        }

        # Datetime
        elsif ( $type == 0x09 ) {
            my ($l1, $l2) = @_;
            ($l1, $l2, $bson) = unpack(BSON_INT64.BSON_REMAINING,$bson);
            my $dt = native_to_int64(pack(BSON_INT64,$l1, $l2));
            $value = BSON::Time->new( int( $dt / 1000 ) );
        }

        # Null
        elsif ( $type == 0x0A ) {
            $value = undef;
        }

        # Regex
        elsif ( $type == 0x0B ) {
            ( my $re, my $op, $bson ) = unpack( BSON_CSTRING.BSON_CSTRING.BSON_REMAINING, $bson );
            $value = eval "qr/$re/$op"; ## no critic
        }

        # Code
        elsif ( $type == 0x0D ) {
            ( my $len, my $code, $bson ) = unpack( BSON_INT32.BSON_CSTRING.BSON_REMAINING, $bson );
            $value = BSON::Code->new($code);
        }

        # Code with scope
        elsif ( $type == 0x0F ) {
            my $len = unpack( BSON_INT32, $bson );
            my @a = unpack( BSON_SKIP_4_BYTES.BSON_SKIP_4_BYTES.BSON_CSTRING.BSON_REMAINING, substr( $bson, 0, $len ) );
            $value = BSON::Code->new( $a[0], decode( $a[1], %opt ) );
            $bson = substr( $bson, $len, length($bson) - $len );
        }

        # Int32
        elsif ( $type == 0x10 ) {
            ( $value, $bson ) = unpack( BSON_INT32.BSON_REMAINING, $bson );
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

        $hash{$key} = $value;
    }
    return \%hash;
}

1;

__END__

=head1 SYNOPSIS

    use BSON qw/encode decode/;

    my $document = {
        _id      => BSON::ObjectId->new,
        date     => BSON::Time->new,
        name     => 'James Bond',
        age      => 45,
        amount   => 24587.45,
        badass   => BSON::Bool->true,
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
