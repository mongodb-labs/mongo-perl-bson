use 5.008001;
use strict;
use warnings;

package BSON::String;
# ABSTRACT: BSON type wrapper for String

our $VERSION = '0.17';

use Class::Tiny qw/value/;

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

use overload (
    q{""}    => sub { $_[0]->{value} },
    fallback => 1,
);

1;

__END__

=head1 SYNOPSIS

    use BSON 'encode';

    my $str1 = BSON::String->new('Jack Reacher');
    my $str2 = BSON::String->new('55');
    my $str3 = BSON::String->new('-1234.7654');

    my $bson = encode( { a => $str1, b => $str2, c => $str3 } );


=head1 DESCRIPTION

Since Perl does not distinguish between numbers and strings, this module 
is provides an explicit string type for L<BSON>'s string element.
It's very simple and does not implement any operator overloading other 
than C<"">.

=head1 METHODS

=head2 new

Main constructor which takes a single parameter - the string.

    my $string = BSON::String->new('Hello, there!');
    print "$string\n";    # Prints 'Hello, there!'
    if ( "$string" gt "abcde" ) {

        # This will work
        ...;
    }

=head2 value

Returns the value of the string.

=head1 OVERLOAD

Only the C<""> operator is overloaded. You won't be able to perform string
comparison on a BSON::String instance.

=head1 SEE ALSO

L<BSON>

=cut
