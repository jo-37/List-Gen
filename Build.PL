use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'List::Gen',
    license             => 'perl',
    dist_author         => q{Eric Strom <ejstrom@gmail.com>},
    dist_version_from   => 'lib/List/Gen.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
		'strict'	   => 0,
		'warnings'     => 0,
		'Carp'		   => 0,
		'List::Util'   => 0,
		'Exporter'     => 0,
		'Scalar::Util' => 0,
        'Symbol'       => 0,
        'overload'     => 0,
    },
    add_to_cleanup      => [ 'List-Gen-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
