use strict;
use warnings;

use Test::More tests => 8;

use Fey::DBIManager;

{
    package Fey::DBIManager::Source;

    sub new
    {
        my $class = shift;

        return bless {@_}, $class;
    }

    sub name { return $_[0]->{name} }
}


{
    my $man = Fey::DBIManager->new();
    isa_ok( $man, 'Fey::DBIManager' );

    is( $man->source_count(), 0, 'manager has no sources' );

    eval { $man->default_source(); };
    like( $@, qr/has no sources at all/,
          'default_source() fails before any sources are added' );

    my $source = Fey::DBIManager::Source->new( name => 'not default' );

    $man->add_source($source);

    is( $man->source_count(), 1, 'manager has one source' );

    eval { $man->add_source($source); };
    like( $@, qr/\Qalready have a source named "not default"/,
          'cannot add the same source twice' );

    is( $man->default_source()->name(), $source->name(),
        'default source is the only source it has' );

    my $source2 = Fey::DBIManager::Source->new( name => 'not default either' );

    $man->add_source($source2);
    eval { $man->default_source() };
    like( $@, qr/has multiple sources/,
          q{no default source with multiple sources, none named "default"} );

    my $source3 = Fey::DBIManager::Source->new( name => 'default' );

    $man->add_source($source3);
    is( $man->default_source()->name(), 'default',
        q{default_source() returns the source named "default"} );
}
