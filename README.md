# NAME

DBIx::Class::Schema::PgSearchPath

# SYNOPSIS

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

    # Read the current search path name
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

# DESCRIPTION

Component for [DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema)

Allows a schema instance to set a PostgreSQL search\_path in a way that
persists within connection managers like DBIx::Connection and
Catalyst::Model::DBIC::Schema

Useful when a Pg database has multiple Schemas with the same table structure.
The DBIx::Class::Schema instance can use the same Result classes to operate
on the independant data sets within the multiple schemas

Module relies heavily on the term **search path** when referring to a
PostgreSQL Schema, to avoid naming confusion with DBIx::Class::Schema

# About Schema->connection() parameters

Schema->connection() supports several formats of parameter list

This module only supports a hashref parameter list, as in the synopsis

# METHODS and FUNCTIONS

## search\_path

Return the current value for search\_path

## set\_search\_path pg\_schema\_name

Set the search path for the Pg database connection

Immediately issues a SET search\_path statement

Issues a SET search\_path statment upon database reconnect

## create\_search\_path search\_path

Create a Postgres Schema with the given name

## drop\_search\_path search\_path

Destroy a Postgres Schema with the given name

## validate\_search\_path pg\_schema\_name

Prevent SQL Injection, pg\_schema\_name may only contain
letters, numbers, and \_

## dbh\_do\_set\_storage\_path $storage, $search\_path

Issue SET search\_path statement on a given [DBIx::Class::Storage](https://metacpan.org/pod/DBIx::Class::Storage) object

Callback inserted into connect\_info on\_connect\_do attribute

## connection

Add on\_connect\_do callback to connections that sets search\_path

Currently only supports hash style connection() argument list, as
shown in the POD synopsis

## dbh\_do sql\_stm

Execute a single sql statement

Wrapper for schema->storage->dbh\_do.  Only appropriate when the statement
returns no results.

# BUGS

Probably

# SEE ALSO

[DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema), [DBIx::Class::Storage](https://metacpan.org/pod/DBIx::Class::Storage), [DBIx::Connection](https://metacpan.org/pod/DBIx::Connection)

# COPYRIGHT

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com> under the perl5 license
