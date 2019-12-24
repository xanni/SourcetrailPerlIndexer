package t::indexer;

use strict;
use warnings;

use File::Spec;
use FindBin;
use JSON;
use Mock::Quick;
use Test::Exit;
use Test::More tests => 20;

use lib File::Spec->catfile( $FindBin::Bin, '..' );
use indexer qw(:all);

my $CALL       = $indexer::REFERENCE_CALL;
my $EXPLICIT   = $indexer::DEFINITION_EXPLICIT;
my $FUNCTION   = $indexer::SYMBOL_FUNCTION;
my $GLOBAL_VAR = $indexer::SYMBOL_GLOBAL_VARIABLE;
my $IMPLICIT   = $indexer::DEFINITION_IMPLICIT;
my $IMPORT     = $indexer::REFERENCE_IMPORT;
my $INCLUDE    = $indexer::REFERENCE_INCLUDE;
my $PACKAGE    = $indexer::SYMBOL_PACKAGE;
my $USAGE      = $indexer::REFERENCE_USAGE;

my ( $file, $language, @references, %references, @symbols, %symbols );

sub decode_symbol {
    my $symbol_ref = decode_json(shift);
    my $name_ref   = $symbol_ref->{name_elements};
    return $name_ref->[-1]{prefix} . join( '::', map { $name_ref->[$_]{name} } keys @{$name_ref} );
}

sub record_reference {
    my ( $from, $to, $kind ) = @_;

    push @{ $references{$from}{$to} }, scalar @references;
    push @references, { K => $kind };

    return $references{$from}{$to}[-1];
} ## end sub record_reference

sub record_reference_location {
    my $i = shift;

    $references[$i] = { %{ $references[$i] }, F => shift, LB => shift, CB => shift, LE => shift, CE => shift };
    return;
} ## end sub record_reference_location

sub record_symbol {
    my ($key) = @_;

    $key = decode_symbol($key);
    if ( !exists $symbols{$key} ) {
        $symbols{$key} = scalar @symbols;
        push @symbols, { D => $IMPLICIT };
    }

    return $symbols{$key};
} ## end sub record_symbol

sub record_symbol_location {
    my $i = shift;

    $symbols[$i] = { %{ $symbols[$i] }, F => shift, LB => shift, CB => shift, LE => shift, CE => shift };

    return;
} ## end sub record_symbol_location

# ---------- Tests start here ----------

is( exit_code { index_source_file('') }, 2, 'no source' );
$PPI::Document::errstr = '';    ## no critic (ProhibitPackageVars)

my $control = qtakeover(
    indexer => ( recordFile => sub { $file = shift; return 1 }, recordFileLanguage => sub { $language = $_[1] } ),
    recordSymbol               => \&record_symbol,
    recordSymbolDefinitionKind => sub { $symbols[ $_[0] ]{D} = $_[1] },
    recordSymbolKind           => sub { my ( $id, $kind ) = @_; $symbols[$id]{K} = $kind },
    recordSymbolLocation       => \&record_symbol_location,
    recordReference            => \&record_reference,
    recordReferenceLocation    => \&record_reference_location,
);

my $source = '';
index_source_file( \$source );

is( $file,     \$source, 'recordFile' );
is( $language, 'perl',   'recordFileLanguage' );
is_deeply( [ sort keys %symbols ], [qw(main)], 'recordSymbol' );
is_deeply( \@symbols, [ { D => $IMPLICIT, K => $indexer::SYMBOL_PACKAGE } ], 'recordSymbolKind' );

# package NAMESPACE
# package NAMESPACE VERSION
# package NAMESPACE BLOCK
# package NAMESPACE VERSION BLOCK

$source = <<'CODE';
package test1;
package test2 v1.0;
package test3 { 1; }
package test4 v1.1 { 1; }
{ package test5; }
package main;
CODE

my @expect = (
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 6, CB => 9,  LE => 6, CE => 12 },    # main
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 1, CB => 9,  LE => 1, CE => 13 },    # test1
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 2, CB => 9,  LE => 2, CE => 13 },    # test2
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 3, CB => 9,  LE => 3, CE => 13 },    # test3
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 4, CB => 9,  LE => 4, CE => 13 },    # test4
    { D => $EXPLICIT, F => 1, K => $PACKAGE, LB => 5, CB => 11, LE => 5, CE => 15 },    # test5
);
index_source_file( \$source );
is_deeply( [ sort keys %symbols ], [qw(main test1 test2 test3 test4 test5)], 'package symbols' );
is_deeply( \@symbols, \@expect, 'package definitions' );

