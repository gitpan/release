# $Id: Makefile.PL,v 1.10 2003/03/27 04:58:58 petdance Exp $
use ExtUtils::MakeMaker;

eval "use Test::Pod";

if ( $@ ) {
    warn "Test::Pod is not installed on your machine, so we'll skip the POD tests.\n";
}

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION_FROM' => "lib/Module/Release.pm",
	
	'EXE_FILES' =>  [ 'release' ],
	    	
	'PREREQ_PM' => {
 		'ConfigReader::Simple' => '0',
 		'Test::More'           => '0',
	},

	'MAN1PODS' => {
		'release' => '$(INST_MAN1DIR)/release.1',
	},
		
	clean => { FILES => '*.bak release-*' },
);
