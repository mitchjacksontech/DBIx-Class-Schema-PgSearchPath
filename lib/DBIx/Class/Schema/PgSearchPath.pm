package DBIx::Class::Schema::PgSearchPath;
use base qw/DBIx::Class::Schema/;
use strict;
use warnings;

=head1 NAME

DBIx::Class::Schema::PgSearchPath

=head1 SYNOPSIS

  # Define your Schema class
  package MyApp::Schema;
  use base qw/DBIx::Class::Schema::PgSearchPath/;
  
  __PACKAGE__->load_classes(qw/Arthur Ford Zaphod/);

  # Initialize the schema
  # (Only hashref connect_info style supported)
  $schema = MyApp::Schema->connection({
    dsn => 'dbi:Pg:database=myapp',
    user => undef,
    pass => undef,
    auto_commit => 1,
    raise_error => 1,
  )};
  
  # Select from table myapp_customer_1.foo
  $schema->set_search_path('myapp_customer_1');
  $schema->resultset('Foo')->all;

  # Read the current search path
  say $schema->search_path;

  # Select from table myapp_customer_3.foo
  # search_path settings persist accross disconnect/reconnect
  $schema->set_search_path('myapp_customer_3');

  # Pg search path selection will persist across connection manager
  # disconnect/reconnects
  $schema->storage->disconnect;
  $schema->resultset('Foo')->all;

  # Create a Pg schema
  $schema->create_search_path('yaph');

  # Destroy a Pg schema
  $schema->drop_search_path('yaph');

=head1 DESCRIPTION

Component for L<DBIx::Class::Schema>

Allows a schema instance to set a PostgreSQL search_path in a way that
persists within connection managers like DBIx::Connection and
Catalyst::Model::DBIC::Schema

Useful when a Pg database has multiple Schemas with the same table structure.
The DBIx::Class::Schema instance can use the same Result classes to operate
on the independant data sets within the multiple schemas

Module relies heavily on the term B<search path> when referring to a
PostgreSQL Schema, to avoid naming confusion with DBIx::Class::Schema

=head1 About Schema->connection() parameters

Schema->connection() supports several formats of parameter list

This module only supports a hashref parameter list, as in the synopsis

=head1 But They Said "Bad Things May Happen"

L<DBIx::Class::Storage::DBI::Pg/POSTGRESQL SCHEMA SUPPORT> says this:

  This driver supports multiple PostgreSQL schemas, with one
  caveat: for performance reasons, data about the search path,
  sequence names, and so forth is queried as needed and CACHED
  for subsequent uses.
  
  For this reason, once your schema is instantiated, you should
  not change the PostgreSQL schema search path for that schema's
  database connection. If you do, Bad Things may happen.

For my use case, the information being cached is identical between
the different search paths being selected.  I am deploying an identical
DBIx::Class::Schema into each search_path with $schema->deploy().

If you intend to switch between Pg search_path with variations in
table design, B<Bad Things May Happen>.  YMMV

=cut

our $VERSION = '0.3';
use Carp qw( croak );

__PACKAGE__->mk_group_accessors(inherited => '_search_path');
__PACKAGE__->_search_path('public');

=head1 METHODS

=head2 search_path

Return the current value for search_path name

=cut

sub search_path {
  # Protect from accidentally calling search_path() instead of set_search_path()
  croak 'search_path() accepts no arguments. Use set_search_path() instead'
    if $_[1];

  shift->_search_path;
}

=head2 set_search_path pg_schema_name

Set the search path for the Pg database connection

=cut

sub set_search_path {
  my $self = shift;

  my $search_path = shift || $self->_search_path || return;
  __check_search_path( $search_path );
  $self->_search_path( $search_path );

  __dbh_do_set_storage_path( $self->storage, $search_path );
}

=head2 create_search_path search_path

Create a Postgres Schema with the given name

=cut

