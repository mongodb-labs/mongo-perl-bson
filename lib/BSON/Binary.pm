package BSON::Binary;

use strict;
use warnings;

use overload '""' => \&to_s;

our $TYPE_SIMPLE       = 0x00;
our $TYPE_BYTES        = 0x02;
our $TYPE_UUID         = 0x03;
our $TYPE_MD5          = 0x05;
our $TYPE_USER_DEFINED = 0x80;

sub new {
    my ( $class, $data, $type ) = @_;
    $type ||= $TYPE_SIMPLE;
    my $self = bless { type => $type }, $class;
    $self->data($data);
    return $self;
}

sub data {
    my ( $self, $data ) = @_;
    if ( defined $data ) {
        $data = [ unpack( 'C*', $data ) ] unless ref $data eq 'ARRAY';
        $self->{data} = $data;
    }
    return $self->{data};
}

sub type {
    return $_[0]->{type};
}

sub to_s {
    my $self = shift;
    my @data = @{ $self->data };
    return pack( 'lC*', scalar(@data), $self->type, @data );
}

1;

__END__

=head1 NAME

BSON::Binary - Binary data for BSON

=head1 SYNOPSIS

    use BSON;

    my $bin = BSON::Binary->new([1,2,3,4,5,0x67,0x89], 0);

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's binary element.

=head1 METHODS

=head2 new

Main constructor which takes two parameters: An array reference with 
binary data and a data type. A string may also be passed as the first parameter, 
in which case it will be converted to an array ref.

    my $bin = BSON::Binary->new("classic\x20string\0", 0);

The different types are described in the BSON specification. A type is
one of the follwoing:

    0x00  Binary / Generic
    0x01  Function
    0x02  Binary (Old)
    0x03  UUID
    0x05  MD5
    0x80  User defined

=head2 data

Returns an array reference to the contents of the binary data.

=head2 type

Returns the type of the binary data per the BSON specification.

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
