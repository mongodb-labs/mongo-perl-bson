use 5.008001;
use strict;
use warnings;

package BSON::Code;
# ABSTRACT: BSON type wrapper for Javascript code

our $VERSION = '0.17';

use Carp ();

use Class::Tiny qw/code scope/;

sub length {
    length( $_[0]->code );
}

# Support legacy constructor shortcut
sub BUILDARGS {
    my ($class) = shift;

    my %args;
    if ( @_ && $_[0] !~ /^[c|s]/ ) {
        $args{code}   = $_[0];
        $args{scope} = $_[1] if defined $_[1];
    }
    else {
        Carp::croak( __PACKAGE__ . "::new called with an odd number of elements\n" )
          unless @_ % 2 == 0;
        %args = @_;
    }

    return \%args;
}

sub BUILD {
    my ($self) = @_;
    $self->{code} = '' unless defined $self->{code};
    Carp::croak( __PACKAGE__ . " scope must be hash reference, not $self->{scope}")
        if exists($self->{scope}) && ref($self->{scope}) ne 'HASH';
    return;
}

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$code" : "<code>"}
    {"$code" : "<code>", "$scope" : <scope-document> }

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    if ( $ENV{BSON_EXTJSON} ) {
        return {
            '$code' => $_[0]->{code},
            ( defined $_[0]->{scope} ? ( '$scope' => $_[0]->{scope} ) : () ),
        };
    }

    Carp::croak( "The value '$_[0]' is illegal in JSON" );
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
