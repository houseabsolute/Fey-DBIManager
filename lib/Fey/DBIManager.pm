package Fey::DBIManager;

use strict;
use warnings;

our $VERSION = '0.01';

use Fey::Exceptions qw( object_state_error param_error );
use Scalar::Util qw( blessed );

use Fey::DBIManager::Source;
use Moose::Policy 'MooseX::Policy::SemiAffordanceAccessor';
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

has _sources =>
    ( metaclass => 'Collection::Hash',
      is        => 'ro',
      isa       => 'HashRef[Fey::DBIManager::Source]',
      default   => sub { {} },
      init_arg  => "\0_sources",
      provides  => { get    => 'get_source',
                     set    => 'add_source',
                     delete => 'remove_source',
                     count  => 'source_count',
                     exists => 'has_source',
                     values => 'sources',
                   },
    );

has default_source =>
    ( is        => 'rw',
      isa       => 'Fey::DBIManager::Source',
      predicate => 'has_default_source',
      writer    => '_set_default_source',
      clearer   => '_clear_default_source',
      init_arg  => "\0default_source",
    );


around 'add_source' =>
    sub { my $orig   = shift;
          my $self   = shift;
          my $source = shift;

          my $name;
          if ( blessed $source && $source->can('name') )
          {
              $name = $source->name();

              param_error qq{You already have a source named "$name".}
                  if $self->has_source($name);
          }

          my $return = $self->$orig( $name => $source );

          if ( $self->source_count() == 1 )
          {
              $self->_set_default_source( ( $self->sources() )[0] );
          }
          elsif ( $self->get_source('default') )
          {
              $self->_set_default_source( $self->get_source('default') );
          }
          else
          {
              $self->_clear_default_source();
          }

          return $return;
        };

before default_source =>
    sub { my $self = shift;

          return if $self->has_default_source();

          if ( $self->source_count() == 0 )
          {
              object_state_error 'This manager has no default source because it has no sources at all.';
          }
          else
          {
              object_state_error 'This manager has multiple sources, but none are named "default".';
          }

          return;
        };

sub source_for_sql
{
    my $self = shift;

    return $self->default_source();
}

no Moose;
__PACKAGE__->meta()->make_immutable();


1;