# require VERSION
# require NAMESPACE
# require FILENAME
# use Pragma
# use Module VERSION LIST
# use Module VERSION
# use Module LIST
# use Module
# use VERSION

@symbols = %symbols = ();
$source = <<'CODE';
require v5.10;
require test1;
require '_version.pm';
use strict;
use test2 v1.0 ();
use test3 v1.1;
use test4 ();
use test5;
use v5.10.1;
CODE

@expect = ( ( { D => $IMPLICIT, K => $PACKAGE, } ) x 6 );
my @expect_refs = (
    { K => $INCLUDE, F => 1, LB => 2, CB => 9, LE => 2, CE => 13, },    # test1
    { K => $IMPORT,  F => 1, LB => 5, CB => 5, LE => 5, CE => 9, },     # test2
    { K => $IMPORT,  F => 1, LB => 6, CB => 5, LE => 6, CE => 9, },     # test3
    { K => $IMPORT,  F => 1, LB => 7, CB => 5, LE => 7, CE => 9, },     # test4
    { K => $IMPORT,  F => 1, LB => 8, CB => 5, LE => 8, CE => 9, },     # test5
);
index_source_file( \$source );
is_deeply( [ sort keys %symbols ], [qw(main test1 test2 test3 test4 test5)], 'require and use symbols' );
is_deeply( \@symbols,    \@expect,      'require and use definitions' );
is_deeply( \@references, \@expect_refs, 'require and use references' );

# sub NAME;			                     # A "forward" declaration.
# sub NAME(PROTO);		                 #  ditto, but with prototypes
# sub NAME : ATTRS;		                 #  with attributes
# sub NAME(PROTO) : ATTRS;	             #  with attributes and prototypes
# sub NAME BLOCK		                 # A declaration and a definition.
# sub NAME(PROTO) BLOCK                  #  ditto, but with prototypes
# sub NAME : ATTRS BLOCK	             #  with attributes
# sub NAME(PROTO) : ATTRS BLOCK          #  with prototypes and attributes
# sub NAME(SIG) BLOCK                    # with signature
# sub NAME :ATTRS (SIG) BLOCK            # with signature, attributes
# sub NAME :prototype(PROTO) (SIG) BLOCK # with signature, prototype

@symbols = %symbols = ();
$source = <<'CODE';
sub test1;
sub test2();
sub test3 : attr1() : attr2;
sub test4() : attr1() : attr2;
sub test5 {}
sub test6() {}
sub test7 : attr1() : attr2 {}
sub test8() : attr1() : attr2 {}
sub test9($arg1) {}
sub testa :attr1() :attr2 ($arg2) {}
sub testb :prototype() ($arg3) {}
CODE

@expect = (
    { D => $IMPLICIT, K => $PACKAGE, },    # main
    ( map { D => $EXPLICIT, F => 1, K => $FUNCTION, LB => $_, CB => 5, LE => $_, CE => 9, }, ( 1 .. 10 ) ),  # test 1..a
    { D => $IMPLICIT, },                                                                                     # arg2
    { D => $EXPLICIT, F => 1, K => $FUNCTION, LB => 11, CB => 5, LE => 11, CE => 9, },                       # test b
    { D => $IMPLICIT, },                                                                                     # arg3
);
index_source_file( \$source );
is_deeply(
    [ sort keys %symbols ],
    [ qw($main::arg2 $main::arg3 main), map { "main::test$_" } ( 1 .. 9, 'a' .. 'b' ) ],
    'sub symbols'
);
is_deeply( \@symbols, \@expect, 'sub definitions' );

# Anonymous subs (closures)
# sub BLOCK;		                     # no proto
# sub (PROTO) BLOCK;	                 # with proto
# sub : ATTRS BLOCK;	                 # with attributes
# sub (PROTO) : ATTRS BLOCK;             # with proto and attributes
# sub (SIG) BLOCK;                       # with signature
# sub : ATTRS (SIG) BLOCK;               # with signature, attributes

@symbols = %symbols = ();
$source = <<'CODE';
sub {};
sub () {};
# sub : attr1() : attr2 {};              # PPI wrongly parses "sub :" as a label
sub () : attr1() : attr2 {};
sub ($arg1) {};
# sub : attr1() : attr2 ($arg2) {};      # PPI wrongly parses "sub :" as a label
CODE

