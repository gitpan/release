package Module::Release;

=head1 NAME

Module::Release - Methods for releasing packages

=head1 SYNOPSIS

	use Module::Release;

=head1 VERSION

Version 0.25

    $Header: /cvsroot/brian-d-foy/release/lib/Release.pm,v 1.3 2004/12/17 21:54:48 petdance Exp $

=over 4

=cut

our $VERSION = '0.25';

use strict;
use Config;
use CGI qw(-oldstyle_urls);
use ConfigReader::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Net::FTP;
use File::Spec;
use Carp;
use constant DASHES => "-" x 73;


sub _resolve_method
	{
	my $self   = shift;
	my $method = shift;
	
	my( $key, $name ) = split /_/, $method, 2;
	
	my $plugin = $self->get_plugin( lc $key ) ;

	return $plugin unless $plugin == 1;
	
	return ( $plugin, $name );
	}
	
sub _call_method
	{
	my $self = shift;
	my ( $plugin, $name, @args ) = @_;
	
	"$plugin::$name"->( $self, @args );
	}

=back
		
=head2 C<new()>

Create a Module::Release object.  Any arguments passed are assumed to
be key-value pairs that override the default values.

At this point, the C<new()> method is not overridable via the
C<release_subclass> config file entry.  It would be nice to fix this
sometime.

=cut

sub new {
    my ($class, %params) = @_;
    my $self = {
			make => $Config{make},
			perl => $ENV{PERL} || $^X,
			conf => '.releaserc',
			debug => $ENV{RELEASE_DEBUG} || 0,
			local => undef,
			remote => undef,
			%params,
	       };

    # Read the configuration
    die "Could not find conf file $self->{conf}\n" unless -e $self->{conf};
    my $config = $self->{config} = ConfigReader::Simple->new( $self->{conf} );
    die "Could not get configuration data\n" unless ref $config;

    # See whether we should be using a subclass
    if (my $subclass = $config->release_subclass) {
	unless (UNIVERSAL::can($subclass, 'new')) {
	    require File::Spec->catfile( split '::', $subclass ) . '.pm';
	}
	bless $self, $subclass;
    } else {
	bless $self, $class;
    }

    # Figure out options
    $self->{cpan} = $config->cpan_user eq '<none>' ? 0 : 1;
    $self->{sf}   = $config->sf_user   eq '<none>' ? 0 : 1;
    $self->{passive_ftp} = ($config->passive_ftp && $config->passive_ftp =~ /^y(es)?/) ? 1 : 0;

    my @required = qw( sf_user cpan_user );
    push( @required, qw( sf_group_id sf_package_id ) ) if $self->{sf};

    my $ok = 1;
    for( @required ) {
	unless ( length $config->$_() ) {
	    $ok = 0;  
	    print "Missing configuration data: $_; Aborting!\n";
	}
    }
    die "Missing configuration data" unless $ok;
  
    if( !$self->{cpan} && !$self->{sf} ) {
	die "Must upload to the CPAN or SourceForge.net; Aborting!\n";
    }
    elsif( !$self->{cpan} ) {
	print "Uploading to SourceForge.net only\n";
    }
    elsif( !$self->{sf} ) {
	print "Uploading to the CPAN only\n";
    }
  

    # Set up the browser
    $self->{ua}      = LWP::UserAgent->new( agent => 'Mozilla/4.5' );
    $self->{cookies} = HTTP::Cookies->new(
					    file           => ".lwpcookies",
					    hide_cookie2   => 1,
					    autosave       => 1 );
    $self->{cookies}->clear;

    return $self;
}

=head2 clean()

Clean up the directory to get rid of old versions

=cut

sub clean {
    my $self = shift;
    print "Cleaning directory... ";
    
    unless( -e 'Makefile' ) {
        print " no Makefile---skipping\n";
        return;
    }

    $self->run( "$self->{make} realclean 2>&1" );

    print "done\n";

} # clean

=head2 C<build_makefile()>

Builds the makefile from Makefile.PL

=cut

sub build_makefile {
    my $self = shift;
    print "Recreating make file... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    $self->run( "$self->{perl} Makefile.PL 2>&1" );

    print "done\n";
} # perl

=head2 C<test()>

Check the tests, which must all pass

=cut

sub test {
    my $self = shift;
    print "Checking make test... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $tests = $self->run( "$self->{make} test 2>&1" );

    die "\nERROR: Tests failed!\n$tests\n\nAborting release\n"
            unless $tests =~ /All tests successful/;

    print "all tests pass\n";
} # test

=head2 C<dist()>

Make the distribution

=cut

sub dist {
    my $self = shift;
    print "Making dist... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $messages = $self->run( "$self->{make} dist 2>&1" );

    unless( $self->{local} ){
        print ", guessing local distribution name" if $self->{debug};
        ($self->{local}) = $messages =~ /^\s*gzip.+?\b'?(\S+\.tar)'?\s*$/m;
        $self->{local} .= '.gz';
        $self->{remote} = $self->{local};
    }

    die "Couldn't guess distname from dist output\n" unless $self->{local};
    die "Local file '$self->{local}' does not exist\n" unless -f $self->{local};

    print "done\n";
} # dist

=head2 C<dist_test()>

Check the distribution test

=cut

