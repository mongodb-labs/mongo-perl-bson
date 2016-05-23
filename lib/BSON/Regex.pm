use 5.008001;
use strict;
use warnings;

package BSON::Regex;
# ABSTRACT: BSON type wrapper for regular expressions

our $VERSION = '0.17';

use Carp ();

use Class::Tiny qw/pattern flags/;

=attr pattern

A B<string> containing a PCRE regular expression pattern (not a C<qr> object
and without slashes).  Default is the empty string.

=cut

=attr flags

A string with regular expression flags.  Flags will be sorted and
duplicates will be removed during object construction.  Supported flags
include C<imxlsu>.  Invalid flags will cause an exception.
Default is the empty string;

=cut

my %ALLOWED_FLAGS = map { $_ => 1 } qw/i m x l s u/;

sub BUILD {
    my $self = shift;

    $self->{pattern} = '' unless defined($self->{pattern});
    $self->{flags} = '' unless defined($self->{flags});

    if ( length $self->{flags} ) {
        my %seen;
        my @flags = grep { !$seen{$_}++ } split '', $self->{flags};
        foreach my $f (@flags) {
            Carp::croak("Regex flag $f is not supported")
              if not exists $ALLOWED_FLAGS{$f};
        }

        # sort flags
        $self->{flags} = join '', sort @flags;
    }

}

=method try_compile

    my $qr = $regexp->try_compile;

Tries to compile the C<pattern> and C<flags> into a reference to a regular
expression.  If the pattern or flags can't be compiled, a
exception will be thrown.

B<SECURITY NOTE>: Executing a regular expression can evaluate arbitrary
code if the L<re> 'eval' pragma is in force.  You are strongly advised
to read L<re> and never to use untrusted input with C<try_compile>.

=cut

sub try_compile {
    my ($self) = @_;
    my ( $p, $f ) = @{$self}{qw/pattern flags/};
    my $re = length($f) ? eval { qr/(?$f:$p)/ } : eval { qr/$p/ };
    Carp::croak("error compiling regex 'qr/$p/$f': $@")
      if $@;
    return $re;
}

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://docs.mongodb.org/manual/reference/mongodb-extended-json/>
format, which represents it as a document as follows:

    {"$regex" : "<pattern>", "$options" : "<flags>"}

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    if ( $ENV{BSON_EXTJSON} ) {
        return { '$regex' => $_[0]->{pattern}, '$options' => $_[0]->{flags} };
    }

    Carp::croak( "The value '$_[0]' is illegal in JSON" );
}


1;

__END__

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use BSON::Types ':all';

    $regex = bson_regex( $pattern );
    $regex = bson_regex( $pattern, $flags );

=head1 DESCRIPTION

This module provides a BSON type wrapper for a PCRE regular expression and
optional flags.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
