=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::Element::ToolButtons;

use strict;
use warnings;

use previous qw(init);

sub init {
  my $self        = shift;
  my $controller  = $_[0];
  my $hub         = $controller->hub;
  my $object      = $controller->object;

  $self->PREV::init(@_);

  # can not share any tools pages via urls
  if($hub->type eq 'Tools') {
    $_->{'class'} = sprintf 'disabled %s', $_->{'class'} || '' for grep {$_->{'caption'} eq 'Share this page'} @{$self->entries};
  }
}

1;
