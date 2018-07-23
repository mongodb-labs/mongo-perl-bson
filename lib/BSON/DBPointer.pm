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
        return { '$dbPointer' => {
            '$ref' => $self->ref,
            '$id'  => { '$oid' => $self->id },
            ( defined($self->db) ? ( '$db' => $self->db ) : () ),
            %{ $self->extra },
        } };
    }

    Carp::croak( "The value '$self' is illegal in JSON" );
}

1;
