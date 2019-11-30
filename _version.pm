package _version;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw($SOURCETRAIL_DB_VERSION $VERSION);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use version v0.77; our $VERSION = version->declare('v1.25.0');
our $SOURCETRAIL_DB_VERSION = 'v3.db25.p0';

1;
