# $Id: Makefile.PL,v 1.11 2003/03/29 21:48:17 petdance Exp $
use ExtUtils::MakeMaker;

eval "use Test::Pod 0.95";

if ( $@ ) {
    warn "Test::Pod 0.95 is not installed on your machine, so we'll skip the POD tests.\n";
}

WriteMakefile(
	'NAME'	    => 'release',
	'VERSION_FROM' => "lib/Module/Release.pm",
	
	'EXE_FILES' =>  [ 'release' ],
	    	
	'PREREQ_PM' => {
 		'ConfigReader::Simple' => 0,
 		'Test::More'           => 0,
		'Config'               => 0,
		'CGI'                  => 0,
		'LWP::UserAgent'       => 0,
		'HTTP::Cookies'        => 0,
		'HTTP::Request'        => 0,
		'Net::FTP'             => 0,
		'File::Spec'           => 0,
	},

	'MAN1PODS' => {
		'release' => '$(INST_MAN1DIR)/release.1',
	},
		
	clean => { FILES => '*.bak release-*' },
);
