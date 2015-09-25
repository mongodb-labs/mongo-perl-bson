use 5.008001;
use strict;
use warnings;

package BSON::String;
# ABSTRACT: String data for BSON

our $VERSION = '0.16'; # TRIAL

use overload '""' => \&value;

sub new {
    my ( $class, $value ) = @_;
    bless { value => $value }, $class;
}

sub value {
    return $_[0]->{value};
}

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
