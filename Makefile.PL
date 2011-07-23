use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'BSON',
    AUTHOR              => q{minimalist <minimalist@lavabit.com>},
    VERSION_FROM        => 'lib/BSON.pm',
    ABSTRACT_FROM       => 'lib/BSON.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Tie::IxHash' => 0
    },
    BUILD_REQUIRES => {
        'DateTime' => 0
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'BSON-*' },
);
