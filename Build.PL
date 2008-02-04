use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new( module_name => 'Fey::DBIManager',
                        license     => 'perl',
                        requires    => { 'MooseX::StrictConstructor'              => 0,
                                         'MooseX::Policy::SemiAffordanceAccessor' => 0,
                                       },
                        build_requires => { 'DBD::Mock'        => 0,
                                            'Test::More'       => 0,
                                          },
                        create_makefile_pl => 'passthrough',
                        create_readme      => 1,
                        sign               => 1,
                      );

$builder->create_build_script();
