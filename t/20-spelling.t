#!/usr/bin/perl

use Test::More;

BEGIN {
    plan skip_all => "Spelling tests only for authors"
        unless -e '.author'
}

use Test::Spelling;
set_spell_cmd('aspell list -l en');
add_stopwords(<DATA>);
all_pod_files_spelling_ok('lib');

__END__
Github
GitHub
MongoDB
MongoDB's
deserialization
ixhash
unordered
Timestamp
timestamp
minimalist
minimalistic
BSON
BSON's
OOP
MinKey
MaxKey
ObjectId
sharding
Kostyuk
Oleg
