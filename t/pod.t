# $Id: pod.t,v 1.5 2003/03/27 04:51:02 petdance Exp $

BEGIN {
    @pods = qw(
	blib/lib/Module/Release.pm
	blib/script/release
    );
}

use Test::More tests => scalar @pods;

SKIP: {
    eval "use Test::Pod;";
    $bad = ( $@ || ($Test::Pod::VERSION < '0.95') );
    skip "Test::Pod 0.95 not installed", scalar @pods if $bad;
    pod_file_ok($_) for @pods;
}

