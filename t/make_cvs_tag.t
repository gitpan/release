# $Id: make_cvs_tag.t,v 1.2 2004/09/02 01:33:24 comdog Exp $

BEGIN {
    our %tags = qw(
		Foo-Bar-0.04.tar.gz	RELEASE_0_04
		);
	}

use Test::More tests => (scalar keys %tags) + 2;

use_ok( 'Module::Release::CVS' );
