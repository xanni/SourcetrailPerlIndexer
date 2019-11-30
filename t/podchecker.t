package t::podchecker;

use strict;
use warnings;

use Pod::Checker;
use Test::More tests => 1;

is( podchecker('run.pl'), 0, 'run.pl' );

1;
