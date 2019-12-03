package t::perlcritic;

use strict;
use warnings;

use Test::More;
plan skip_all => 'Test::Perl::Critic not installed' unless eval {
	require Test::Perl::Critic;
	Test::Perl::Critic->import( -severity => 3, -exclude => qw(ProhibitVersionStrings) );
};

plan tests => 7;
Test::Perl::Critic::all_critic_ok(qw( _version.pm indexer.pm run.pl t ));

1;
