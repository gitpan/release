# $Id: pod.t,v 1.3 2003/03/19 21:40:24 petdance Exp $

use Test::More tests => 1;


SKIP: {
    eval "use Test::Pod;";
    skip "Test::Pod not installed", 1 if $@;
    pod_file_ok('blib/script/release');
}

