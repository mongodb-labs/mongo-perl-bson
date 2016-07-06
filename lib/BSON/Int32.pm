use 5.008001;
use strict;
use warnings;

package BSON::Int32;
# ABSTRACT: BSON type wrapper for Int32

use version;
our $VERSION = 'v1.1.0';

use Carp;
use Moo;

=attr value

A numeric scalar.  It will be coerced to an integer.  The default is 0.

=cut

has 'value' => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

my $max_int32 = 2147483647;
my $min_int32 = -2147483648;

sub BUILD {
    my $self = shift;
    # coerce to IV internally
    $self->{value} = defined( $self->{value} ) ? int( $self->{value} ) : 0;
    if ( $self->{value} > $max_int32 || $self->{value} < $min_int32 ) {
        croak("The value '$self->{value}' can't fit in a signed Int32");
    }
}

=method TO_JSON

Returns the value as an integer.

=cut

# BSON_EXTJSON_FORCE is for testing; not needed for normal operation
sub TO_JSON {
    return int($_[0]->{value});
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

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use BSON::Types ':all';

    bson_int32( $number );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a numeric value that
would be represented in BSON as a 32-bit integer.

If the value won't fit in a 32-bit integer, an error will be thrown.

=head1 OVERLOADING

The numification operator, C<0+> is overloaded to return the C<value>,
the full "minimal set" of overloaded operations is provided (per L<overload>
documentation) and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
