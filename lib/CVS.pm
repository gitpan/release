package Module::Release::CVS;

=head1 NAME

Module::Release::CVS - Methods for committing packages to CVS.

=head1 SYNOPSIS

Right now, there are no user-servicable parts inside.  However, this
has been split out like this so that there can be in the future.

=head1 VERSION

Version 0.22

    $Header: /cvsroot/brian-d-foy/release/lib/CVS.pm,v 1.1 2004/09/02 01:38:49 comdog Exp $

=cut

our $VERSION = '0.23';
our $KEY     = 'cvs';

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


=head2 C<check_cvs()>

Check the state of the CVS repository

=cut

sub check_cvs {
    my $self = shift;
    return unless -d 'CVS';

    print "Checking state of CVS... ";

    my $cvs_update = $self->run( "cvs -n update 2>&1" );

    if( $? )
            {
            die sprintf("\nERROR: cvs failed with non-zero exit status: %d\n\n" .
                    "Aborting release\n", $? >> 8);
            }

    my %message    = (
            C   => 'These files have conflicts',
            M   => 'These files have not been checked in',
            U   => 'These files need to be updated',
            P   => 'These files need to be patched',
            A   => 'These files were added but not checked in',
            '?' => q|I don't know about these files|,
            );
    my @cvs_states = keys %message;

    my %cvs_state;
    foreach my $state ( @cvs_states ) {
        $cvs_state{$state} = [ $cvs_update =~ /^\Q$state\E (.+)/m ];
    }

    my $rule = "-" x 50;
    my $count;
    my $question_count;

    foreach my $key ( sort keys %cvs_state ) {
            my $list = $cvs_state{$key};
            next unless @$list;
            $count += @$list unless $key eq '?';
            $question_count += @$list if $key eq '?';

	    local $" = "\n\t";
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
} # cvs


=head2 C<cvs_tag()>

Tag the release in local CVS

=cut

sub cvs_tag {
    my $self = shift;
    return unless -d 'CVS';

    my $tag = $self->make_cvs_tag;
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

=head2 C<make_cvs_tag()>

By default, examines the name of the remote file
(i.e. F<Foo-Bar-0.04.tar.gz>) and constructs a CVS tag like
C<RELEASE_0_04> from it.  Override this method if you want to use a
different tagging scheme.

=cut

sub make_cvs_tag {
    my $self = shift;
    my( $major, $minor ) = $self->{remote} =~ /(\d+) \. (\d+(?:_\d+)?) (?:\. tar \. gz)? $/xg;
    return "RELEASE_${major}_${minor}";
}


$KEY;

__END__
