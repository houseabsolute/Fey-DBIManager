package Fey::DBIManager;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose::Policy 'MooseX::Policy::SemiAffordanceAccessor';
use MooseX::StrictConstructor;

has 'dbh' =>
    ( is        => 'rw',
      isa       => 'DBI::db',
      reader    => '_dbh',
      writer    => '_set_dbh',
      clearer   => '_unset_dbh',
      predicate => '_has_dbh',
      lazy      => 1,
      default   => \&_make_dbh,
    );

has 'name' =>
    ( is      => 'ro',
      isa     => 'Str',
      default => 'main',
    );

has 'dsn' =>
    ( is        => 'ro',
      isa       => 'Str',
      predicate => '_has_dsn',
    );

has 'username' =>
    ( is      => 'ro',
      isa     => 'Str',
      default => '',
    );

has 'password' =>
    ( is      => 'ro',
      isa     => 'Str',
      default => '',
    );

has 'attributes' =>
    ( is      => 'rw',
      isa     => 'HashRef',
      writer  => '_set_attributes',
      default => sub { {} },
    );

has 'post_connect' =>
    ( is  => 'ro',
      isa => 'CodeRef',
    );

has 'auto_refresh' =>
    ( is      => 'ro',
      isa     => 'Bool',
      default => 1,
    );

has '_threaded' =>
    ( is       => 'ro',
      isa      => 'Bool',
      lazy     => 1,
      default  => sub { threads->can('tid') ? 1 : 0 },
      # a hack to make this attribute hard to set via the constructor
      init_arg => "\0_threaded",
    );

has '_pid' =>
    ( is       => 'rw',
      isa      => 'Num',
      # a hack to make this attribute hard to set via the constructor
      init_arg => "\0_pid",
    );

has '_tid' =>
    ( is       => 'rw',
      isa      => 'Num',
      # a hack to make this attribute hard to set via the constructor
      init_arg => "\0_tid",
    );

no Moose;
__PACKAGE__->meta()->make_immutable();

use DBI;
use Fey::Exceptions qw( param_error );
use Fey::Validate
    qw( validate_pos DBI_TYPE );


sub BUILD
{
    my $self   = shift;
    my $params = shift;

    return if $self->_has_dbh();

    param_error 'You must pass a dbh or dsn attribute to the Fey::DBIManager constructor.'
        unless $self->_has_dsn();

    $self->_set_attributes( { %{ $self->attributes() },
                              $self->_required_dbh_attributes(),
                            }
                          );

    return $self;
}

sub _required_dbh_attributes
{
    return ( AutoCommit         => 1,
             RaiseError         => 1,
             PrintError         => 0,
             PrintWarn          => 1,
             ShowErrorStatement => 1,
           );
}

sub dbh
{
    my $self = shift;

    $self->_ensure_fresh_dbh() if $self->auto_refresh();

    return $self->_dbh();
}

{
    my $spec = DBI_TYPE;
    sub set_dbh
    {
        my $self  = shift;
        my ($dbh) = validate_pos( @_, $spec );

        my %attr = $self->_required_dbh_attributes();
        while ( my ( $k, $v ) = each %attr )
        {
            $dbh->{$k} = $v;
        }

        $self->_set_pid_tid();

        $self->_set_dbh($dbh);
    }
}

sub _make_dbh
{
    my $self = shift;

    my $dbh =
        DBI->connect
            ( $self->dsn(), $self->username(),
              $self->password(), $self->attributes() );

    $self->_set_pid_tid();

    if ( my $pc = $self->post_connect() )
    {
        $pc->( $dbh );
    }

    $self->_set_dbh($dbh);

    return $self->_dbh();
}

sub _set_pid_tid
{
    my $self = shift;

    $self->_set_pid($$);
    $self->_set_tid( threads->tid() ) if $self->_threaded();
}

# The logic in this method is largely borrowed from
# DBIx::Class::Storage::DBI.
sub _ensure_fresh_dbh
{
    my $self = shift;

    my $dbh = $self->_dbh();
    if ( $self->_pid() != $$ )
    {
        $dbh->{InactiveDestroy} = 1;
        $self->_unset_dbh();
    }

    if ( $self->_threaded()
         &&
         $self->_tid() != threads->tid()
       )
    {
        $self->_unset_dbh();
    }

    unless ( $dbh->{Active} && $dbh->ping() )
    {
        $self->_unset_dbh();
    }

    $self->_make_dbh() unless $self->_has_dbh();
}


1;

__END__
