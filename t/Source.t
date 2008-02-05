use strict;
use warnings;

use Test::More;

BEGIN
{
    unless ( eval { require DBD::Mock; 1 } )
    {
        plan skip_all => 'These tests require DBD::Mock.';
    }
    else
    {
        plan tests => 53;
    }
}

use Fey::DBIManager::Source;


my $DSN = 'dbi:Mock:foo';
my $Username = 'user';
my $Password = 'password';


{
    my $source = Fey::DBIManager::Source->new( dsn => $DSN );

    is( $source->name(), 'default', 'source is named default' );
    is( $source->dsn(), $DSN, 'dsn passed to new() is returned by dsn()' );
    is( $source->username(), '', 'default username is empty string' );
    is( $source->password(), '', 'default password is empty string' );
    is_deeply( $source->attributes(),
               { AutoCommit         => 1,
                 RaiseError         => 1,
                 PrintError         => 0,
                 PrintWarn          => 1,
                 ShowErrorStatement => 1,
               },
               'check default attributes' );
    ok( ! $source->post_connect(), 'no post_connect hook by default' );
    ok( $source->auto_refresh(), 'auto_refresh defaults to true' );
    ok( ! $source->{threaded}, 'threads is false' );

    my $sub = sub {};
    $source = Fey::DBIManager::Source->new( dsn          => $DSN,
                                            username     => $Username,
                                            password     => $Password,
                                            attributes   => { AutoCommit => 0,
                                                              SomeThing  => 1,
                                                            },
                                            post_connect => $sub,
                                            auto_refresh => 0,
                                          );

    is( $source->dsn(), $DSN, 'dsn passed to new() is returned by dsn()' );
    is( $source->username(), $Username, 'username is user' );
    is( $source->password(), $Password, 'password is password' );
    is_deeply( $source->attributes(),
               { AutoCommit         => 1,
                 RaiseError         => 1,
                 PrintError         => 0,
                 PrintWarn          => 1,
                 ShowErrorStatement => 1,
                 SomeThing          => 1,
               },
               'attributes include values passed in, except AutoCommit is 1' );
    is( $source->post_connect(), $sub, 'post_connect is set' );
    ok( ! $source->auto_refresh(), 'auto_refresh  is false' );
}

eval <<'EOF';
{
    package threads;

    $threads::tid = 42;
    sub tid { $threads::tid }
}
EOF

{
    my $source = Fey::DBIManager::Source->new( dsn => $DSN );

    ok( $source->_threaded(), 'threads is true' );
}

{
    my $post_connect = 0;
    my $count = 0;
    my $sub = sub { $post_connect = shift; $count++ };

    my $source = Fey::DBIManager::Source->new( dsn          => $DSN,
                                               username     => $Username,
                                               password     => $Password,
                                               attributes   => { AutoCommit => 0,
                                                               },
                                               post_connect => $sub,
                                             );

    my $dbh = $source->dbh();

    test_dbh( $dbh, $post_connect );

    is( $count, 1, 'one DBI handle made so far' );

    local $$ = $$ + 1;
    $source->_ensure_fresh_dbh();

    ok( $dbh->{InactiveDestroy}, 'InactiveDestroy was set to true' );

    $dbh = $source->dbh();
    test_dbh( $dbh, $post_connect );

    is( $count, 2, 'new handle made when pid changes' );

    $threads::tid++;
    $source->_ensure_fresh_dbh();

    ok( ! $dbh->{InactiveDestroy}, 'InactiveDestroy was not set' );

    $dbh = $source->dbh();
    test_dbh( $dbh, $post_connect );

    is( $count, 3, 'new handle made when tid changes' );

    $source->_ensure_fresh_dbh();
    is( $count, 3, 'no new handle made with same pid & tid' );

    $dbh->{mock_can_connect} = 0;
    $source->_ensure_fresh_dbh();

    is( $count, 4, 'new handle made when Active is false' );

    $dbh = $source->dbh();

    $dbh->{mock_can_connect} = 1;
    no warnings 'redefine';
    local *DBD::Mock::db::ping = sub { return 0 };

    $source->_ensure_fresh_dbh();
    is( $count, 5, 'new handle made when ping returns false' );
}

{
    my $count = 0;
    my $sub = sub { $count++ };

    my $source = Fey::DBIManager::Source->new( dsn          => $DSN,
                                               username     => $Username,
                                               password     => $Password,
                                               attributes   => { AutoCommit => 0,
                                                               },
                                               auto_refresh => 0,
                                               post_connect => $sub,
                                             );

    my $dbh = $source->dbh();

    is( $count, 1, 'one DBI handle made so far' );

    local $$ = $$ + 1;
    $dbh = $source->dbh();

    is( $count, 1, 'no new handle when pid changes' );

    $threads::tid++;
    $dbh = $source->dbh();

    is( $count, 1, 'no new handle when tid changes' );

    $dbh->{mock_can_connect} = 0;
    $dbh = $source->dbh();

    is( $count, 1, 'no new handle made when Active is false' );

    $dbh->{mock_can_connect} = 1;
    no warnings 'redefine';
    local *DBD::Mock::db::ping = sub { return 0 };
    $dbh = $source->dbh();

    is( $count, 1, 'no new handle made when ping returns false' );
}

{
    my $source = Fey::DBIManager::Source->new( dsn => $DSN, name => 'another' );

    is( $source->name(), 'another',
        'explicit name passed to constructor' );
}

sub test_dbh
{
    my $dbh          = shift;
    my $post_connect = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    isa_ok( $dbh, 'DBI::db' );
    is( $dbh->{Name}, 'foo',
        'db name passed to DBI->connect() is same as the one passed to new()' );
    is( $dbh->{Username}, $Username,
        'username passed to DBI->connect() is same as the one passed to new()' );
    is( $post_connect, $dbh,
        'post_connect sub was called with DBI handle as argument' );

    check_attributes($dbh);
}

sub check_attributes
{
    my $dbh = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %expect = ( AutoCommit         => 1,
                   RaiseError         => 1,
                   # DBD::Mock seems to lose this value when it's set after a handle is created (weird!)
#                   PrintError         => 0,
                   PrintWarn          => 1,
                   ShowErrorStatement => 1,
                 );
    for my $k ( sort keys %expect )
    {
        is( $dbh->{$k}, $expect{$k},
            "$k should be $expect{$k}" );
    }
}