sub create_search_path {
  my ( $self, $search_path ) = @_;

  # Unable to use $search_path as a bind value here.  It is being
  # enclosed in quotes, and this statement does not accept that.
  #
  # e.g.
  # $dbh->do('CREATE SCHEMA IF NOT EXISTS ?', undef, $search_path);
  __check_search_path( $search_path );

  $self->storage->dbh_do( sub {
    # my ( $storage, $dbh ) = @_;
    $_[1]->do("CREATE SCHEMA IF NOT EXISTS $search_path");
  });
}

=head2 drop_search_path search_path

Destroy a Postgres Schema with the given name

=cut

sub drop_search_path {
  my ( $self, $search_path ) = @_;

  # Unable to use $search_path as a bind value here.  It is being
  # enclosed in quotes, and this statement does not accept that.
  #
  # e.g.
  # $dbh->do('CREATE SCHEMA IF NOT EXISTS ?', undef, $search_path);
  __check_search_path( $search_path );

  $self->storage->dbh_do( sub {
    # my ( $storage, $dbh ) = @_;
    $_[1]->do("DROP SCHEMA IF EXISTS $search_path CASCADE");
  });
}

=head1 METHODS Overload

=head2 connection %connect_info

Overload L<DBIx::Class::Schema/connection>

Inserts a callback into L<DBIx::Class::Storage::DBI/on_connect_call>
to set search_path on dbh reconnect

Use of this module requires using only the hashref style of
connect_info arguments. Other connect_info formats are not
supported.  See L<DBIx::Class::Storage::DBI/connect_info>

=cut

sub connection {
  my ( $self, @args ) = @_;

  my %conn = %{$args[0]};

  die 'DBIx::Class::Schema::PgSearchPath only supports hashref '
    . 'style connection() argument list'
      unless $conn{dsn};

  my $callback_sub = sub {
    # my ( $storage ) = @_;
    __dbh_do_set_storage_path( $_[0], $self->_search_path );
  };

  # Add an on_connect_call callback to set search_path
  if ( exists $conn{on_connect_call} ) {
    my $occ = $conn{on_connect_call};

    if ( ref $occ eq 'ARRAY' ) {
      push @$occ, $callback_sub;
    } else {
      $conn{on_connect_call} = [ $occ, $callback_sub ];
    }
  } else {
    $conn{on_connect_call} = [ $callback_sub ];
  }

  return $self->next::method( \%conn );
}

=head1 INTERNAL SUBS

=head2 __check_search_path $search_path

This function is a validation work-around to prevent SQL injection.

I haven't found an approach that lets me use an auto escaped and quoted
placeholder value for a particular sql stm:

  # will fail D:
  $dbh->do('CREATE SCHEMA IF NOT EXISTS ?', undef, $search_path);

L<https://www.postgresql.org/docs/9.3/sql-prepare.html> Psql docs hint it is
possible to declare a data type for a bound parameter, but I must be too
stupid to make that work for this use case.

So for the moment, I am limiting $search_path to a small set of characters
that works for me.

=cut

sub __check_search_path {
  croak "search_path '$_[0]' may only contain letters, numbers and _"
    if @_ && $_[0] =~ /[^a-zA-Z0-9\_]/;
}

=head2 __dbh_do_set_storage_path $storage, $search_path

Execute sql statement to set storage_path

=cut

sub __dbh_do_set_storage_path {
  my ( $storage, $search_path ) = @_;

  die 'search_path parameter is required' unless $search_path;

  $storage->dbh_do( sub {
    # my ( $storage, $dbh ) = @_;

    # Placeholder for search_path DOES work here at least :D
    $_[1]->do( 'SET search_path = ?', undef, $search_path );
  });
}

=head1 BUGS

Limited support for characters in search_path names.  Done in the name of
SQL injection protection.  Overload L<__check_search_path>, or submit a
patch, if this is a problem for you.

=cut

=head1 SEE ALSO

L<DBIx::Class::Schema>, L<DBIx::Class::Storage>, L<DBIx::Connection>

=head1 COPYRIGHT

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com> under the perl5 license

=cut

1;
