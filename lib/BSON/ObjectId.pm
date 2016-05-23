use 5.008001;
use strict;
use warnings;

package BSON::ObjectId;
# ABSTRACT: Legacy BSON type wrapper for Object IDs (DEPRECATED)

our $VERSION = '0.17';

use Carp;

use BSON::OID;
our @ISA = qw/BSON::OID/;

sub new {
    my ( $class, $value ) = @_;
    my $self = bless {}, $class;
    if ( $value ) {
        $self->value( $value );
    }
    else {
        $self->{oid} = $self->_packed_oid();
    }
    return $self;
}

sub value {
    my ( $self, $new_value ) = @_;
    if ( defined $new_value ) {
        if ( length($new_value) == 12 ) {
            $self->{oid} = $new_value;
        }
        elsif ( length($new_value) == 24 && $self->is_legal($new_value) ) {
            $self->{oid} = pack("H*", $new_value);
        }
        else {
            croak("BSON::ObjectId must be a 12 byte or 24 char hex value");
        }
    }
    return $self->{oid};
}

sub is_legal {
    $_[1] =~ /^[0-9a-f]{24}$/i;
}

sub to_s { $_[0]->to_string }

1;

__END__

=for Pod::Coverage to_s

=head1 DESCRIPTION

This module has been deprecated as it was not compatible with
the official MongoDB BSON implementation on CPAN.

Internally, this is now a thin wrapper around L<BSON::OID>.  The only
difference are:

=for :list
* The C<new> constructor can take a single argument (not a key/value pair),
  either a 12-byte packed OID or a 24-byte hex value
* The C<value> method here returns a 12-byte packed value and may also be
  used as a mutator with either 12-byte packed or 24-byte hex inputs.

You are strongly encouraged to use L<BSON::OID> instead.

=head1 METHODS

=head2 new

Main constructor which takes one optional parameter, a string with ObjectId. 
ObjectId can be either a 24 character hexadecimal value or a 12 character
binary value.

    my $oid  = BSON::ObjectId->new("4e24d6249ccf967313000000");
    my $oid2 = BSON::ObjectId->new("\x4e\x24\xd6\x24\x9c\xcf\x96\x73\x13\0\0\0");

If no ObjectId string is specified, a new one will be generated based on the
machine ID, process ID and the current time.

=head2 value

Returns or sets the ObjectId value.

    $oid->value("4e262c24422ad15e6a000000");
    print $oid->value; # Will print it in binary

=head2 is_legal

Returns true if the 24 character string passed matches an ObjectId.

    if ( BSON::ObjectId->is_legal($id) ) {
        ...
    }

=head1 OVERLOAD

The string operator is overloaded so any string operations will actually use
the 24-character value of the ObjectId. Fallback overloading is enabled.

=head1 THREADS

This module is thread safe.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
