# $Id: Makefile.PL,v 1.3 2003/03/03 17:47:51 petdance Exp $
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION'   => '0.11',
	
	'EXE_FILES' =>  [ 'release' ],
	    	
	'PREREQ_PM' => {
 		'ConfigReader::Simple' => '0',
 		'Test::More'           => '0',
 		'Test::Pod'            => '0.90'
	},

	'MAN1PODS' => {
		'release' => '$(INST_MAN1DIR)/release.1',
	},
		
	clean => { FILES => '*.bak release-*' },
);
