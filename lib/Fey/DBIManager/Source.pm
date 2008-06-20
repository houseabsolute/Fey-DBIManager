package Fey::DBIManager::Source;

use strict;
use warnings;

use Moose::Policy 'MooseX::Policy::SemiAffordanceAccessor';
use MooseX::StrictConstructor;

has 'name' =>
    ( is      => 'ro',
      isa     => 'Str',
      default => 'default',
    );

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

after '_unset_dbh' =>
    sub { $_[0]->_clear_supports_nested_transactions() };

has 'dsn' =>
    ( is        => 'rw',
      isa       => 'Str',
      predicate => '_has_dsn',
      writer    => '_set_dsn',
      required  => 1,
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

has 'allows_nested_transactions' =>
    ( is      => 'ro',
      isa     => 'Bool',
      lazy    => 1,
      default => \&_check_nested_transactions,
      clearer => '_clear_supports_nested_transactions',
    );

has '_threaded' =>
    ( is       => 'ro',
      isa      => 'Bool',
      lazy     => 1,
      default  => sub { threads->can('tid') ? 1 : 0 },
      init_arg => undef,
    );

has '_pid' =>
    ( is       => 'rw',
      isa      => 'Num',
      init_arg => undef,
    );

has '_tid' =>
    ( is       => 'rw',
      isa      => 'Num',
      init_arg => undef,
    );

use DBI;
use Fey::Exceptions qw( param_error );
use Fey::Validate
    qw( validate_pos DBI_TYPE );


sub BUILD
{
    my $self   = shift;
    my $params = shift;

    $self->_set_attributes( { %{ $self->attributes() },
                              $self->_required_dbh_attributes(),
                            }
                          );

    $self->_set_pid_tid()
        if $self->_has_dbh();

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

sub _check_nested_transactions
{
    my $self = shift;

    my $dbh = $self->dbh();

    my $allows_nested =
        eval
        {
            # This error comes from DBI in its default implementation
            # of begin_work(). There didn't seem to be a way to shut
            # this off (setting PrintWarn to false does not do
            # it). Hopefully the message text won't change.
            local $SIG{__WARN__}
                = sub { warn @_ unless $_[0] =~ /Already in a transaction/ };

            $dbh->begin_work();
            $dbh->begin_work();
            $dbh->rollback();
            $dbh->rollback();
            1;
        };

    if ($@)
    {
        $dbh->rollback() unless $dbh->{AutoCommit};
    }

    return $allows_nested;
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
        $dbh->disconnect();
        $self->_unset_dbh();
    }

    if ( $self->_threaded()
         &&
         $self->_tid() != threads->tid()
       )
    {
        $dbh->disconnect();
        $self->_unset_dbh();
    }

    # Maybe consider only pinging once ever X seconds/minutes?
    unless ( $dbh->{Active} && $dbh->ping() )
    {
        $dbh->disconnect();
        $self->_unset_dbh();
    }

    $self->_make_dbh() unless $self->_has_dbh();
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::DBIManager::Source - Wraps a single DBI handle

=head1 SYNOPSIS

  my $source = Fey::DBIManager::Source->new( dbh => $dbh );

  my $dbh = $source->dbh();

=head1 DESCRIPTION

A C<Fey::DBIManager::Source> object provides a wrapper around a C<DBI>
handle which does things like ensure that handles are recreated
properly after a fork.

A source can be created from an existing DBI handle, or from
parameters such as the dsn and authentication info.

=head1 METHODS

This class provides the following methods:

=head2 Fey::DBIManager::Source->new(...)

Creates a new C<Fey::DBIManager::Source> object. This method accepts a
number of parameters.

=over 4

=item * name

The name of the source. This defaults to "default", which cooperates
nicely with L<Fey::DBIManager>.

=item * dbh

An already connected C<DBI> handle. Even if this is given, you still
need to provide the relevant connection parameters such as "dsn".

=item * dsn

A C<DBI> DSN string. This is required.

=item * username

=item * password

The username and password for the source. These both default to an
empty string.

=item * attributes

A hash reference of attributes to be passed to C<< DBI->connect()
>>. Note that some attributes are set for all handles. See L<REQUIRED
ATTRIBUTES> for more details. This attribute is optional.

=item * post_connect

This is an optional subroutine reference which will be called after a
handle is created with C<< DBI->connect() >>. This is a handy way to
set connection info or to set driver-specific attributes like
"mysql_enable_utf8" or "pg_auto_escape".

=item * auto_refresh

A boolean value. The default is true, which means that whenever you
call C<< $source->dbh() >>, the source ensures that the database
handle is still active. See L<HANDLE FRESHNESS> for more details.

=back

=head2 $source->dbh()

Returns a database handle for the source. If you did not pass a handle
to the constructor, this may create a new handle. If C<auto_refresh>
is true, this may cause a new handle to be created. See L<HANDLE
FRESHNESS> for more details.

=head2 $source->dsn()

=head2 $source->username()

=head2 $source->password()

=head2 $source->post_connect()

=head2 $source->auto_connect()

These methods simply return the value of the specified attribute.

=head2 $source->attributes()

This method reutrns attributes hash reference for the source. This
will be a combination of any attributes passed to the constructor plus
the L<REQUIRED ATTRIBUTES>.

=head2 $source->allows_nested_transactions()

Returns a boolean indicating whether or not the database to which the
source connects supports nested transactions. It does this by trying
to issue two calls to C<< $dbh->begin_work() >> followed by two calls
to C<< $dbh->rollback() >> (in an eval block).

=head1 REQUIRED ATTRIBUTES

In order to provide consistency for C<Fey::ORM>, sources enforce a set
of standard attributes:

=over 4

=item * AutoCommit => 1

=item * RaiseError => 1

=item * PrintError => 0

=item * PrintWarn  => 1

=item * ShowErrorStatement => 1

=back

=head1 HANDLE FRESHNESS

If C<auto_refresh> is true for a source, then every call to C<<
$source->dbh() >> incurs the cost of a "freshness" check. The upside
of this is that it will just work in the face of forks, threading, and
lost connections.

First, we check to see if the pid has changed since the handle was
created. If it has, we set C<InactiveDestroy> to true in the handle
and disconnect it. If the thread has changed, we just disconnect the
handle.

Finally, we check C<< $dbh->{Active] >> and call C<< $dbh->ping()
>>. If either of these is false, we disconnect the handle.

If the handle is not fresh, a new one is created.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-fey-dbimanager@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2008 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
