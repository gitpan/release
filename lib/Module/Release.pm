package Module::Release;

=head1 NAME

Module::Release - Methods for releasing packages to CPAN and SourceForge.

=head1 SYNOPSIS

Right now, there are no user-servicable parts inside.  However, this
has been split out like this so that there can be in the future.

=head1 VERSION

Version 0.20

    $Header: /cvsroot/brian-d-foy/release/lib/Module/Release.pm,v 1.3 2003/03/27 05:17:04 petdance Exp $

=cut

our $VERSION = '0.20';

use strict;
use Config;
use CGI qw(-oldstyle_urls);
use ConfigReader::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Net::FTP;

use constant DASHES => "-" x 73;

=head2 C<new()>

Create a Module::Release object.  Any arguments passed are assumed to
be key-value pairs that override the default values.

=cut

sub new {
    my ($class, %params) = @_;
    my $self = bless {
			make => $Config{make},
			perl => $ENV{PERL} || $^X,
			conf => '.releaserc',
			debug => $ENV{RELEASE_DEBUG} || 0,
			local => undef,
			remote => undef,
			%params,
		    }, $class;

    # Read the configuration
    die "Could not find conf file $self->{conf}\n" unless -e $self->{conf};
    my $config = $self->{config} = ConfigReader::Simple->new( $self->{conf} );
    die "Could not get configuration data\n" unless ref $config;

    # Figure out options
    $self->{cpan} = $config->cpan_user eq '<none>' ? 0 : 1;
    $self->{sf}   = $config->sf_user   eq '<none>' ? 0 : 1;
    $self->{passive_ftp} = $config->passive_ftp =~ /^y(es)?/ ? 1 : 0;

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
  
    # Make sure we have the right passwords
    if ( $self->{cpan} ) {
	$self->{cpan_pass} = $self->getpass( "CPAN_PASS" );
    }
    if ( $self->{sf} ) {
	$self->{sf_pass} = $self->getpass( "SF_PASS" );
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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# clean up the directory to get rid of old versions
sub clean {
    my $self = shift;
    print "Cleaning directory... ";
    
    unless( -e 'Makefile' ) {
        print " no Makefile---skipping\n";
        return;
    }

    my $messages = $self->run( "$self->{make} realclean 2>&1" );

    print "done\n";

    print $messages, DASHES, "\n" if $self->{debug};
} # clean

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# clean up the directory to get rid of old versions
sub perl {
    my $self = shift;
    print "Recreating make file... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $messages = $self->run( "$self->{perl} Makefile.PL 2>&1" );

    print "done\n";

    print $messages, DASHES, "\n" if $self->{debug};
} # perl

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# check the tests, which must all pass
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

    print $tests, DASHES, "\n" if $self->{debug};
} # test

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# XXX: make the distribution
sub dist {
    my $self = shift;
    print "Making dist... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $messages = $self->run( "$self->{make} tardist 2>&1" );

    unless( $self->{local} ){
        print ", guessing local distribution name" if $self->{debug};
        ($self->{local}) = $messages =~ /^\s*gzip.+?\b(\S+\.tar)\s*$/m;
        $self->{local} .= '.gz';
        $self->{remote} = $self->{local};
    }

    die "Couldn't guess distname from tardist output\n" unless $self->{local};
    die "Local file '$self->{local}' does not exist\n" unless -f $self->{local};

    print "done\n";

    print $messages, DASHES, "\n" if $self->{debug};
} # dist

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# XXX: check the distribution test
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

    print $tests, DASHES, "\n" if $self->{debug};
} # dist_test

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# check the state of the CVS repository
sub cvs {
    my $self = shift;
    last CVS unless -d 'CVS';

    print "Checking state of CVS... ";

    my @cvs_update = $self->run( "cvs -n update 2>&1" );
    chomp( @cvs_update );

    if( $? )
            {
            print join("\n", @cvs_update, "\n"), DASHES, "\n" if $self->{debug};
            die sprintf("\nERROR: cvs failed with non-zero exit status: %d\n\n" .
                    "Aborting release\n", $? >> 8);
            }

    my @cvs_states = qw( C M U P A ? );
    my %cvs_state;
    my %message    = (
            C   => 'These files have conflicts',
            M   => 'These files have not been checked in',
            U   => 'These files need to be updated',
            P   => 'These files need to be patched',
            A   => 'These files were added but not checked in',
            '?' => q|I don't know about these files|,
            );

    foreach my $state ( @cvs_states ) {
            my $regex = qr/^\Q$state /;

            $cvs_state{$state} = [
                    map { my $x = $_; $x =~ s/$regex//; $x }
                    grep /$regex/, @cvs_update
                    ];
            }

    local $" = "\n\t";
    my $rule = "-" x 50;
    my $count;
    my $question_count;

    foreach my $key ( sort keys %cvs_state ) {
            my $list = $cvs_state{$key};
            next unless @$list;
            $count += @$list unless $key eq '?';
            $question_count += @$list if $key eq '?';

            print "\n\t$message{$key}\n\t$rule\n\t@$list\n";
            }

    die "\nERROR: CVS is not up-to-date ($count files): Can't release files\n"
            if $count;

    if( $question_count ) {
            print "\nWARNING: CVS is not up-to-date ($question_count files unknown); ",
                    "continue anwyay? [Ny] " ;
            die "Exiting\n" unless <> =~ /^[yY]/;
    }

    print "CVS up-to-date\n";

    print join("\n", @cvs_update, "\n"), DASHES, "\n" if $self->{debug};
} # cvs

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# upload the files to the FTP servers

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


    foreach my $site ( @Sites ) {
        print "Uploading to $site\n";
        my $ftp = Net::FTP->new( $site, Debug => $self->{debug}, Passive => $self->{passive_ftp} );

        $ftp->login( "anonymous", $config->cpan_user . '@cpan.org' );
        $ftp->pasv if $self->{passive_ftp};
        $ftp->binary;
        $ftp->cwd( "/incoming" );
        $ftp->put( $self->{local}, $self->{remote} );

        $ftp->quit;
    }
} # ftp_upload

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# claim the file in PAUSE
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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# tag the release
sub cvs_tag {
    my $self = shift;
    my $file = $self->{remote};
    my( $major, $minor ) = $file =~ /(\d+) \. (\d+(?:_\d+)?) (?:\. tar \. gz)? $/xg;
    my $tag = "RELEASE_${major}_$minor";
    print "Tagging release with $tag\n";

    system 'cvs', 'tag', $tag;

    if ( $? ) {
            # already uploaded, and tagging is not (?) essential, so warn, don't die
            warn sprintf(
                    "\nWARNING: cvs failed with non-zero exit status: %d\n",
                    $? >> 8
            );
    }

} # cvs_tag

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Do the SourceForge.net stuff

