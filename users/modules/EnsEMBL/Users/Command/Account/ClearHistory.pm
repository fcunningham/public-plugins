=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Users::Command::Account::ClearHistory;

use strict;

use base qw(EnsEMBL::Users::Command::Account);

sub process {
  my $self    = shift;
  my $user    = $self->hub->user;
  my $object  = $self->hub->param('object');

  $_->delete for $object ? grep($_->object eq $object, @{$user->histories}) : @{$user->histories};
}

1;