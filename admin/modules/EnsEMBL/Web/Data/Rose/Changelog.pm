package EnsEMBL::Web::Data::Rose::Changelog;

### NAME: EnsEMBL::Web::Data::Rose::Changelog;

### STATUS: Under Development

### DESCRIPTION:

use strict;
use warnings;
no warnings qw(uninitialized);

use EnsEMBL::Data::Manager::Changelog;
use base qw(EnsEMBL::Web::Data::Rose);

sub _set_relationships {
  my $self = shift;
  $self->set_edit_tracking;
}

sub fetch_all {
  my $self = shift;
  my $objects = EnsEMBL::Data::Manager::Changelog->get_changelogs(
    query => [
      release_id => $self->hub->species_defs->ENSEMBL_VERSION,
    ],
    sort_by => 'team',
  );
  $self->data_objects(@$objects);
  return $objects;
}

1;
