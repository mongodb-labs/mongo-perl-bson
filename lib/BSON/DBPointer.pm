use 5.010001;
use strict;
use warnings;

package BSON::DBPointer;

our $VERSION = 'v1.6.8';

use Moo 2.002004;
use Tie::IxHash;
use namespace::clean -except => 'meta';


extends 'BSON::DBRef';

sub TO_JSON {
    my $self = shift;

    if ( $ENV{BSON_EXTJSON} ) {

        my $id = $self->id;
        if (ref $id) {
            $id = $id->TO_JSON;
        }
        else {
            $id = BSON->perl_to_extjson($id);
        }

        my %data;
        tie( %data, 'Tie::IxHash' );
        $data{'$ref'} = $self->ref;
        $data{'$id'} = $id;
        $data{'$db'} = $self->db
            if defined $self->db;

        my $extra = $self->extra;
        $data{$_} = $extra->{$_}
            for keys %$extra;

        return \%data;
    }

    Carp::croak( "The value '$self' is illegal in JSON" );
}

1;