@expect = (
    { D => $IMPLICIT, K => $PACKAGE, },    # main
);
index_source_file( \$source );
is_deeply( [ sort keys %symbols ], [qw(main)], 'anonymous sub symbols' );
is_deeply( \@symbols, \@expect, 'anonymous sub definitions' );

# subroutine calls
# NAME(LIST);	   # & is optional with parentheses.
# NAME LIST;	   # Parentheses optional if predeclared/imported.
# &NAME(LIST);     # Circumvent prototypes.
# &NAME;	       # Makes current @_ visible to called subroutine.

@references = %references = @symbols = %symbols = ();
$source = <<'CODE';
test1();
test2;
&test3();
&test4;
CODE

@expect = ( { D => $IMPLICIT, K => $PACKAGE, }, ( { D => $IMPLICIT, K => $FUNCTION, } ) x 4 );
@expect_refs = (
    { K => $CALL, F => 1, LB => 1, CB => 1, LE => 1, CE => 5, },    # test1
    { K => $CALL, F => 1, LB => 2, CB => 1, LE => 2, CE => 5, },    # test2
    { K => $CALL, F => 1, LB => 3, CB => 1, LE => 3, CE => 6, },    # test4
    { K => $CALL, F => 1, LB => 4, CB => 1, LE => 4, CE => 6, },    # test5
);
index_source_file( \$source );
is_deeply( [ sort keys %symbols ], [ qw(main), map { "main::test$_" } ( 1 .. 4 ) ], 'sub references' );
is_deeply( \@symbols,    \@expect,      'sub references definitions' );
is_deeply( \@references, \@expect_refs, 'require and use references' );

# global variables
# our VARLIST
# our TYPE VARLIST
# our VARLIST : ATTRS
# our TYPE VARLIST : ATTRS

@references = %references = @symbols = %symbols = ();
$source = <<'CODE';
$test = 0;  $main::test;  $test;
package p1;  $p1::test = 1;  $p1::test;
our $test;  $test;
package p2;  our $test;  $test;
our ($test1, $test2);
# package Class;  use fields qw(test test4);  our Class $test;
our $test3 : attr3;
# our Class $test4 : attr4;
CODE

@expect = (
    { D => $IMPLICIT, K => $PACKAGE, },                                                     # main
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 1, CB => 1, LE => 1, CE => 5, },      # $main::test
    { D => $EXPLICIT, K => $PACKAGE, F => 1, LB => 2, CB => 9, LE => 2, CE => 10, },        # p1
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 2, CB => 14, LE => 2, CE => 22, },    # $p1::test
    { D => $EXPLICIT, K => $PACKAGE, F => 1, LB => 4, CB => 9, LE => 4, CE => 10, },        # p2
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 4, CB => 18, LE => 4, CE => 22, },    # $p2::test
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 5, CB => 6, LE => 5, CE => 11, },     # $p2::test1
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 5, CB => 14, LE => 5, CE => 19, },    # $p2::test2
    { D => $EXPLICIT, K => $GLOBAL_VAR, F => 1, LB => 7, CB => 5, LE => 7, CE => 10, },     # $p2::test3
    { D => $IMPLICIT, K => $FUNCTION, },                                                    # p2::attr3
);
@expect_refs = (
    { K => $USAGE, F => 1, LB => 1, CB => 13, LE => 1, CE => 23, },                         # $main::test
    { K => $USAGE, F => 1, LB => 1, CB => 27, LE => 1, CE => 31, },                         # $main::test
    { K => $USAGE, F => 1, LB => 2, CB => 30, LE => 2, CE => 38, },                         # $p1::test
    { K => $USAGE, F => 1, LB => 3, CB => 5,  LE => 3, CE => 9, },                          # $p1::test
    { K => $USAGE, F => 1, LB => 3, CB => 13, LE => 3, CE => 17, },                         # $p1::test
    { K => $USAGE, F => 1, LB => 4, CB => 26, LE => 4, CE => 30, },                         # $p2::test
    { K => $CALL,  F => 1, LB => 7, CB => 14, LE => 7, CE => 18, },                         # p2::attr3
);
index_source_file( \$source );
is_deeply(
    [ sort keys %symbols ],
    [qw($main::test $p1::test $p2::test $p2::test1 $p2::test2 $p2::test3 main p1 p2 p2::attr3)],
    'global variables'
);
is_deeply( \@symbols, \@expect, 'global variable definitions' );
is_deeply( \@references, \@expect_refs, 'global variable references' );

1;
