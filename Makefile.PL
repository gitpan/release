# $Id: Makefile.PL,v 1.13 2004/12/17 21:27:18 petdance Exp $
use ExtUtils::MakeMaker;

eval "use Test::Manifest";
unless( $@ )
   {
   * ExtUtils::MM_Any::test_via_harness = sub
	   {
	   my($self, $perl, $tests) = @_;

	   return qq|\t$perl "-MTest::Manifest" | .
				  qq|"-e" "run_t_manifest(\$(TEST_VERBOSE), '\$(INST_LIB)', | .
				  qq|'\$(INST_ARCHLIB)')"\n|;
	   }
   }
	   
WriteMakefile(
	'NAME'	       => 'release',
	'VERSION_FROM' => "lib/Release.pm",
	
	'EXE_FILES' =>  [ 'release' ],
	    	
	'PREREQ_PM' => {
 		'ConfigReader::Simple' => 0,
		'Net::FTP'             => 0,
	},

	'PM' => {
        'lib/Release.pm'  => '$(INST_LIBDIR)/Module/Release.pm',
        'lib/Registry.pm' => '$(INST_LIBDIR)/Module/Release/Registry.pm',
        'lib/CVS.pm'      => '$(INST_LIBDIR)/Module/Release/CVS.pm',
        'lib/UsePerl.pm'  => '$(INST_LIBDIR)/Module/Release/UsePerl.pm',
    },

	'MAN1PODS' => {
		'release' => '$(INST_MAN1DIR)/release.1',
	},
		
	clean => { FILES => '*.bak release-*' },
);
