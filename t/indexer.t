package t::indexer;

use strict;
use warnings;

use File::Spec;
use FindBin;
use JSON;
use Mock::Quick;
use Test::Exit;
use Test::More tests => 5;

use lib File::Spec->catfile( $FindBin::Bin, '..' );
use indexer qw(:all);

is( exit_code { index_source_file('') }, 2, 'no source' );
$PPI::Document::errstr = '';    ## no critic (ProhibitPackageVars)

my ( $file, %kinds, $language, %symbols );
my $control = qtakeover(
	indexer => ( recordFile => sub { $file = shift; return 1 }, recordFileLanguage => sub { $language = $_[1] } ),
	recordSymbol => sub { $symbols{ $_[0] } = 1; return scalar keys %symbols },
	recordSymbolKind => sub { my ( $id, $kind ) = @_; $kinds{$id} = $kind },
);

my $source = '';
index_source_file( \$source );

is( $file,     \$source, 'recordFile' );
is( $language, 'perl',   'recordFileLanguage' );
like( ( keys %symbols )[0], qr/"name":"main"/x, 'recordSymbol' );
is_deeply( \%kinds, { 1 => $indexer::SYMBOL_PACKAGE }, 'recordSymbolKind' );

1;
