package t::tests;

use strict;
use warnings;

use File::Spec;
use FindBin;
use JSON;
use Mock::Quick;
use Test::More tests => 8;

use lib File::Spec->catfile($FindBin::Bin, '..');

our ( $VERSION, $SOURCETRAIL_DB_VERSION );

BEGIN {
	use_ok( '_version', qw(:all) );
	use_ok( 'indexer',  qw(:all) );
}

# _version tests
ok( $VERSION,                '$VERSION exported' );
ok( $SOURCETRAIL_DB_VERSION, '$SOURCETRAIL_DB_VERSION exported' );

# indexer unit tests
my %expect = ( name_delimiter => '::', name_elements => [ { prefix => '', name => 'test', postfix => '' } ] );
is_deeply( decode_json( indexer::encode_symbol( prefix => '', name => 'test', postfix => '' ) ),
	\%expect, 'encode_symbol name' );
$expect{name_elements} = [ map { prefix => 'pre', name => $_, postfix => 'post' }, qw(test class) ];
is_deeply( decode_json( indexer::encode_symbol( prefix => 'pre', name => 'test::class', postfix => 'post' ) ),
	\%expect, 'encode_symbol complex' );

my $control = qtakeover( indexer => ( getVersionString => '' ) );
ok( !is_sourcetraildb_version_compatible(), 'is_sourcetraildb_version_compatible fails' );
$control->override( getVersionString => $SOURCETRAIL_DB_VERSION );
ok( is_sourcetraildb_version_compatible(), 'is_sourcetraildb_version_compatible' );
undef $control;

1;
