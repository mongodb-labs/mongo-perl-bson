#!/usr/bin/perl

use Test::More;

BEGIN {
    plan skip_all => "Manifest tests only for authors"
        unless -e '.author'
}

use Test::CheckManifest;
ok_manifest({ filter => [qr/\.(git|author)/, qr/ignore\.txt/] });
done_testing();
