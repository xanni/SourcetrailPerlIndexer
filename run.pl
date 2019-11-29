#!/usr/bin/perl

use v5.10;

use strict;
use warnings;

use FindBin;
use Getopt::Long qw(:config auto_version);
use Pod::Usage;

use lib "$FindBin::Bin";
use _version;
use indexer qw(:all);

my ( $clear, $database_file_path, $source_file_path, $verbose );
our $VERSION = $_version::VERSION;

GetOptions(
	'clear!'               => \$clear,
	'database-file-path=s' => \$database_file_path,
	'help'                 => sub { pod2usage( -verbose => 1 ) },
	'source-file-path=s'   => \$source_file_path,
	'verbose!'             => \$verbose,
);
pod2usage() unless $database_file_path && $source_file_path;

exit(1) unless is_sourcetraildb_version_compatible();

__END__

=head1 NAME

run.pl - Perl source code indexer that generates a Sourcetrail compatible database

=head1 SYNOPSIS

run.pl [-h] --database-file-path DATABASE_FILE_PATH --source-file-path SOURCE_FILE_PATH [--clear] [--verbose]

Index a Perl source file and store the indexed data to a Sourcetrail database file.

=head1 OPTIONS

  --clear                 clear the database before indexing
  --database-file-path    path to the generated Sourcetrail database file
  --source-file-path      path to the source file to index
  --verbose               enable verbose console output
  --version               print version of this program

=cut
