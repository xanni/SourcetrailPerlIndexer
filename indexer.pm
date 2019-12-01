package indexer;

use v5.10;

use strict;
use warnings;

use Exporter qw(import);
use JSON;
use PPI;
use PPI::Dumper;

use _version qw($SOURCETRAIL_DB_VERSION);
use sourcetraildb;

our @EXPORT_OK = qw(index_source_file is_sourcetraildb_version_compatible);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

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

	my $package = '';
	foreach my $node ( $document->schildren() ) {
		if ( $node->class eq 'PPI::Statement::Include' ) {
			my $kind = $node->schild(0) eq 'use' ? $sourcetraildb::REFERENCE_IMPORT : $sourcetraildb::REFERENCE_INCLUDE;
			my $name = $node->schild(1);
			next if $name->class ne 'PPI::Token::Word';
			my %symbol = (
				name_delimiter => '::',
				name_elements  => [ { prefix => '', name => $name->content, postfix => '', } ]
			);
			my $name_id = sourcetraildb::recordSymbol( encode_json( \%symbol ) );
			sourcetraildb::recordReference( $file_id, $name_id, $kind );
			my $next_token = $name->next_token;
			sourcetraildb::recordReferenceLocation( $name_id, $file_id, $name->line_number, $name->column_number,
				$next_token->line_number, $next_token->column_number - 1 );
		} ## end if ( $node->class eq 'PPI::Statement::Include')

		if ( $node->class eq 'PPI::Statement::Package' ) {
			my $name = $node->schild(1);
			$package = $name->content eq 'main' ? '' : $name->content;
			my %symbol
				= ( name_delimiter => '::', name_elements => [ { prefix => '', name => $package, postfix => '', } ] );
			my $package_id = sourcetraildb::recordSymbol( encode_json( \%symbol ) );
			sourcetraildb::recordSymbolDefinitionKind( $package_id, $sourcetraildb::DEFINITION_EXPLICIT );
			sourcetraildb::recordSymbolKind( $package_id, $sourcetraildb::SYMBOL_PACKAGE );
			my $next_token = $name->next_token;
			sourcetraildb::recordSymbolLocation( $package_id, $file_id, $name->line_number, $name->column_number,
				$next_token->line_number, $next_token->column_number - 1 );
		} ## end if ( $node->class eq 'PPI::Statement::Package')
	} ## end foreach my $node ( $document->schildren() )

	return;
} ## end sub index_source_file

1;
