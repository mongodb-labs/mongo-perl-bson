use 5.010001;
use strict;
use warnings;

package BSON::DBPointer;

use Moo 2.002004;
use namespace::clean -except => 'meta';

extends 'BSON::DBRef';

sub TO_JSON {
    my $self = shift;

    if ( $ENV{BSON_EXTJSON} ) {

        my %data;
        tie( %data, 'Tie::IxHash' );
        $data{'$ref'} = $self->ref;
        $data{'$id'} = { '$oid' => $self->id };
        $data{'$db'} = $self->db
            if defined $self->db;

        my $extra = $self->extra;
        $data{$_} = $extra->{$_}
            for keys %$extra;

        return { '$dbPointer' => \%data };
    }

    Carp::croak( "The value '$self' is illegal in JSON" );
}

1;
