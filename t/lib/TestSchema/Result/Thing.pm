package TestSchema::Result::Thing;
use base qw/DBIx::Class::Core/;
use strict;
use warnings;

__PACKAGE__->table('things');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    thing => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },,
);
__PACKAGE__->set_primary_key(qw/id/);

1;
