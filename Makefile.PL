# $Id: Makefile.PL,v 1.6 2003/03/12 15:59:05 petdance Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION'   => '0.13',
	
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
