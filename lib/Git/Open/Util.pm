use strict;
use warnings;
package Git::Open::Util;
use Moose;

has remote_url => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        my $git_url = `git ls-remote --get-url`;

        $git_url =~ s/\n//;
        $git_url =~ s/:/\//; # Change : to /
        $git_url =~ s/^git@/http:\/\//; # Change protocal to http
        $git_url =~ s/\.git$//; # Remove .git at the end
        return $git_url;
    }
);

has current_branch => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        my $current_branch = `git symbolic-ref --short HEAD`;
        return $current_branch;
    }
);

has service => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        $self->remote_url =~ m|//([a-z]+)\.|;
        return $1;
    }
);

sub generate_url {
    my $self = shift;
    my $args = shift;

    my $suffix = '';
    if( defined $args->{compare} ) {
        if( $args->{compare} eq '' ) {
            $suffix = 'compare';
        }else {
            my @branches = split( /-/, $args->{compare} );
            $suffix = $self->_url_pattern( 'compare' );
            foreach my $i ( 0..1 ) {
                $suffix =~ s/_$i/$branches[$i]/;
            }
        }
    }elsif ( defined $args->{branch} ) {
        my $branch = $args->{branch} || $self->current_branch;
        $suffix = $self->_url_pattern( 'branch' );
        $suffix =~ s/_0/$branch/;
    }

    return $self->remote_url.'/'.$suffix;
};

sub _url_pattern {
    my $self = shift;
    my $view = shift;
    my $mapping_pattern = {
        github => {
            compare => 'compare/_0..._1',
            branch => 'tree/_0'
        },
        bitbucket => {
            compare => 'compare/_0.._1',
            branch => 'src?at=_0'
        }
    };

    return $mapping_pattern->{$self->service}->{$view};
};

1;

