use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Upgrade;

our $VERSION = '0.001000';

# ABSTRACT: Upgrade existing prerequisites in place

# AUTHORITY

use Moose;

__PACKAGE__->meta->make_immutable;
no Moose;

1;

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
