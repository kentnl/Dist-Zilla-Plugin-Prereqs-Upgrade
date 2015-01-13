use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Upgrade;

our $VERSION = '0.001000';

# ABSTRACT: Upgrade existing prerequisites in place

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose;

__PACKAGE__->meta->make_immutable;
no Moose;

1;

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
