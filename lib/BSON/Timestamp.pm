use 5.008001;
use strict;
use warnings;

package BSON::Timestamp;
# ABSTRACT: BSON type wrapper for timestamps

use version;
our $VERSION = 'v1.2.3';

use Carp ();

use Moo;

=attr seconds

A value representing seconds since the Unix epoch.  The default is
current value of C<time()>.

=attr increment

A numeric value to disambiguate timestamps in the same second.  The
default is 0.

=cut

has [qw/seconds increment/] => (
    is => 'ro'
);

use namespace::clean -except => 'meta';

# Support back-compat 'secs' and inc' and legacy constructor shortcut
sub BUILDARGS {
    my ($class) = shift;

    my %args;
    if ( @_ && $_[0] !~ /^[s|i]/ ) {
        $args{seconds}   = $_[0];
        $args{increment} = $_[1];
    }
    else {
        Carp::croak( __PACKAGE__ . "::new called with an odd number of elements\n" )
          unless @_ % 2 == 0;

        %args = @_;
        $args{seconds}   = $args{secs} if exists $args{secs} && !exists $args{seconds};
        $args{increment} = $args{inc}  if exists $args{inc}  && !exists $args{increment};
    }

    $args{seconds}   = time unless defined $args{seconds};
    $args{increment} = 0    unless defined $args{increment};
    $args{$_} = int( $args{$_} ) for qw/seconds increment/;

    return \%args;
}

# For backwards compatibility
*sec = \&seconds;
*inc = \&increment;

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$timestamp" : { "t":<seconds>, "i":<increment> }}

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    if ( $ENV{BSON_EXTJSON} ) {
        return { '$timestamp' => { t => $_[0]->{seconds}, i => $_[0]->{increment} } };
    }

    Carp::croak( "The value '$_[0]' is illegal in JSON" );
}

1;

__END__

=for Pod::Coverage BUILDARGS sec inc

=head1 SYNOPSIS

    use BSON::Types ':all';

    bson_timestamp( $seconds );
    bson_timestamp( $seconds, $increment );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a BSON timestamp value.

Generally, it should not be used by end-users, but is provided for
backwards compatibility.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
