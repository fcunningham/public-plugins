# $Id$

package EnsEMBL::Web::ImageConfig::Genoverse;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init_genoverse {
  my $self = shift;
  
  $self->set_parameter('component', $self->hub->viewconfig->component) if $self->hub->viewconfig;
  $self->create_menus('options');
  $self->add_option('auto_height', undef, undef, undef, 'off')->set('menu', 'no');
  
  $self->modify_configs($self->{'transcript_types'},                        { genoverse => { type       => 'Gene'                                                                                           } });
  $self->modify_configs([ 'misc_feature'                                 ], { genoverse => { type       => 'Clone'                                                                                          } });
  $self->modify_configs([ 'contig'                                       ], { genoverse => { type       => 'Contig',              cache          => 'chr'                                                   } });
  $self->modify_configs([ 'assembly_exception_core', 'annotation_status' ], { genoverse => { type       => 'Patch',               cache          => 'chr'                                                   } });
  $self->modify_configs([ 'synteny'                                      ], { genoverse => { type       => 'Synteny',             cache          => 'chr'                                                   } });
  $self->modify_configs([ 'seq'                                          ], { genoverse => { type       => 'Sequence',            bin_size       => 5e4,   all_features  => 1                               } });  
  $self->modify_configs([ 'codonseq'                                     ], { genoverse => { type       => 'TranslatedSequence',  bin_size       => 6e4,   all_features  => 1                               } });
  $self->modify_configs([ 'variation', 'somatic_mutation'                ], { genoverse => { type       => 'Variation',           threshold      => 1e5,   bin_size      => 1e6                             } });
  $self->modify_configs([ map "${_}structural_variation", '', 'somatic_' ], { genoverse => { type       => 'StructuralVariation', threshold      => 5e6                                                     } });
  $self->modify_configs([ 'variation_feature_structural_smaller'         ], { genoverse => { type       => 'StructuralVariation', threshold      => 5e6,   bin_size      => 1e6                             } });
  $self->modify_configs([ 'reg_features'                                 ], { genoverse => { type       => 'RegulatoryFeature',   threshold      => 2.5e6, bin_size      => 1e6                             } });
  $self->modify_configs([ 'seg_features'                                 ], { genoverse => { type       => 'SegmentationFeature', threshold      => 1e6,   bin_size      => 2e6                             } });
  $self->modify_configs([ 'codons'                                       ], { genoverse => { autoHeight => 'force',               bin_size       => 6e4,   featureHeight => 3,                              } });
  $self->modify_configs([ 'chr_band_core'                                ], { genoverse => { autoHeight => 'force',               cache          => 'chr', allData       => JSON::true, labels => 'overlay' } });
  $self->modify_configs([ 'marker'                                       ], { genoverse => { bump       => 'labels',              maxLabelRegion => 5e4                                                     } });
  $self->modify_configs([ 'scalebar', 'ruler', 'draggable', 'info'       ], { genoverse => { remove     => 1                                                                                                } });
  
  my $info  = $self->get_node('information');
  my $order = 1e6;
  
  # Super-horrible way of getting legend info from track ids
  for (grep { $_->get('menu') ne 'no' && $_->id =~ /legend/ } $info ? $info->nodes : ()) {
    (my $type = $_->id) =~ s/(fg_|_legend)//g;
    $type =~ s/features$/feature/;
    $type =~ s/_(\w)/uc $1/ge;
    $_->set('genoverse', { type => 'Legend', featureType => ucfirst $type, order => $order++ });
  }
  
  my $marker = $self->get_node('marker');
  $_->set('genoverse', { bump => JSON::true, labels => 'overlay' }) for grep $_->id =~ /^qtl_/, $marker ? $marker->nodes : ();
}

# All functions from here on are generic modifications
sub glyphset_configs {
  my $self = shift;
  
  if (!$self->{'ordered_tracks'}) {
    my %stranded;
    
    $self->SUPER::glyphset_configs;
    
    push @{$stranded{$_->id}}, $_ for @{$self->{'ordered_tracks'}};
    
    foreach (map scalar @$_ == 2 ? @$_ : (), values %stranded) {
      my %config = %{$_->get('genoverse') || {}};
      push @{$config{'inherit'}}, 'Stranded';
      $_->set('genoverse', \%config);
    }
  }
  
  return $self->{'ordered_tracks'};
}

# Don't reset auto height setting
sub reset {
  my $self = shift;
  
  if ($self->hub->input->param('reset') ne 'track_order') {
    my $user_data = $self->get_user_settings;
    
    foreach my $track (keys %$user_data) {
      foreach (keys %{$user_data->{$track}}) {
        next if /^(display|track_order)$/;
        $self->altered = 1 if delete $user_data->{$track}{$_};
      }
    }
  }
  
  $self->SUPER::reset;
}

1;