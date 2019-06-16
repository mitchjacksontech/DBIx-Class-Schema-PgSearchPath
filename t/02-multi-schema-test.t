use Test::More;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestSchema;

#
# To run these tests, you'll need a live PostgreSQL server and a database
#
# sudo -u postgres createuser -s myusername
# createdb multi_schema_test
# export PGSEARCHPATH_TEST_DSN=dbi:Pg:database=multi_schema_test
#

SKIP: {
  skip 'Set PGSEARCHPATH_TEST_DSN for live database testing'
    unless $ENV{PGSEARCHPATH_TEST_DSN};

  my $schema = TestSchema->connection({
    dsn => $ENV{PGSEARCHPATH_TEST_DSN},
    user => undef,
    pass => undef,
    auto_commit => 1,
    raise_error => 1,
  });

  my @search_paths = qw/search_path1 search_path2/;

  # Create schemas and tables
  for my $search_path ( @search_paths ) {
    ok(
      $schema->storage->dbh_do(
        sub {
          my ( $storage, $dbh ) = @_;
          $dbh->do("CREATE SCHEMA IF NOT EXISTS $search_path;")
            or die $dbh->errstr;
        }
      ),
      "Create schema $search_path",
    );

    ok(
      $schema->set_search_path($search_path),
      "set_search_path($search_path)"
    );

    ok(
      $schema->deploy() || 1,
      '$schema->deploy()',
    );
  }

  # Create two rows in each search path and confirm
  # their independence
  for my $search_path ( @search_paths ) {
    ok(
      $schema->set_search_path( $search_path ),
      "set_search_path($search_path)",
    );

    my @things = ("$search_path:thing1","$search_path:thing2");
    for my $thing ( @things ) {
      ok(
        $schema->resultset('Thing')->create({thing => $thing}),
        "Create thing $thing",
      );
    }

    # Verify only (x) things exists, and they exists in @things
    ok(
      $schema->resultset('Thing')->count == scalar(@things),
      sprintf(
        '%s.things count %s == %s',
        $search_path,
        $schema->resultset('Thing')->count,
        scalar(@things),
      ),
    );

    for my $row ( $schema->resultset('Thing')->all ) {
      ok(
        grep( { $row->thing eq $_ } @things ),
        sprintf(
          "thing %s belongs in %s.things",
          $row->thing,
          $search_path,
        )
      );
    }
  }

  # Force a disconnection within DBIx::Connection
  # Connection manager will create new db connection on next db call
  # Verify connection persists choice of schema
  ok(
    $schema->storage->disconnect || 1,
    '$schema->storage->disconnect',
  );

  ok(
    $schema->_search_path eq 'search_path2',
    '$schema->_search_path attribute persisted accross disconnect',
  );

  ok(
    $schema->resultset('Thing')->first->thing =~ /search_path2/,
    'Next query still executed in correct schema search_path',
  );

  # Teardown schemas
  for my $search_path ( @search_paths ) {
    ok(
      $schema->storage->dbh_do(
        sub {
          my ( $storage, $dbh ) = @_;
          $dbh->do("DROP SCHEMA IF EXISTS $search_path CASCADE;")
            or die $dbh->errstr;
        }
      ),
      "Drop schema $search_path",
    );
  }

}

done_testing;

1;

