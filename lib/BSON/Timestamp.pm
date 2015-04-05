use 5.008001;
use strict;
use warnings;

package BSON::Timestamp;
# ABSTRACT: Timestamp data for BSON

our $VERSION = '0.12';

sub new {
    my ( $class, $seconds, $increment ) = @_;
    bless {
        seconds   => $seconds,
        increment => $increment
    }, $class;
}

sub increment {
    my ( $self, $value ) = @_;
    $self->{increment} = $value if defined $value;
    return $self->{increment};
}

sub seconds {
    my ( $self, $value ) = @_;
    $self->{seconds} = $value if defined $value;
    return $self->{seconds};
}

1;

__END__

=head1 SYNOPSIS

    use BSON;

    my $ts = BSON::Timestamp->new( $seconds, $increment );

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's timestamp element.
C<Timestamp> is an internal MongoDB type used in replication and sharding.
The first four bytes are increment and the second four bytes are a timestamp.
A timestamp value of 0 has special semantics.

=head1 METHODS

=head2 new

Object constructor takes seconds and increment parameters.

=head2 seconds

Returns the value of C<seconds>

=head2 increment

Returns the value of C<increment>

=head1 SEE ALSO

L<BSON>

=cut
