use 5.010001;
use strict;
use warnings;

package BSON::Code;
# ABSTRACT: BSON type wrapper for Javascript code

use version;
our $VERSION = 'v1.6.8';

use Carp ();
use Tie::IxHash;

use Moo;

=attr code

A string containing Javascript code. Defaults to the empty string.

=attr scope

An optional hash reference containing variables in the scope of C<code>.
Defaults to C<undef>.

=cut

has [ qw/code scope/ ] => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

=method length

Returns the length of the C<code> attribute.

=cut

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
    {"$code" : "<code>", "$scope" : { ... } }

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    require BSON;
    if ( $ENV{BSON_EXTJSON} ) {
        my %data;
        tie( %data, 'Tie::IxHash' );
        $data{'$code'} = $_[0]->{code};
        $data{'$scope'} = BSON->perl_to_extjson($_[0]->{scope})
            if defined $_[0]->{scope};
        return \%data;
    }

    Carp::croak( "The value '$_[0]' is illegal in JSON" );
}

1;

__END__

=for Pod::Coverage BUILD BUILDARGS

=head1 SYNOPSIS

    use BSON::Types ':all';

    $code = bson_code( $javascript );
    $code = bson_code( $javascript, $scope );

=head1 DESCRIPTION

This module provides a BSON type wrapper for the "Javascript code" type 
and the "Javascript with Scope" BSON types.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