# SourceForge.net seems to know our path through the system
# Hit all the pages, collect the right cookies, etc

########################################################################
# authenticate
sub sf_login {
    my $self = shift;
    return unless $self->{sf};

    print "Logging in to SourceForge.net... ";

    my $cgi = CGI->new();
    my $request = HTTP::Request->new( POST =>
        'https://sourceforge.net/account/login.php' );
    $self->{cookies}->add_cookie_header( $request );

    $cgi->param( 'return_to', '' );
    $cgi->param( 'form_loginname', $self->{config}->sf_user );
    $cgi->param( 'form_pw', $self->{sf_pass} );
    $cgi->param( 'stay_in_ssl', 1 );
    $cgi->param( 'login', 'Login With SSL' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->content( $cgi->query_string );

    $request->header( "Referer", "http://sourceforge.net/account/login.php" );

    print $request->as_string, DASHES, "\n" if $self->{debug};

    my $ua = $self->{ua};
    my $response = $ua->request( $request );
    $self->{cookies}->extract_cookies( $response );

    print $response->headers_as_string, DASHES, "\n" if $self->{debug};

    if( $response->code == 302 ) {
        my $location = $response->header('Location');
        print "Location is $location\n" if $self->{debug};
        my $request = HTTP::Request->new( GET => $location );
        $self->{cookies}->add_cookie_header( $request );
        print $request->as_string, DASHES, "\n" if $self->{debug};
        $response = $ua->request( $request );
        print $response->headers_as_string, DASHES, "\n" if $self->{debug};
        $self->{cookies}->extract_cookies( $response );
    }

    my $content = $response->content;
    $content =~ s|.*<!-- begin SF.net content -->||s;
    $content =~ s|Register New Project.*||s;

    print $content if $self->{debug};

    my $sf_user = $self->{config}->sf_user;
    if( $content =~ m/welcomes.*$sf_user/i ) {
        print "Logged in!\n";
    } else {
        print "Not logged in! Aborting\n";
        exit;
    }
} # sf_login

########################################################################
# visit the Quick Release System form
sub sf_qrs {
    my $self = shift;
    return unless $self->{sf};

    my $request = HTTP::Request->new( GET =>
        'https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=' . $self->{config}->sf_group_id
    );
    $self->{cookies}->add_cookie_header( $request );
    print $request->as_string, DASHES, "\n" if $self->{debug};
    my $response = $self->{ua}->request( $request );
    print $response->headers_as_string,  DASHES, "\n" if $self->{debug};
    $self->{cookies}->extract_cookies( $response );
} # sf_qrs

########################################################################
# release the file
sub sf_release {
    my $self = shift;
    return unless $self->{sf};

    my @time = localtime();
    my $date = sprintf "%04d-%02d-%02d", $time[5] + 1900, $time[4] + 1, $time[3];

    print "Connecting to SourceForge.net QRS... ";
    my $cgi = CGI->new();
    my $request = HTTP::Request->new( POST => 'https://sourceforge.net/project/admin/qrs.php' );
    $self->{cookies}->add_cookie_header( $request );

    $cgi->param( 'MAX_FILE_SIZE', 1000000 );
    $cgi->param( 'package_id', $self->{config}->sf_package_id  );
    $cgi->param( 'release_name', $self->{release} );
    $cgi->param( 'release_date',  $date );
    $cgi->param( 'status_id', 1 );
    $cgi->param( 'file_name',  $self->{remote} );
    $cgi->param( 'type_id', $self->{config}->sf_type_id || 5002 );
    $cgi->param( 'processor_id', $self->{config}->sf_processor_id || 8000 );
    $cgi->param( 'release_notes', get_readme() );
    $cgi->param( 'release_changes', get_changes() );
    $cgi->param( 'group_id', $self->{config}->sf_group_id );
    $cgi->param( 'preformatted', 1 );
    $cgi->param( 'submit', 'Release File' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->content( $cgi->query_string );

    $request->header( "Referer",
        "https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=" . $self->{config}->sf_group_id
    );
    print $request->as_string, "\n", DASHES, "\n" if $self->{debug};

    my $response = $self->{ua}->request( $request );
    print $response->headers_as_string, "\n", DASHES, "\n" if $self->{debug};

    my $content = $response->content;
    $content =~ s|.*Database Admin.*?<H3><FONT.*?>\s*||s;
    $content =~ s|\s*</FONT></H3>.*||s;

    print "$content\n" if $self->{debug};
    print "File Released\n";
} # sf_release


sub get_readme {
        open my $fh, '<README' or return '';
        my $data = do {
                local $/;
                <$fh>;
        };
        return $data;
}

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

sub run {
    my ($self, $command) = @_;
    print "$command\n" if $self->{debug};
    return `$command`;
};

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
