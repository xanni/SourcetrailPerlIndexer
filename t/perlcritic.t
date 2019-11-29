use strict;
use warnings;

use Test::More;
plan skip_all => 'Test::Perl::Critic not installed' unless eval { require Test::Perl::Critic };

plan tests => 5;
Test::Perl::Critic::all_critic_ok(qw( _version.pm indexer.pm run.pl t ));
