use 5.008001;
use strict;
use warnings;

package BSON::String;
# ABSTRACT: BSON type wrapper for strings

use version;
our $VERSION = 'v1.2.2';

use Moo;

=attr value

A scalar value, which will be stringified during construction.  The default
is the empty string.

=cut

has 'value' => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

sub BUILDARGS {
    my $class = shift;
    my $n     = scalar(@_);

    my %args;
    if ( $n == 0 ) {
        $args{value} = '';
    }
    elsif ( $n == 1 ) {
        $args{value} = shift;
    }
    elsif ( $n % 2 == 0 ) {
        %args = @_;
        $args{value} = '' unless defined $args{value};
    }
    else {
        croak("Invalid number of arguments ($n) to BSON::String::new");
    }

    # normalize all to internal PV type
    $args{value} = "$args{value}";

    return \%args;
}

=method TO_JSON

Returns value as a string.

=cut

sub TO_JSON { return "$_[0]->{value}" }

use overload (
    # Unary
    q{""} => sub { $_[0]->{value} },
    q{0+} => sub { 0+ $_[0]->{value} },
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

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    use BSON::Types ':all';

    bson_string( $string );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a string value.

Since Perl does not distinguish between numbers and strings, this module
provides an explicit string type for a scalar value.

=head1 OVERLOADING

The stringification operator (C<"">) is overloaded to return the C<value>,
the full "minimal set" of overloaded operations is provided (per L<overload>
documentation) and fallback overloading is enabled.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
