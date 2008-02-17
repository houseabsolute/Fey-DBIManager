use strict;
use warnings;

use Test::More;

use Fey::Test::SQLite;
use Fey::DBIManager::Source;

plan tests => 1;


my $source = Fey::DBIManager::Source->new( dsn => Fey::Test::SQLite->dsn(),
                                           dbh => Fey::Test::SQLite->dbh(),
                                         );

ok( ! $source->allows_nested_transactions(),
    'source allows nested transactions is false with SQLite' );

