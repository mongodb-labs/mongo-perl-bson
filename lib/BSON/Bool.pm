package BSON::Bool;

use strict;
use warnings;

use overload
  bool => \&value,
  '==' => \&op_eq,
  'eq' => \&op_eq;

sub new {
    my ( $class, $bool ) = @_;
    bless { value => $bool ? 1 : 0 }, $class;
}

sub value {
    $_[0]->{value} ? 1 : 0;
}

sub true {
    return $_[0]->new(1);
}

sub false {
    return $_[0]->new(0);
}

sub op_eq {
    return ref( $_[0] ) eq ref( $_[1] ) && $_[0]->value == $_[1]->value;
}

1;

__END__

=head1 NAME

BSON::Bool - Boolean data for BSON

=head1 SYNOPSIS

    use BSON;

    my $true  = BSON::Bool->true;
    my $false = BSON::Bool->false;
    my $odd   = BSON::Bool->new( time % 2 )

    print "Odd times!" if $odd;

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's boolean element.

=head1 METHODS

=head2 new

Main constructor which takes a single parameter. Zero or C<undef> create
a C<false> instance, and everything else creates a C<true> instance.

    my $true  = BSON::Bool->new(255);
    my $false = BSON::Bool->new;

=head2 true

As a secondary constructor it returns a C<true> instance.

=head2 false

As a secondary constructor it returns a C<false> instance.

=head2 value

Returns C<0> or C<1> for C<false> and C<true>.

=head1 OVERLOAD

All boolean operations are overloaded, so the class instance can
be used as a boolean variable itself.

    if ( BSON::Bool->true ) {
        print "You kick ass!";
    }

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
