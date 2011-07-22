package BSON::ObjectId;

use strict;
use warnings;
use Carp;
use Sys::Hostname;
use Digest::MD5 'md5';

use overload
  '""' => \&to_s,
  '==' => \&op_eq,
  'eq' => \&op_eq;

my $_inc : shared = 0;

sub new {
    my ( $class, $value ) = @_;
    my $self = bless {}, $class;
    $self->value( $value || _generate() );
    return $self;
}

sub value {
    my ( $self, $new_value ) = @_;
    if ( defined $new_value ) {
        if ( length($new_value) == 12 ) {
            $self->{value} = $new_value;
        }
        elsif ( length($new_value) == 24 && $self->is_legal($new_value) ) {
            $self->{value} = _from_s($new_value);
        }
        else {
            croak("BSON::ObjectId must be a 24 char hex value");
        }
    }
    return $self->{value};
}

sub is_legal {
    $_[1] =~ /^[0-9a-f]{24}$/i;
}

sub to_s {
    my $self = shift;
    return unpack( 'H*', $self->value );
}

sub op_eq {
    my ( $self, $other ) = @_;
    return ref($self) eq ref($other) && $self->value eq $other->value;
}

sub _generate {
    my $self = shift;
    my $time = pack( 'N', shift || time );
    my $host = substr( md5(hostname), 0, 3 );
    my $proc = pack( 'n', $$ % 0xFFFF );
    my $inc  = substr( pack( 'N', $_inc++ % 0xFFFFFF ), 1, 3 );
    return $time . $host . $proc . $inc;
}

sub _from_s {
    my @a = split( //, shift );
    my $oid = '';
    while ( my ( $x, $y ) = splice( @a, 0, 2 ) ) {
        $oid .= pack( 'C', hex("$x$y") );
    }
    return $oid;
}

1;

__END__

=head1 NAME

BSON::ObjectId - ObjectId data element for BSON

=head1 SYNOPSIS

    use BSON;

    my $oid  = BSON::ObjectId->new;
    my $oid2 = BSON::ObjectId->new($string);
    my $oid3 = BSON::ObjectId->new($binary_string);

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's ObjectId element.

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
the 24-character value of the ObjectId.

=head1 THREADS

This module is thread safe.

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
