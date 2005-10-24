# $Id: compile.t,v 1.3 2003/03/27 04:51:17 petdance Exp $

use Test::More tests => 2;

my $file = 'blib/script/release';

print "bail out! Script file is missing!" unless ok( -e $file, "File exists" );

my $output = `$^X -c $file 2>&1`;

like( $output, qr/syntax OK$/, 'script compiles' );
