use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new
        ( module_name => 'Fey::DBIManager',
          license     => 'perl',
          requires => { 'Fey'                            => '0.12',
                        'Moose'                          => '0.56',
                        'MooseX::AttributeHelpers'       => '0.13',
                        'MooseX::StrictConstructor'      => '0.07',
                        'MooseX::SemiAffordanceAccessor' => '0.03',
                      },
          build_requires => { 'DBD::Mock'  => '1.38',
                              'Fey::Test'  => '0.04',
                              'Test::More' => '0',
                            },
          create_makefile_pl => 'traditional',
          create_readme      => 1,
          sign               => 1,
          meta_merge =>
              { resources =>
                    { homepage   => 'http://www.fey-project.org/',
                      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Fey-DBIManager',
                      repository => 'http://hg.urth.org/hg/Fey-DBIManager',
                    },
              },
        );

$builder->create_build_script();
