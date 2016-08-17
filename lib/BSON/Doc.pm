use 5.008001;
use strict;
use warnings;

package BSON::Doc;
# ABSTRACT: BSON type wrapper for ordered documents

use version;
our $VERSION = 'v1.2.1';

use Carp qw/croak/;
use Tie::IxHash;

sub new {
    my ( $class, @args ) = @_;

    croak "BSON::Doc::new requires key/value pairs"
        if @args % 2 != 0;

    my $key_count =()= keys %{{@args}};
    croak "Duplicate keys not allowed in BSON::Doc"
        if $key_count * 2 != @args;

    return bless \@args, $class;
}

sub _as_tied_hash {
    my $self = shift;
    tie my %h, 'Tie::IxHash', @$self;
    return \%h;
}

sub _iterator {
    my $self = shift;
    my $index = 0;
    return sub {
        return if $index > $#{$self};
        my ($k,$v) = @{$self}[$index, $index+1];
        $index += 2;
        return ($k,$v);
    }
}

1;

__END__

=for Pod::Coverage new

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $ordered = bson_doc( first => 1, second => 2 );

=head1 DESCRIPTION

This module provides a BSON type wrapper representing a document preserves
key-value order.  It is currently read-only.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
