#$Id: pod.t,v 1.7 2004/09/02 01:29:20 comdog Exp $
use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();
