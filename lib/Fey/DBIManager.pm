package Fey::DBIManager;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors
    ( qw( name dsn username password attributes
          post_connect auto_refresh ) );

use DBI;
use Fey::Validate
    qw( validate validate_pos SCALAR_TYPE HASHREF_TYPE BOOLEAN_TYPE CODEREF_TYPE DBI_TYPE );


{
    my $spec = { name         => SCALAR_TYPE( default => 'main' ),
                 dsn          => SCALAR_TYPE,
                 username     => SCALAR_TYPE( default => '' ),
                 password     => SCALAR_TYPE( default => '' ),
                 attributes   => HASHREF_TYPE( default => {} ),
                 post_connect => CODEREF_TYPE( optional => 1 ),
                 auto_refresh => BOOLEAN_TYPE( default => 1 ),
               };
    sub new
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        $class->_set_attributes( $p{attributes} );

        return bless { %p,
                       threaded => threads->can('tid'),
                     }, $class;
    }

    sub ConstructorSpec { return $spec }
}

sub _set_attributes
{
    my $self = shift;
    my $attr = shift;

    $attr->{AutoCommit}         = 1;
    $attr->{RaiseError}         = 1;
    $attr->{PrintError}         = 0;
    $attr->{PrintWarn}          = 1;
    $attr->{ShowErrorStatement} = 1;
}

sub dbh
{
    my $self = shift;

    return $self->_make_dbh()
        unless $self->{dbh};

    $self->_ensure_fresh_dbh() if $self->auto_refresh();

    return $self->{dbh};
}

sub _make_dbh
{
    my $self = shift;

    $self->{dbh} =
        DBI->connect
            ( $self->dsn(), $self->username(), $self->password(), $self->attributes() );

    $self->_set_pid_tid();

    $self->{post_connect}->( $self->{dbh} )
        if $self->{post_connect};

    return $self->{dbh};
}

sub _set_pid_tid
{
    my $self = shift;

    $self->{pid} = $$;
    $self->{tid} = threads->tid() if $self->{threaded};
}

# The logic in this method is largely borrowed from
# DBIx::Class::Storage::DBI.
sub _ensure_fresh_dbh
{
    my $self = shift;

    if ( $self->{pid} != $$ )
    {
        $self->{dbh}{InactiveDestroy} = 1;
        undef $self->{dbh};
    }

    if ( $self->{threaded}
         &&
         $self->{tid} != threads->tid()
       )
    {
        undef $self->{dbh};
    }

    unless ( $self->{dbh}{Active} && $self->{dbh}->ping() )
    {
        undef $self->{dbh};
    }

    $self->_make_dbh() unless $self->{dbh};
}

{
    my $spec = DBI_TYPE;
    sub set_dbh
    {
        my $self  = shift;
        my ($dbh) = validate_pos( @_, $spec );

        $self->_set_attributes($dbh);

        $self->_set_pid_tid();

        $self->{dbh} = $dbh;
    }
}


1;

__END__
