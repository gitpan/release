# $Id: pod.t,v 1.6 2003/03/29 21:48:05 petdance Exp $

BEGIN {
    @pods = qw(
	blib/lib/Module/Release.pm
	blib/script/release
    );
}

use Test::More tests => scalar @pods;

SKIP: {
    eval "use Test::Pod 0.95";
    skip "Test::Pod 0.95 not installed", scalar @pods if $@;
    pod_file_ok($_) for @pods;
}

