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
  
  # Select from table myapp_customer_3.foo
  # search_path settings persist accross disconnect/reconnect
  $schema->set_search_path('myapp_customer_3');
  $schema->storage->disconnect;
  $schema->resultset('Foo')->all;

=head1 DESCRIPTION

Component for L<DBIx::Class::Schema>

Allows a schema instance to set a PostgreSQL search_path in a way that
persists within connection managers like DBIx::Connection and
Catalyst::Model::DBIC::Schema

Useful when a Pg database has multiple Schemas with the same table structure.
The DBIx::Class::Schema instance can use the same Result classes to operate
on the independant data sets within the multiple schemas

=head1 About Schema->connection() parameters

Schema->connection() supports several formats of parameter list

This module only supports a hashref parameter list, as in the synopsis

=cut

our $VERSION = '0.1';
use Carp qw( croak );

__PACKAGE__->mk_group_accessors(inherited => '_search_path');
__PACKAGE__->_search_path('public');

=head1 METHODS and FUNCTIONS

=head2 set_search_path pg_schema_name

Set the search path for the Pg database connection

Immediately issues a SET search_path statement

Issues a SET search_path statment upon database reconnect

=cut

sub set_search_path {
  my $self = shift;
  my $search_path = shift || $self->_search_path;

  $self->validate_search_path( $search_path );
  return unless $search_path;

  $self->_search_path( $search_path );
  dbh_do_set_storage_path( $self->storage, $search_path );
}

=head2 validate_search_path pg_schema_name

Prevent SQL Injection, pg_schema_name may only contain
letters, numbers, and _

=cut

sub validate_search_path {
  my ( $self, $search_path ) = @_;
  if ( $search_path && $search_path =~ /[^a-zA-Z0-9\_]/ ) {
    croak "search_path '$search_path' may only contain letters, numbers and _";
  }
}

=head2 dbh_do_set_storage_path $storage, $search_path

Issue SET search_path statement on a given L<DBIx::Class::Storage> object

Callback inserted into connect_info on_connect_do attribute

=cut

sub dbh_do_set_storage_path {
  my ( $storage, $search_path ) = @_;

  die 'search_path parameter is required' unless $search_path;
  validate_search_path(undef, $search_path);

  $storage->dbh_do(
    sub {
      my ( $storage, $dbh ) = @_;
      $dbh->do("SET search_path = $search_path;")
        or die $dbh->errstr;
    }
  )
}

=head2 connection

Add on_connect_do callback to connections that sets search_path

Currently only supports hash style connection() argument list, as
shown in the POD synopsis

=cut

sub connection {
  my ( $self, @args ) = @_;

  my %conn = %{$args[0]};

  die 'DBIx::Class::Schema::PgSearchPath only supports hash style connection() '
    . 'argument list'
      unless $conn{dsn};

  # todo: could be extended to detect existing on_connect_do callbacks ando not
  #       step on them
  $conn{on_connect_do} = sub {
    my $storage = shift;
    dbh_do_set_storage_path( $storage, $self->_search_path );
  };

  return $self->next::method( \%conn );
}

=head1 BUGS

Probably

=cut

=head1 SEE ALSO

L<DBIx::Class::Schema>, L<DBIx::Class::Storage>, L<DBIx::Connection>

=head1 COPYRIGHT

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com> under the perl5 license

=cut

1;
