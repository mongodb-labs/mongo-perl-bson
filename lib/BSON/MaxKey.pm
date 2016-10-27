use 5.008001;
use strict;
use warnings;

package BSON::MaxKey;
# ABSTRACT: BSON type wrapper for MaxKey

use version;
our $VERSION = 'v1.2.3';

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

=for Pod::Coverage new

=head1 SYNOPSIS

    use BSON::Types ':all';

    bson_maxkey();

=head1 DESCRIPTION

This module provides a BSON type wrapper for the special BSON "MaxKey" type.
The object returned is a singleton.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
