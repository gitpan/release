# $Id: load.t,v 1.2 2004/09/02 01:30:15 comdog Exp $

BEGIN {
	our @modules = qw(
		Module::Release
		Module::Release::Registry
		Module::Release::CVS
		Module::Release::UsePerl
		);
	}
	
use Test::More tests => scalar @modules;

foreach my $module ( @modules )
	{	
	print "bail out! [$module] has problems\n" 
		unless use_ok( $module );
	}
