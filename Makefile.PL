# $Id: Makefile.PL,v 1.9 2003/03/19 21:40:24 petdance Exp $
use ExtUtils::MakeMaker;

eval "use Test::Pod";

if ( $@ ) {
    warn "Test::Pod is not installed on your machine, so we'll skip the POD tests.\n";
}

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION'   => '0.16',
	
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
