package t::tests;

use strict;
use warnings;

use Test::More tests => 2;

use lib '.';
use_ok('_version');
use_ok('indexer');

1;
