#!/usr/bin/perl

use v5.10;

use strict;
use warnings;

use Carp;
use File::Spec;
use FindBin;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

use lib $FindBin::Bin;
use _version qw($VERSION);
use indexer qw(:all);
use sourcetraildb;

sub sourcetrail_fatal {
	say 'ERROR: ' . sourcetraildb::getLastError();
	exit(2);
}

my ( $clear, $database_file_path, $source_file_path, $verbose );

GetOptions(
	'clear!'               => \$clear,
	'database-file-path=s' => \$database_file_path,
	'help|?'               => sub { pod2usage( -verbose => 1 ) },
	'man'                  => sub { pod2usage( -verbose => 2 ) },
	'source-file-path=s'   => \$source_file_path,
	'verbose|v!'           => \$verbose,
	'version|V'            => sub { say "$0 version $VERSION"; exit },
);
pod2usage() unless $database_file_path && $source_file_path;

exit(2) unless is_sourcetraildb_version_compatible();

$database_file_path = File::Spec->rel2abs($database_file_path);
$source_file_path   = File::Spec->rel2abs($source_file_path);

sourcetrail_fatal() unless sourcetraildb::open($database_file_path);

if ($clear) {
	say 'INFO: Clearing database...' if $verbose;
	sourcetrail_fatal() unless sourcetraildb::clear();
	say 'INFO: Clearing done.' if $verbose;
}

sourcetraildb::beginTransaction();
index_source_file( $source_file_path, $verbose );
sourcetraildb::commitTransaction();
sourcetrail_fatal() unless sourcetraildb::close();

__END__

=head1 NAME

run.pl - Perl source code indexer that generates a Sourcetrail compatible database

=head1 SYNOPSIS

run.pl [--help] [--man] [--version] --database-file-path=DATABASE_FILE_PATH
--source-file-path=SOURCE_FILE_PATH [--clear] [--verbose]

 Options:

  --help                print brief help message and exit
  --man                 show full documentation and exit
  --version             print version of this program and exit
  --database-file-path  path to the generated Sourcetrail database file (required)
  --source-file-path    path to the generated Sourcetrail database file (required)
  --clear               clear the database before indexing
  --verbose             enable verbose console output

=head1 DESCRIPTION

Index a Perl source file and store the indexed data to a Sourcetrail database file.

=head1 OPTIONS

=over

=item B<-c>, B<--clear>

clear the database before indexing

=item B<-d> I<path>, B<--database-file-path>=I<path>

path to the generated Sourcetrail database file (required)

=item B<-m>, B<--man>

show full documentation and exit

=item B<-h>, B<--help>

print brief help message and exit

=item B<-s> I<path>, B<--source-file-path>=I<path>

path to the source file to index (required)

=item B<-v>, B<--verbose>

enable verbose console output

=item B<-V>, B<--version>

print version of this program and exit

=back

=head1 AUTHOR

Andrew Pam L<mailto:andrew@sericyb.com.au>

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Andrew Pam

This program is licensed under the GNU General Public License v3.0 or later

SPDX-License-Identifier: GPL-3.0-or-later

=cut
