use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use B;

use base 'Exporter';
our @EXPORT = qw/sv_type/;

sub sv_type {
    my $v = shift;
    my $b_obj = B::svref_2object(\$v);
    my $type = ref($b_obj);
    $type =~ s/^B:://;
    return $type;
}

1;
# COPYRIGHT

# vim: set ts=4 sts=4 sw=4 et tw=75:
