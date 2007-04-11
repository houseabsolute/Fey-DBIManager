use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new
        ( module_name        => 'Fey::DBIManager',
          license            => 'perl',
          requires           => { 'Fey::Core'  => 0,
                                },
          build_requires     => { 'Test::MockObject' => 0,
                                  'Test::More'       => 0,
                                },
          create_makefile_pl => 'passthrough',
          create_readme      => 1,
          sign               => 1,
        );

$builder->create_build_script();
