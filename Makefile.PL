# $Id: Makefile.PL,v 1.8 2003/03/14 17:24:38 petdance Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION'   => '0.15',
	
	'EXE_FILES' =>  [ 'release' ],
	    	
	'PREREQ_PM' => {
 		'ConfigReader::Simple' => '0',
 		'Test::More'           => '0',
 		'Test::Pod'            => '0.95'
	},

	'MAN1PODS' => {
		'release' => '$(INST_MAN1DIR)/release.1',
	},
		
	clean => { FILES => '*.bak release-*' },
);
