package Module::Release::Registry;
use strict;

=head1 NAME

Module::Release::Registry - knowledge about Module::Release plug-ins

=head1 SYNOPSIS

	use Module::Release::Registry;
	
	my $registry    = Module::Release::Registry->new();
	
	my $key         = 'cvs'; # or 'sf', 'pause', and so on
	my $module_name = $registry->get_plugin( $key );
	
=head1 DESCRIPTION

=head2 Pre-defined keys

=over 4 

=item cvs - Module::Release::CVS

Commit to CVS

=item sf - Module::Release::SourceForge

Upload and claim in SourceForge project

=item pause - Module::Release::PAUSE

Upload and claim in Perl Authors Upload SErver

=item useperl - Module::Release::UsePerl

Send announcements to your use.perl journal

=item clpa - Module::Release::cpla

Send announcements to comp.lang.perl.announce

=back

=head2 Methods

=over 4

=cut
use base qw(Exporter);
use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS);

use Carp qw(carp);

@EXPORT_OK = qw( KEY_DOES_NOT_EXIST KEY_UNDEFINED MODULE_NOT_FOUND
	MODULE_LOADED KEY_EXISTS KEY_ADDED);
%EXPORT_TAGS = (
	all       => \@EXPORT_OK,
	constants => \@EXPORT_OK,
	);
	
$VERSION   = 1.0;

my $singleton = bless {
	cvs      => 'Module::Release::CVS',
	sf       => 'Module::Release::SourceForge',
	pause    => 'Module::Release::PAUSE',
	useperl  => 'Module::Release::UsePerl',
	clpa     => 'Module::Release::cpla',
	}, __PACKAGE__;

sub KEY_DOES_NOT_EXIST { -1 }
sub KEY_UNDEFINED      { -2 }
sub MODULE_NOT_FOUND   { -3 }
sub MODULE_LOADED      {  1 }
sub KEY_EXISTS         {  2 }
sub KEY_ADDED          {  3 }

=item new()

Returns a registry object that is a singleton. Make as many objects
as you like because they are all the same.

=cut

sub new { return $singleton };

=item get_plugin( KEY )

Turn a plugin key into its module name. The key name is defined by the
available plugins and those defined by this module.

=cut

sub get_plugin 
	{ 
	my $self = shift;
	my $key  = lc shift;
	
	unless( exists $self->{$key} )
		{
		carp "Registry key [$key] does not exist";
		return KEY_DOES_NOT_EXIST;
		}
	elsif( not defined $self->{$key} )
		{
		carp "Registry key [$key] is not defined";
		return KEY_UNDEFINED;
		}
		
	my $module = "$$self{$key}";

	unless( eval "require $module" )
		{
		carp "Could not load $module\n$@";
		return MODULE_NOT_FOUND;
		}
	
	return $module;
	}

=item add_plugin( KEY, MODULE )

=cut

sub add_plugin
	{
	my $self = shift;
	my( $key, $module ) = @_;
		
	if( exists $self->{$key} )
		{
		carp "Registry key [$key] already exists for []";
		return KEY_EXISTS;
		}
	elsif( not eval "require $module" )
		{
		carp "Could not find module [$module]";
		return MODULE_NOT_FOUND;
		}
	
	$self->{$key} = $module;

	return KEY_ADDED;
	}
=back

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	http://sourceforge.net/projects/brian-d-foy/
	
If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHORS

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2004 brian d foy.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;