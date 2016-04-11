use 5.008001;
use strict;
use warnings;

package BSON::MaxKey;
# ABSTRACT: MaxKey data for BSON

our $VERSION = '0.17';

use Carp;

my $singleton = bless \(my $x), __PACKAGE__;

sub new {
    return $singleton;
}

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$maxKey" : 1}

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    if ( $ENV{BSON_EXTJSON} ) {
        return { '$maxKey' => 1 };
    }

    croak( "The value '$_[0]' is illegal in JSON" );
}

1;

__END__

=head1 SYNOPSIS

    use BSON;

    my $key = BSON::MaxKey->new;

=head1 DESCRIPTION

This module is needed for L<BSON> and it manages BSON's MaxKey element.

=head1 METHODS

=head2 new

Object constructor, takes no parameters.

=head1 SEE ALSO

L<BSON>

=cut
