use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'List::Gen',
    license            => 'perl',
    dist_author        => q{Eric Strom <asg@cpan.org>},
    dist_version_from  => 'lib/List/Gen.pm',
    requires           => {perl => '5.10.0'},
    add_to_cleanup     => ['List-Gen-*'],
    create_makefile_pl => 'traditional',
    meta_merge         => {
        repository => {
            type => 'git',
            url => 'git://github.com/jo-37/list-gen.git',
            web => 'https://github.com/jo-37/list-gen.git',
        }
    },
);

$builder->create_build_script();
