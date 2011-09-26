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
        'Tie::IxHash' => 0,
        'Test::More'  => 0,
        'Carp'        => 0
    },
    BUILD_REQUIRES => {
        'DateTime' => 0
    },
    MIN_PERL_VERSION    => '5.008',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'BSON-*' },
);
