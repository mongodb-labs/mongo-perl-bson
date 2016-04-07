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
