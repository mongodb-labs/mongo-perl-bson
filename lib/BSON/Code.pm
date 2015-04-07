use 5.008001;
use strict;
use warnings;

package BSON::Code;
# ABSTRACT: JavaScript code data for BSON

our $VERSION = '0.14'; # TRIAL

sub new {
    my ( $class, $code, $scope ) = @_;
    bless { code => $code, scope => $scope }, $class;
}

sub code {
    $_[0]->{code};
}

sub scope {
    $_[0]->{scope};
}

sub length {
    length( $_[0]->code );
}

1;

__END__

=head1 SYNOPSIS

    use BSON;

    my $code = BSON::Code->new(q[
        function be_weird(a) {
            if ( a > 20 ) {
                alert("It's too big!")
            }
            return function(b){
                alert(b)
            }
        }
    ]);

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's code element.

=head1 METHODS

=head2 new

Main constructor which takes two parameters: A string with JavaScript code
and an optional hashref with scope. 

    my $code = BSON::Code->new($js_code, { a => 6, b => 14 });

=head2 code

Returns the JavaScript code.

=head2 scope

Returns the scope hashref.

=head2 length

Returns the length of the JavaScript code.

=head1 SEE ALSO

L<BSON>

=cut
