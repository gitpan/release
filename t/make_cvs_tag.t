BEGIN {
    our %tags = (
	'Foo-Bar-0.04.tar.gz'	=> 'RELEASE_0_04'
    );
}

use Test::More tests=>(scalar keys %tags) + 2;

use_ok( 'Module::Release' );
my $r = new Module::Release;
isa_ok( $r, 'Module::Release' );

while ( my($file,$tag) = each %tags ) {
    $r->{remote} = $file;
    is( $r->make_cvs_tag(), $tag, $file )
}
