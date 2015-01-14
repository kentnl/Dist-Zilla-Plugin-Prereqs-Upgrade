use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Upgrade;

our $VERSION = '0.001000';

# ABSTRACT: Upgrade existing prerequisites in place

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has with );
use Scalar::Util qw( blessed );

with 'Dist::Zilla::Role::PrereqSource';

sub _defaulted {
  my ( $name, $type, $default, @rest ) = @_;
  return has $name, is => 'ro', isa => $type, init_arg => '-' . $name, lazy => 1, default => $default, @rest;
}

sub _builder {
  my ( $name, $type, @rest ) = @_;
  return has $name, is => 'ro', isa => $type, init_arg => '-' . $name, 'lazy_build' => 1, @rest;
}

has 'modules' => (
  is       => 'ro',
  isa      => 'HashRef[Str]',
  init_arg => '-modules',
  required => 1,
  traits   => [qw( Hash )],
  handles  => {
    '_user_wants_upgrade_on' => 'exists',
    '_wanted_minimum_on' => 'get',
  },
);

_defaulted 'applyto_phase'   => 'ArrayRef[Str]' => sub { [qw(build test runtime configure develop)] };
_defaulted 'target_relation' => 'Str'           => sub { 'recommends' };
_defaulted 'source_relation' => 'Str'           => sub { 'requires' };

_builder 'applyto_map' => 'ArrayRef[Str]';
_builder _applyto_map_pairs => 'ArrayRef[HashRef]', init_arg => undef;

__PACKAGE__->meta->make_immutable;
no Moose;

sub mvp_multivalue_args { return qw(-applyto_map -applyto_phase) }

sub register_prereqs {
  my ($self)  = @_;
  my $zilla   = $self->zilla;
  my $prereqs = $zilla->prereqs;
  my $guts = $prereqs->cpan_meta_prereqs->{prereqs} || {};

  for my $applyto ( @{ $self->_applyto_map_pairs } ) {
    $self->_register_applyto_map_entry( $applyto, $guts );
  }
  return $prereqs;
}

sub BUILDARGS {
  my ( $self, $config, @extra ) = @_;
  if ( 'HASH' ne ( ref $config || q[] ) or scalar @extra ) {
    $config = { $config, @extra };
  }
  my $modules = {};
  for my $key ( keys %{$config} ) {
    next if $key =~ /\A-/msx;
    next if $key eq 'plugin_name';
    next if blessed $config->{$key};
    next if $key eq 'zilla';
    $modules->{$key} = delete $config->{$key};
  }
  return { '-modules' => $modules, %{$config} };
}
sub _register_applyto_map_entry {
  my ( $self, $applyto, $prereqs ) = @_;
  my ( $phase, $rel );
  $phase = $applyto->{source}->{phase};
  $rel   = $applyto->{source}->{relation};
  my $targetspec = {
    phase => $applyto->{target}->{phase},
    type  => $applyto->{target}->{relation},
  };
  $self->log_debug( [ 'Processing %s.%s => %s.%s', $phase, $rel, $applyto->{target}->{phase}, $applyto->{target}->{relation} ] );
  if ( not exists $prereqs->{$phase} or not exists $prereqs->{$phase}->{$rel} ) {
    $self->log_debug( [ 'Nothing in %s.%s', $phase, $rel ] );
    return;
  }

  my $reqs = $prereqs->{$phase}->{$rel}->as_string_hash;

  for my $module ( keys %{$reqs} ) {
    next unless $self->_user_wants_upgrade_on($module);
    my $v = $self->_wanted_minimum_on($module);

    # Get the original requirement and see if applying the new minimum changes anything
    my $fake_target = $prereqs->{$phase}->{$rel}->clone;
    my $old_string  = $fake_target->as_string_hash->{ $module };
    $fake_target->add_string_requirement( $module, $v );
    # Dep changed in the effective source spec
    next unless $fake_target->as_string_hash->{ $module } ne $old_string;

    $self->log_debug( [ "%s.%s, Setting minimum for %s to %s", $targetspec->{phase}, $targetspec->{type}, $module, "$v" ] );

    # Apply the change to the target spec to to it being an upgrade.
    $self->zilla->register_prereqs( $targetspec, $module, $fake_target->as_string_hash->{$module} );
  }
  return $self;
}

sub _build_applyto_map {
  my ($self) = @_;
  my (@out);
  for my $phase ( @{ $self->applyto_phase } ) {
    push @out, sprintf '%s.%s = %s.%s', $phase, $self->source_relation, $phase, $self->target_relation;
  }
  return \@out;
}

# _Pulp__5010_qr_m_propagate_properly
## no critic (Compatibility::PerlMinimumVersionAndWhy)
my $re_phase    = qr/configure|build|runtime|test|develop/msx;
my $re_relation = qr/requires|recommends|suggests|conflicts/msx;

my $combo = qr/(?:$re_phase)[.](?:$re_relation)/msx;

sub _parse_map_token {
  my ( $self,  $token )    = @_;
  my ( $phase, $relation ) = $token =~ /\A($re_phase)[.]($re_relation)/msx;
  unless ( defined $phase and defined $relation ) {
    return $self->log_fatal( [ '%s is not in the form <phase.relation>', $token ] );
  }
  return { phase => $phase, relation => $relation, };
}

sub _parse_map_entry {
  my ( $self,   $entry )  = @_;
  my ( $source, $target ) = $entry =~ /\A\s*($combo)\s*=\s*($combo)\s*\z/msx;
  unless ( defined $source and defined $target ) {
    return $self->log_fatal( [ '%s is not a valid entry for -applyto_map', $entry ] );
  }
  return {
    source => $self->_parse_map_token($source),
    target => $self->_parse_map_token($target),
  };
}

sub _build__applyto_map_pairs {
  my ($self) = @_;
  return [ map { $self->_parse_map_entry($_) } @{ $self->applyto_map } ];
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Prereqs::Upgrade - Upgrade existing prerequisites in place

=head1 VERSION

version 0.001000

=head1 DESCRIPTION

This allows you to automatically upgrade selected prerequisites
to selected versions, if, and only if, they're already prerequisites.

This is intended to be used to compliment C<[AutoPrereqs]> without adding dependencies.

  [AutoPrereqs]

  [Prereqs::Upgrade]
  Moose = 2.0 ; Moose is upgraded to 2.0 if its a prereq, but ignored otherwise.

This is intended to be especially helpful in C<PluginBundle>'s where one may habitually
always want a certain version of a certain dependency every time they use it, but don't want to be burdened
with remembering to encode that version of it.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
