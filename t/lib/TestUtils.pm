use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use B;
use Carp qw/croak/;

use base 'Exporter';
our @EXPORT = qw/sv_type packed_is/;

sub sv_type {
    my $v     = shift;
    my $b_obj = B::svref_2object( \$v );
    my $type  = ref($b_obj);
    $type =~ s/^B:://;
    return $type;
}

sub packed_is {
    croak("Not enough args for packed_is()") unless @_ >= 3;
    my ( $template, $got, $exp, $label ) = @_;
    $label = '' unless defined $label;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ok = ok( pack( $template, $got ) eq pack( $template, $exp ), $label );
    diag "Got:\n", unpack( "H*", $got ), "\nExpected:\n", unpack( "H*", $exp )
      unless $ok;

    return $ok;
}

1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
