# DBIx::Class::Schema::PgSearchPath

## SYNOPSIS

```perl
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
```

## DESCRIPTION

Component for DBIx::Class::Schema

Allows a schema instance to set a PostgreSQL search_path in a way that
persists within connection managers like DBIx::Connection and
Catalyst::Model::DBIC::Schema

Useful when a Pg database has multiple Schemas with the same table structure.
The DBIx::Class::Schema instance can use the same Result classes to operate
on the independant data sets within the multiple schemas

## About Schema->connection() parameters

Schema->connection() supports several formats of parameter list

This module only supports a hashref parameter list, as in the synopsis

## COPYRIGHT

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com> under the perl5 license
