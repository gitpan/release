package Module::Release::SourceForge;

=head1 NAME

Module::Release::SourceForge - Methods for releasing packages to SourceForge.

=head1 SYNOPSIS

Right now, there are no user-servicable parts inside.  However, this
has been split out like this so that there can be in the future.

=head1 VERSION

Version 0.22

    $Header: /cvsroot/brian-d-foy/release/lib/SourceForge.pm,v 1.1 2004/09/02 01:38:49 comdog Exp $

=cut

our $VERSION = '0.23';

use strict;
use Config;
use CGI qw(-oldstyle_urls);
use ConfigReader::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Net::FTP;
use File::Spec;

use constant DASHES => "-" x 73;


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


# SourceForge.net seems to know our path through the system
# Hit all the pages, collect the right cookies, etc

=head2 C<sf_login()>

Authenticate with Sourceforge

=cut

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

=head2 C<sf_qrs()>

Visit the Quick Release System form

=cut

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

=head2 C<sf_release()>

Release the file

=cut

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
