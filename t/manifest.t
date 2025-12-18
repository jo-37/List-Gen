#!perl
use 5.006;
use Test2::V0;
use ExtUtils::Manifest;

SKIP: {
    skip "Author tests not required for installation"
        unless $ENV{RELEASE_TESTING};
    is [ExtUtils::Manifest::manicheck()], [], 'missing';
    is [ExtUtils::Manifest::filecheck()], [], 'extra';
}

done_testing;
