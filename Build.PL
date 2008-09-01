use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new( module_name => 'Fey::DBIManager',
                        license     => 'perl',
                        requires => { 'Fey'                            => '0.12',
                                      'Moose'                          => '0.56',
                                      'MooseX::AttributeHelpers'       => '0.13',
                                      'MooseX::StrictConstructor'      => '0.07',
                                      'MooseX::SemiAffordanceAccessor' => '0.03',
                                    },
                        build_requires => { 'DBD::Mock'  => '0',
                                            'Fey::Test'  => '0.04',
                                            'Test::More' => '0',
                                          },
                        create_makefile_pl => 'passthrough',
                        create_readme      => 1,
                        sign               => 1,
                      );

$builder->create_build_script();
