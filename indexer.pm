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

# Import all symbols from sourcetraildb package
BEGIN { $indexer::{$_} = $sourcetraildb::{$_} foreach ( keys %sourcetraildb:: ); }

our @EXPORT_OK = qw(index_source_file is_sourcetraildb_version_compatible);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

Readonly my %PRAGMAS => map { $_ => 1 }
	qw(attributes autodie autouse base bigint bignum bigrat blib bytes charnames constant diagnostics encoding feature
	fields filetest if integer less lib locale more open ops overload overloading parent re sigtrap sort strict subs
	threads threads::shared utf8 vars vmsish warnings warnings::register);

my ( $file_id, $main_id, $package, $package_id );

sub encode_symbol {
	my %args   = @_;
	my %symbol = (
		name_delimiter => '::',
		name_elements  => [
			map { prefix => $args{prefix} // '', name => $_, postfix => $args{postfix} // '', },
			split( '::', $args{name} )
		]
	);
	return encode_json( \%symbol );
} ## end sub encode_symbol

sub index_global_variables {
	my ($node) = @_;

	if ( $node->class eq 'PPI::Structure::List' || $node->class eq 'PPI::Statement::Expression' ) {
		foreach my $child ( $node->schildren() ) { index_global_variables($child); }

		return;
	}

	return unless $node->class eq 'PPI::Token::Symbol';

	my ( $sigil, $name ) = $node->content =~ qr/ ([\W]+) (.+) /x;
	my $symbol_id = recordSymbol( encode_symbol( prefix => $sigil, name => $name ) );
	recordSymbolDefinitionKind( $symbol_id, $DEFINITION_EXPLICIT );
	recordSymbolKind( $symbol_id, $SYMBOL_GLOBAL_VARIABLE );
	recordSymbolLocation( $symbol_id, $file_id, $node->line_number, $node->column_number, $node->line_number,
		$node->column_number + length( $node->content ) - 1 );

	return;
} ## end sub index_global_variables

sub index_include {
	my ($node) = @_;

	my $kind = $node->schild(0) eq 'use' ? $REFERENCE_IMPORT : $REFERENCE_INCLUDE;
	my $name = $node->schild(1);
	return if $name->class ne 'PPI::Token::Word' || $PRAGMAS{ $name->content };

	my $name_id = recordSymbol( encode_symbol( name => $name->content ) );
	recordSymbolKind( $name_id, $SYMBOL_PACKAGE );
	recordReference( $package_id || $main_id, $name_id, $kind );
	recordReferenceLocation( $name_id, $file_id, $name->line_number, $name->column_number, $name->line_number,
		$name->column_number + length( $name->content ) - 1 );

	return;
} ## end sub index_include

sub index_local_variables {
	my ($node) = @_;

	if ( $node->class eq 'PPI::Structure::List' || $node->class eq 'PPI::Statement::Expression' ) {
		foreach my $child ( $node->schildren() ) { index_local_variables($child); }
		return;
	}

	return unless $node->class eq 'PPI::Token::Symbol';

	my ( $sigil, $name ) = $node->content =~ qr/ ([\W]+) (.+) /x;
	my $symbol_id = recordSymbol( encode_symbol( prefix => $sigil, name => $name ) );
	recordSymbolDefinitionKind( $symbol_id, $DEFINITION_EXPLICIT );
	recordSymbolLocation( $symbol_id, $file_id, $node->line_number, $node->column_number, $node->line_number,
		$node->column_number + length( $node->content ) - 1 );

	return;
} ## end sub index_local_variables

sub index_package {
	my ($node) = @_;

	my $name = $node->schild(1);
	$package = $name->content;
	$package_id = recordSymbol( encode_symbol( name => $package ) );
	recordSymbolDefinitionKind( $package_id, $DEFINITION_EXPLICIT );
	recordSymbolKind( $package_id, $SYMBOL_PACKAGE );
	recordSymbolLocation( $package_id, $file_id, $name->line_number, $name->column_number, $name->line_number,
		$name->column_number + length( $name->content ) - 1 );

	return;
} ## end sub index_package

sub index_source_file {
	my ( $source_file_path, $verbose ) = @_;
	say "INFO: Indexing source file '$source_file_path'." if $verbose;
	my $document = PPI::Document->new($source_file_path);
	if ( PPI::Document->errstr ) {
		say 'ERROR: ' . PPI::Document->errstr;
		exit(2);
	}

	$file_id = recordFile($source_file_path);
	recordFileLanguage( $file_id, 'perl' );

	$document->index_locations();

#	PPI::Dumper->new( $document, whitespace => 0 )->print();

	$main_id = recordSymbol( encode_symbol( name => 'main' ) );
	recordSymbolKind( $main_id, $SYMBOL_PACKAGE );

	index_statements($document);

	return;
} ## end sub index_source_file

sub index_statements {
	my ($node) = @_;

	foreach my $child ( $node->schildren ) {
		my $class = $child->class;
		if ( $class eq 'PPI::Statement::Include' )  { index_include($child);   next; }
		if ( $class eq 'PPI::Statement::Package' )  { index_package($child);   next; }
		if ( $class eq 'PPI::Statement::Variable' ) { index_variables($child); next; }
		if ( $class eq 'PPI::Token::Symbol' )       { index_symbol($child);    next; }
		index_statements($child) unless $class =~ m/^PPI::Token/x;
	} ## end foreach my $child ( $node->schildren )

	return;
} ## end sub index_statements

sub index_symbol {
	my ($node) = @_;

	my ( $sigil, $name ) = $node->content =~ qr/ ([\W]+) (.+) /x;
	my $symbol_id = recordSymbol( encode_symbol( prefix => $sigil, name => $name ) );
	recordReference( $package_id || $main_id, $symbol_id, $REFERENCE_USAGE );
	recordReferenceLocation( $symbol_id, $file_id, $node->line_number, $node->column_number, $node->line_number,
		$node->column_number + length( $node->content ) - 1 );

	return;
} ## end sub index_symbol

sub index_variables {
	my ($node) = @_;

	if   ( $node->schild(0) eq 'our' ) { index_global_variables( $node->schild(1) ) }
	else                               { index_local_variables( $node->schild(1) ) }

	return;
} ## end sub index_variables

sub is_sourcetraildb_version_compatible {
	my $db_version = eval { getVersionString() };
	return 1 if $db_version eq $SOURCETRAIL_DB_VERSION;

	$db_version = "($db_version) " if $db_version;
	say "ERROR: Used version of SourcetrailDB ${db_version}"
		. "is incompatible to what is required by this version of SourcetrailPerlIndexer "
		. "($SOURCETRAIL_DB_VERSION).";

	return;
} ## end sub is_sourcetraildb_version_compatible

1;
