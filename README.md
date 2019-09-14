# NAME

DBIx::Class::Schema::PgSearchPath

# SYNOPSIS

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

# But They Said "Bad Things May Happen"

["POSTGRESQL SCHEMA SUPPORT" in DBIx::Class::Storage::DBI::Pg](https://metacpan.org/pod/DBIx::Class::Storage::DBI::Pg#POSTGRESQL-SCHEMA-SUPPORT) says this:

    This driver supports multiple PostgreSQL schemas, with one
    caveat: for performance reasons, data about the search path,
    sequence names, and so forth is queried as needed and CACHED
    for subsequent uses.
    
    For this reason, once your schema is instantiated, you should
    not change the PostgreSQL schema search path for that schema's
    database connection. If you do, Bad Things may happen.

For my use case, the information being cached is identical between
the different search paths being selected.  I am deploying an identical
DBIx::Class::Schema into each search\_path with $schema->deploy().

If you intend to switch between Pg search\_path with variations in
table design, **Bad Things May Happen**.  YMMV

# METHODS

## search\_path

Return the current value for search\_path name

## set\_search\_path pg\_schema\_name

Set the search path for the Pg database connection

## create\_search\_path search\_path

Create a Postgres Schema with the given name

## drop\_search\_path search\_path

Destroy a Postgres Schema with the given name

# METHODS Overload

## connection %connect\_info

Overload ["connection" in DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema#connection)

Inserts a callback into ["on\_connect\_call" in DBIx::Class::Storage::DBI](https://metacpan.org/pod/DBIx::Class::Storage::DBI#on_connect_call)
to set search\_path on dbh reconnect

Use of this module requires using only the hashref style of
connect\_info arguments. Other connect\_info formats are not
supported.  See ["connect\_info" in DBIx::Class::Storage::DBI](https://metacpan.org/pod/DBIx::Class::Storage::DBI#connect_info)

# INTERNAL SUBS

## \_\_check\_search\_path $search\_path

This function is a validation work-around to prevent SQL injection.

I haven't found an approach that lets me use an auto escaped and quoted
placeholder value for a particular sql stm:

    # will fail D:
    $dbh->do('CREATE SCHEMA IF NOT EXISTS ?', undef, $search_path);

[https://www.postgresql.org/docs/9.3/sql-prepare.html](https://www.postgresql.org/docs/9.3/sql-prepare.html) Psql docs hint it is
possible to declare a data type for a bound parameter, but I must be too
stupid to make that work for this use case.

So for the moment, I am limiting $search\_path to a small set of characters
that works for me.

## \_\_dbh\_do\_set\_storage\_path $storage, $search\_path

Execute sql statement to set storage\_path

# BUGS

Limited support for characters in search\_path names.  Done in the name of
SQL injection protection.  Overload [\_\_check\_search\_path](https://metacpan.org/pod/__check_search_path), or submit a
patch, if this is a problem for you.

# SEE ALSO

[DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema), [DBIx::Class::Storage](https://metacpan.org/pod/DBIx::Class::Storage), [DBIx::Connection](https://metacpan.org/pod/DBIx::Connection)

# COPYRIGHT

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com> under the perl5 license
