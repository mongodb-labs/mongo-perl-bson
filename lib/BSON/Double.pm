use 5.010001;
use strict;
use warnings;

package BSON::Double;
# ABSTRACT: BSON type wrapper for Double

use version;
our $VERSION = 'v1.6.8';

use Carp;

=attr value

A numeric scalar (or the special strings "Inf", "-Inf" or "NaN").  This
will be coerced to Perl's numeric type.  The default is 0.0.

=cut

use Moo;

has 'value' => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

use constant {
    nInf  => unpack("d<",pack("H*","000000000000f0ff")),
    pInf  => unpack("d<",pack("H*","000000000000f07f")),
    NaN   => unpack("d<",pack("H*","000000000000f8ff")),
};

sub BUILD {
    my $self = shift;
    # coerce to NV internally
    $self->{value} = defined( $self->{value} ) ? $self->{value} / 1.0 : 0.0;
}

=method TO_JSON

Returns a double, unless the value is 'Inf', '-Inf' or 'NaN'
(which are illegal in JSON), in which case an exception is thrown.

=cut

my $win32_specials = qr/-?1.\#IN[DF]/i;
my $unix_specials = qr/-?(?:inf|nan)/i;
my $illegal = $^O eq 'MSWin32' && $] lt "5.022" ? qr/^$win32_specials/ : qr/^$unix_specials/;

sub TO_JSON {
    my $copy = "$_[0]->{value}"; # avoid changing value to PVNV

    if ($ENV{BSON_EXTJSON}) {
        my $value = $_[0]->{value}/1.0;
        return { '$numberDouble' => 'Infinity' }
            if $value eq 'Inf';
        return { '$numberDouble' => '-Infinity' }
            if $value eq '-Inf';
        return { '$numberDouble' => 'NaN' }
            if $value eq 'NaN';
        return { '$numberDouble' => sprintf '%.20G', $value/1.0 };
    }

    croak( "The value '$copy' is illegal in JSON" )
        if $copy =~ $illegal;

    return $_[0]->{value}/1.0;
}

use overload (
    # Unary
    q{""} => sub { "$_[0]->{value}" },
    q{0+} => sub { $_[0]->{value} },
    q{~}  => sub { ~( $_[0]->{value} ) },
    # Binary
    ( map { $_ => eval "sub { return \$_[0]->{value} $_ \$_[1] }" } qw( + * ) ), ## no critic
    (
        map {
            $_ => eval ## no critic
              "sub { return \$_[2] ? \$_[1] $_ \$_[0]->{value} : \$_[0]->{value} $_ \$_[1] }"
        } qw( - / % ** << >> x <=> cmp & | ^ )
    ),
    (
        map { $_ => eval "sub { return $_(\$_[0]->{value}) }" } ## no critic
          qw( cos sin exp log sqrt int )
    ),
    q{atan2} => sub {
        return $_[2] ? atan2( $_[1], $_[0]->{value} ) : atan2( $_[0]->{value}, $_[1] );
    },

    # Special
    fallback => 1,
);

1;

__END__

=for Pod::Coverage BUILD nInf pInf NaN

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $bytes = bson_double( $number );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a numeric value that
would be represented in BSON as a double.

=head1 INFINITY AND NAN

Some Perls may not support converting "Inf" or "NaN" strings to their
double equivalent.  They are available as functions from the L<POSIX>
module, but as a lighter alternative to POSIX, the following functions are
available:

=for :list
* BSON::Double::pInf() – positive infinity
* BSON::Double::nInf() – negative infinity
* BSON::Double::NaN() – not-a-number

=head1 OVERLOADING

The numification operator, C<0+> is overloaded to return the C<value>,
the full "minimal set" of overloaded operations is provided (per L<overload>
documentation) and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
