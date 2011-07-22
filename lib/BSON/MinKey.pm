package BSON::MinKey;

use strict;
use warnings;

sub new {
    bless {}, $_[0];
}

1;

__END__

=head1 NAME

BSON::MinKey - MinKey data for BSON

=head1 SYNOPSIS

    use BSON;

    my $key = BSON::MinKey->new;

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's MinKey element.

=head1 METHODS

=head2 new

Object constructor, takes no parameters.

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
