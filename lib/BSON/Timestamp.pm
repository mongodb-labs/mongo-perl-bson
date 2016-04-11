use 5.008001;
use strict;
use warnings;

package BSON::Timestamp;
# ABSTRACT: Timestamp data for BSON

our $VERSION = '0.17';

use Carp ();

use Class::Tiny qw/seconds increment/;

# Support back-compat 'secs' and inc' and legacy constructor shortcut
sub BUILDARGS {
    my ($class) = shift;

    my %args;
    if ( @_ && $_[0] !~ /^[s|i]/ ) {
        $args{seconds}   = $_[0];
        $args{increment} = $_[1];
    }
    else {
        Carp::croak( __PACKAGE__ . "::new called with an odd number of elements\n" )
          unless @_ % 2 == 0;

        %args = @_;
        $args{seconds}   = $args{secs} if exists $args{secs} && !exists $args{seconds};
        $args{increment} = $args{inc}  if exists $args{inc}  && !exists $args{increment};
    }

    $args{seconds}   = time unless defined $args{seconds};
    $args{increment} = 0    unless defined $args{increment};
    $args{$_} = int( $args{$_} ) for qw/seconds increment/;

    return \%args;
}

BEGIN {
    *sec = \&seconds;
    *inc = \&increment;
}

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$timestamp" : { "t":<seconds>, "i":<increment> }}

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    if ( $ENV{BSON_EXTJSON} ) {
        return { '$timestamp' => { t => $_[0]->{seconds}, i => $_[0]->{increment} } };
    }

    Carp::croak( "The value '$_[0]' is illegal in JSON" );
}


1;

__END__

=head1 SYNOPSIS

    use BSON;

    my $ts = BSON::Timestamp->new(
        seconds   => $seconds,
        increment => $increment,
    );

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's timestamp element.
C<Timestamp> is an internal MongoDB type used in replication and sharding.
The first four bytes are increment and the second four bytes are a timestamp.
A timestamp value of 0 has special semantics.

=head1 METHODS

=head2 seconds

Returns the value of C<seconds>

=head2 increment

Returns the value of C<increment>

=head1 SEE ALSO

L<BSON>

=cut
