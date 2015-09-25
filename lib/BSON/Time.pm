use 5.008001;
use strict;
use warnings;

package BSON::Time;
# ABSTRACT: Date and time data for BSON

our $VERSION = '0.17';

use Carp;

use overload
  '==' => \&op_eq,
  'eq' => \&op_eq,
  '""' => sub { $_[0]->epoch };

sub new {
    my ( $class, $value ) = @_;
    my $self = bless {}, $class;
    $self->value( defined $value ? $value : time );
    return $self;
}

sub value {
    my ( $self, $value ) = @_;
    if ( defined $value ) {
        confess '$value must be an epoch integer'
          unless $value =~ /^-?\d+$/;
        $self->{value} = $value * 1000;
    }
    return $self->{value};
}

sub epoch {
    return int( $_[0]->value / 1000 );
}

sub op_eq {
    return ref( $_[0] ) eq ref( $_[1] ) && $_[0]->value == $_[1]->value;
}

1;

__END__

=for Pod::Coverage op_eq

=head1 SYNOPSIS

    use BSON;

    my $dt = BSON::Time->new( $epoch );

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's date element.

=head1 METHODS

=head2 new

Object constructor. Optional parameter specifies an epoch date.
If no parameters are passed it will use the current C<time>.

    my $t = BSON::Time->new;    # Time now
    my $d = BSON::Time->new(123456789);

=head2 value

Returns the stored time in milliseconds since the Epoch. 
To convert to seconds, divide by 1000.

=head2 epoch

Returns the stored time in seconds since the Epoch. 

=head1 SEE ALSO

L<BSON>

=cut
