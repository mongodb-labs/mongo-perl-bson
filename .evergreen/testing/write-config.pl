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
      [ 'ubuntu1604', 'windows64', 'windows32', 'rhel67_z', 'ubuntu1604_arm64', 'ubuntu1604_power8' ] };

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

##    # Build filter to only test threaded, non-ld Perls on ZAP
##    my $variant_filter = sub {
##        my ($os, $ver) = @_;
##        return 0 if $os =~ /(?:_z|_arm64|_power8)$/ && substr($ver,-1,1) ne 't';
##        return 1;
##    };
##

##    print assemble_yaml( timeout(600), buildvariants( \@tasks, $variant_filter ), );
    print assemble_yaml( timeout(600), buildvariants( \@tasks ), );

    return 0;
}

# execution
exit main();
