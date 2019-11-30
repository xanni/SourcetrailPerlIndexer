package indexer;

use v5.10;

use strict;
use warnings;

use Exporter qw(import);

use _version qw($SOURCETRAIL_DB_VERSION);
use sourcetraildb;

our @EXPORT_OK = qw(is_sourcetraildb_version_compatible);
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

1;
