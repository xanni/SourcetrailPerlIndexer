package indexer;

use v5.10;

use strict;
use warnings;

use Exporter qw(import);
use JSON;
use PPI;
use PPI::Dumper;
use Readonly;

use _version qw($SOURCETRAIL_DB_VERSION);
use sourcetraildb;

our @EXPORT_OK = qw(index_source_file is_sourcetraildb_version_compatible);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

Readonly my %PRAGMAS => map { $_ => 1 }
	qw(attributes autodie autouse base bigint bignum bigrat blib bytes charnames constant diagnostics encoding feature
	fields filetest if integer less lib locale more open ops overload overloading parent re sigtrap sort strict subs
	threads threads::shared utf8 vars vmsish warnings warnings::register);

sub _encode_symbol {
	my %args   = @_;
	my %symbol = (
		name_delimiter => '::',
		name_elements  => [
			map { prefix => $args{prefix} // '', name => $_, postfix => $args{postfix} // '', },
			split( '::', $args{name} )
		]
	);
	return encode_json( \%symbol );
} ## end sub _encode_symbol

sub is_sourcetraildb_version_compatible {
	my $db_version = eval { sourcetraildb::getVersionString() };
	return 1 if $db_version eq $SOURCETRAIL_DB_VERSION;

	$db_version = "($db_version) " if $db_version;
	say "ERROR: Used version of SourcetrailDB ${db_version}"
		. "is incompatible to what is required by this version of SourcetrailPerlIndexer "
		. "($SOURCETRAIL_DB_VERSION).";

	return;
} ## end sub is_sourcetraildb_version_compatible

sub index_source_file {
	my ( $source_file_path, $verbose ) = @_;
	say "INFO: Indexing source file '$source_file_path'." if $verbose;
	my $document = PPI::Document->new($source_file_path);
	if ( PPI::Document->errstr ) {
		say 'ERROR: ' . PPI::Document->errstr;
		exit(2);
	}

	my $file_id = sourcetraildb::recordFile($source_file_path);
	sourcetraildb::recordFileLanguage( $file_id, 'perl' );

	$document->index_locations();

#	PPI::Dumper->new( $document, whitespace => 0 )->print();

	my $main_id = sourcetraildb::recordSymbol( _encode_symbol( name => 'main' ) );
	sourcetraildb::recordSymbolKind( $main_id, $sourcetraildb::SYMBOL_PACKAGE );

	my $package = '';
	my $package_id;
	foreach my $node ( $document->schildren() ) {
		if ( $node->class eq 'PPI::Statement::Include' ) {
			my $kind = $node->schild(0) eq 'use' ? $sourcetraildb::REFERENCE_IMPORT : $sourcetraildb::REFERENCE_INCLUDE;
			my $name = $node->schild(1);
			next if $name->class ne 'PPI::Token::Word' || $PRAGMAS{ $name->content };

			my $name_id = sourcetraildb::recordSymbol( _encode_symbol( name => $name->content ) );
			sourcetraildb::recordSymbolKind( $name_id, $sourcetraildb::SYMBOL_PACKAGE );
			sourcetraildb::recordReference( $package_id || $main_id, $name_id, $kind );
			sourcetraildb::recordReferenceLocation( $name_id, $file_id, $name->line_number, $name->column_number,
				$name->line_number, $name->column_number + length( $name->content ) - 1 );
		} ## end if ( $node->class eq 'PPI::Statement::Include')

		if ( $node->class eq 'PPI::Statement::Package' ) {
			my $name = $node->schild(1);
			$package = $name->content;
			$package_id = sourcetraildb::recordSymbol( _encode_symbol( name => $package ) );
			sourcetraildb::recordSymbolDefinitionKind( $package_id, $sourcetraildb::DEFINITION_EXPLICIT );
			sourcetraildb::recordSymbolKind( $package_id, $sourcetraildb::SYMBOL_PACKAGE );
			sourcetraildb::recordSymbolLocation( $package_id, $file_id, $name->line_number, $name->column_number,
				$name->line_number, $name->column_number + length( $name->content ) - 1 );
		} ## end if ( $node->class eq 'PPI::Statement::Package')
	} ## end foreach my $node ( $document->schildren() )

	return;
} ## end sub index_source_file

1;
