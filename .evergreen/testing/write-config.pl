#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use utf8;
use open qw/:std :utf8/;

# Get helpers
use FindBin qw($Bin);
use lib "$Bin/../lib";
use EvergreenConfig;

# Limit tasks to certain operating systems
my $OS_FILTER =
  { os =>
      [ 'rhel62', 'windows64', 'suse12_z', 'ubuntu1604_arm64', 'ubuntu1604_power8' ] };

sub main {
    my $download = [ 'downloadPerl5Lib' => { target => '${repo_directory}' } ];

    my @tasks = (
        pre( qw/dynamicVars cleanUp fetchSource/, $download ),
        post(qw/cleanUp/),
        task(
            build  => [qw/whichPerl buildModule uploadBuildArtifacts/],
            filter => $OS_FILTER
        ),
        task(
            test       => [qw/whichPerl downloadBuildArtifacts testModule/],
            depends_on => 'build',
            filter     => $OS_FILTER,
        ),
    );

    print assemble_yaml( timeout(600), buildvariants( \@tasks ), );

    return 0;
}

# execution
exit main();
