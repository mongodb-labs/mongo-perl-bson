package BSON::Timestamp;

use strict;
use warnings;

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

=head1 NAME

BSON::Timestamp - Timestamp data for BSON

=head1 SYNOPSIS

    use BSON;

    my $ts = BSON::Timestamp->new( $seconds, $increment );

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's timestamp element.

=head1 METHODS

=head2 new

Object constructor takes seconds and increment parameters.

=head2 seconds

Returns the value of C<seconds>

=head2 increment

Returns the value of C<increment>

=head1 SEE ALSO

L<BSON>

=head1 AUTHOR

minimalist, C<< <minimalist at lavabit.com> >>

=head1 BUGS

Bug reports and patches are welcome. Reports which include a failing 
Test::More style test are helpful and will receive priority.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 minimalist.

This program is free software; you can redistribute it and/or modify 
it under the terms as perl itself.

=cut
