use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.17;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Pure Perl implementation of MongoDB's BSON serialization",
  "AUTHOR" => "minimalist <minimalist\@lavabit.com>, David Golden <david\@mongodb.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "BSON",
  "LICENSE" => "apache",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "BSON",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Digest::MD5" => 0,
    "Exporter" => 0,
    "Math::Int64" => 0,
    "Sys::Hostname" => 0,
    "Tie::IxHash" => 0,
    "base" => 0,
    "constant" => 0,
    "overload" => 0,
    "strict" => 0,
    "threads::shared" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "DateTime" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::Deep" => 0,
    "Test::More" => "0.86",
    "Test::Number::Delta" => 0,
    "if" => 0
  },
  "VERSION" => "0.17",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "DateTime" => 0,
  "Digest::MD5" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Math::Int64" => 0,
  "Sys::Hostname" => 0,
  "Test::Deep" => 0,
  "Test::More" => "0.86",
  "Test::Number::Delta" => 0,
  "Tie::IxHash" => 0,
  "base" => 0,
  "constant" => 0,
  "if" => 0,
  "overload" => 0,
  "strict" => 0,
  "threads::shared" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
