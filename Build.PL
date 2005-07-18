use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'DBIx::AsForm',
    license             => 'perl',
    dist_author         => 'Mark Stosberg <mark@summersault.com>',
    dist_version_from   => 'lib/DBIx/AsForm.pm',
    create_makefile_pl  => 'traditional',
    create_readme       => 1,
    requires => {
        'Test::More'       => 0,
        'Params::Validate' => 0.74,
        'HTML::Element'    => 0,
    },
    add_to_cleanup      => [ 'DBIx-AsForm-*' ],
);

$builder->create_build_script();