sub dist_test {
    my $self = shift;
    print "Checking disttest... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $tests = $self->run( "$self->{make} disttest 2>&1" );

    die "\nERROR: Tests failed!\n$tests\n\nAborting release\n"
            unless $tests =~ /All tests successful/;

    print "all tests pass\n";
} # dist_test


=head2 C<check_for_passwords()>

Makes sure that C<cpan_pass> and C<sf_pass> members are populated,
as appropriate.  This function must die if the calling program is
not able to continue.

=cut

sub check_for_passwords {
    my $self = shift;

    if ( $self->{cpan} ) {
	$self->{cpan_pass} = $self->getpass( "CPAN_PASS" );
    }
    if ( $self->{sf} ) {
	$self->{sf_pass} = $self->getpass( "SF_PASS" );
    }
}

=head2 C<ftp_upload()>

Upload the files to the FTP servers

=cut

sub ftp_upload {
    my $self = shift;
    my @Sites;
    push @Sites, 'pause.perl.org' if $self->{cpan};
    push @Sites, 'upload.sourceforge.net' if $self->{sf};
    
    ( $self->{release} ) = $self->{remote} =~ m/^(.*?)(?:\.tar\.gz)?$/g;
    
    my $config = $self->{config};
    # set your own release name if you want to ...
    if( $config->sf_release_match && $config->sf_release_replace ) {
        my $match   = $config->sf_release_match;
        my $replace = $config->sf_release_replace;
        $self->{release} =~ s/$match/$replace/ee;
    }
    
    print "Release name is $self->{release}\n";
    print "Will use passive FTP transfers\n" if $self->{passive_ftp} && $self->{debug};


    my $local_file = $self->{local};
    my $local_size = -s $local_file;
    foreach my $site ( @Sites ) {
        print "Logging in to $site\n";
        my $ftp = Net::FTP->new( $site, Hash => \*STDOUT, Debug => $self->{debug}, Passive => $self->{passive_ftp} )
	    or die "Couldn't open FTP connection to $site: $@";

	my $email = ($config->cpan_user || "anonymous") . '@cpan.org';
        $ftp->login( "anonymous", $email )
	    or die "Couldn't log in anonymously to $site";

        $ftp->pasv if $self->{passive_ftp};
        $ftp->binary;

        $ftp->cwd( "/incoming" )
	    or die "Couldn't chdir to /incoming";

	print "Putting $local_file\n";
        my $remote_file = $ftp->put( $self->{local}, $self->{remote} );
	die "PUT failed: $@\n" if $remote_file ne $self->{remote};

	my $remote_size = $ftp->size( $self->{remote} );
	if ( $remote_size != $local_size ) {
	    warn "WARNING: Uploaded file is $remote_size bytes, but local file is $local_size bytes";
	}

        $ftp->quit;
    }
} # ftp_upload

=head2 C<pause_claim()>

Claim the file in PAUSE

=cut

sub pause_claim {
    my $self = shift;
    return unless $self->{cpan};

    my $cgi = CGI->new();
    my $ua  = LWP::UserAgent->new();

    my $request = HTTP::Request->new( POST =>
            'http://pause.perl.org/pause/authenquery' );

    $cgi->param( 'HIDDENNAME', $self->{config}->cpan_user );
    $cgi->param( 'CAN_MULTIPART', 1 );
    $cgi->param( 'pause99_add_uri_upload', $self->{remote} );
    $cgi->param( 'SUBMIT_pause99_add_uri_upload', 'Upload the checked file' );
    $cgi->param( 'pause99_add_uri_sub', 'pause99_add_uri_subdirtext' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->authorization_basic( $self->{config}->cpan_user, $self->{cpan_pass} );
    $request->content( $cgi->query_string );

    my $response = $ua->request( $request );

    print "PAUSE upload ",
            $response->as_string =~ /Query succeeded/ ? "successful" : 'failed',
            "\n";
} # pause_claim

=head2 C<get_readme()>

Read and parse the F<README> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_readme {
        open my $fh, '<README' or return '';
        my $data = do {
                local $/;
                <$fh>;
        };
        return $data;
}

=head2 C<get_changes()>

Read and parse the F<Changes> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_changes {
        open my $fh, '<Changes' or return '';
        my $data = <$fh>;  # get first line
        while (<$fh>) {
                if (/^\S/) { # next line beginning with non-whitespace is end ... YMMV
                        last;
                }
                $data .= $_;
        }
        return $data;
}

=head2 C<run()>

Run a command in the shell.

=cut

sub run {
    my ($self, $command) = @_;
    print "$command\n" if $self->{debug};
    open my($fh), "$command |" or die $!;
    my $output = '';
    local $| = 1;
    
    while (<$fh>) {
        $output .= $_;
        print if $self->{debug};
    }
    print DASHES, "\n" if $self->{debug};
    
    return $output;
};

=head2 C<getpass()>

Get a password from the user if it isn't found.

=cut

sub getpass {
    my ($self, $field) = @_;

    my $pass = $ENV{$field};
    
    return $pass if defined( $pass ) && length( $pass );

    print "$field is not set.  Enter it now: ";
    $pass = <>;
    chomp $pass;

    return $pass if defined( $pass ) && length( $pass );

    die "$field not supplied.  Aborting...\n";
}

1;

__END__
