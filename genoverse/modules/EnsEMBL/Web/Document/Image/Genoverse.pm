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

package EnsEMBL::Web::Document::Image::Genoverse;

use strict;

use JSON qw(to_json);

use parent qw(EnsEMBL::Web::Document::Image);

sub new {
  my ($class, $args) = @_;
  $args->{'species_defs'}  = $args->{'hub'}->species_defs;
  $args->{'image_configs'} = [ $args->{'image_config'} ];
  $args->{'height'}        = 1e9;
  $args->{'toolbars'}{$_}  = $args->{'image_config'}->toolbars->{$_} for qw(top bottom);
  return bless $args, $class;
}

sub has_moveable_tracks {
  return 1;
}

sub get_tracks {
  my $self         = shift;
  my $hub          = $self->{'hub'};
  my $image_config = $self->{'image_config'};
  my (@tracks, %reverse_order);
  
  foreach (map [ $_->get('display'), $_ ], @{$image_config->glyphset_configs}) {
    next if $_->[0] eq 'off';
    
    my ($display, $track) = @$_;
    my %genoverse = %{$track->get('genoverse') || {}};
    
    next if $genoverse{'remove'};
    
    my $glyphset  = $track->get('glyphset');
    my $classname = "EnsEMBL::Draw::GlyphSet::$glyphset";
    
    next unless $hub->dynamic_use($classname);
    
    my $glyphset_object = $classname->new({ config => $image_config, my_config => $track, display => $display });
    
    my $config = {
      id           => $track->id,
      name         => $track->get('caption'),
      order        => $track->get('order') + 0,
      depth        => $glyphset_object->depth,
      labelOverlay => $glyphset_object->label_overlay,
      url          => $hub->url({ type => 'Genoverse', action => 'fetch_features', function => $glyphset, config => $image_config->{'type'}, __clear => 1 }),
      urlParams    => { id => $track->id },
      %genoverse
    };
    
    my $height = $track->get('user_height');
    
    $config->{'user'}{'height'}     = int $height                    if defined $height;
    $config->{'user'}{'autoHeight'} = JSON::true                     if $track->get('auto_height');
    $config->{'featureHeight'}      = $track->get('height')          if $track->get('height');
    $config->{'threshold'}          = $track->get('threshold') * 1e3 if $track->get('threshold');
    $config->{'renderer'}           = $display                       if scalar @{$track->get('renderers')} > 4;
    
    $reverse_order{$config->{'id'}} = $config->{'order'} + 0 and next if $track->get('strand') =~ /[bx]/ && $track->get('drawing_strand') eq 'r';
    
    delete $config->{$_} for grep !defined $config->{$_}, keys %$config;
    
    push @tracks, $config;
  }
  
  $_->{'orderReverse'} = $reverse_order{$_->{'id'}} for grep exists $reverse_order{$_->{'id'}}, @tracks;
  
  return \@tracks;
}

sub render {
  my $self         = shift;
  my $slice        = $self->{'slice'};
  my $image_config = $self->{'image_config'};
  my ($top_toolbar, $bottom_toolbar) = $self->render_toolbar;
  
  my $config = {
    tracks          => [ { type => 'Scaleline' }, { type => 'Scalebar', stranded => 1 }, @{$self->get_tracks} ],
    trackAutoHeight => $image_config->get_option('auto_height') ? JSON::true : JSON::false,
    wheelAction     => $image_config->get_parameter('zoom') eq 'no' ? JSON::false : 'zoom',
    minSize         => $image_config->get_parameter('min_size') + 0,
    flanking        => $self->hub->param('flanking') + 0,
    chr             => $slice->seq_region_name,
    start           => $slice->start + 0,
    end             => $slice->end   + 0,
    chromosomeSize  => $slice->seq_region_length + 0,
  };
  
  my $html = sprintf('
    <input type="hidden" class="panel_type" value="Genoverse" />
    <input type="hidden" class="image_config" value="%s" />
    <script>Ensembl.genoverseConfig = %s;</script>
    <div class="image_container canvas" style="width:%spx">
      %s
      <div class="drag_select">
        <div class="canvas_container"></div>
        %s
      </div>
      %s
    </div>',
    $image_config->{'type'},
    to_json($config),
    $self->{'image_width'},
    $top_toolbar,
    $self->hover_labels,
    $bottom_toolbar
  );
  
  $html .= '<span class="hidden drop_upload"></span>' if $image_config->get_node('user_data');

  return $html;
}

sub render_toolbar {
  my $self            = shift;
  my $hub             = $self->hub;
  my $image_config    = $self->{'image_config'};
  my $zoom            = $image_config->get_parameter('zoom') ne 'no';
  my ($top, $bottom)  = $self->SUPER::render_toolbar;
  my $autoheight      = $image_config->get_option('auto_height');
  my $autoheight_url  = { 'type' => 'Genoverse', 'action' => 'auto_track_heights',  'function' => '', 'image_config' => $image_config->{'type'} };
  my $resetheight_url = { 'type' => 'Genoverse', 'action' => 'reset_track_heights', 'function' => '', 'image_config' => $image_config->{'type'} };

  my $controls = sprintf('
    <div class="genoverse_controls%s">
      <div>
        <span class="label">Scroll:</span>
        <div class="button"><button class="scroll scroll_left" title="Scroll left"></button></div>
        <div class="right button"><button class="scroll scroll_right" title="Scroll right"></button></div>
      </div>
      <div class="%s">
        <span class="label">Zoom:</span>
        <div class="button"><button class="zoom_in" title="Zoom in"></button></div>
        <div class="right button"><button class="zoom_out" title="Zoom out"></button></div>
      </div>
      <div>
        <span class="label">Track height:</span>
        <div class="button%s"><button class="auto_height" title="Fix track heights" value="%s"></button></div>
        <div class="right button%s"><button class="auto_height on" title="Auto-adjust track heights" value="%s"></button></div>
        <div class="right button"><button class="reset_height" title="Reset track heights" value="%s"></button></div>
      </div>
      <div>
        <span class="label">Drag/Select:</span>
        <div class="button selected"><button class="dragging on" title="Scroll to a region"></button></div>
        <div class="right button"><button class="dragging" title="Select a region"></button></div>
      </div>
      <div class="%s">
        <span class="label">Wheel:</span>
        <div class="button selected"><button class="wheel_zoom" title="Scroll the browser window"></button></div>
        <div class="right button"><button class="wheel_zoom on" title="Zoom in or out"></button></div>
      </div>
    </div>',
    $self->{'image_width'} < 800 ? ' narrow' : '',
    $zoom       ? '' : 'hidden',
    $autoheight ? '' : ' selected',
    $hub->url($autoheight_url),
    $autoheight ? ' selected' : '',
    $hub->url($autoheight_url),
    $hub->url($resetheight_url),
    $zoom       ? '' : 'hidden',
  );
  
  $bottom = '' unless $self->{'toolbars'}{'bottom'}; # setting height as 1e9 in render_toolbar forces bottom to be created, but it may not be required
  $_     .= $controls for grep $_, $top, $bottom;
  
  return ($top, $bottom);
}

sub hover_labels {
  my $self    = shift;
  my %filters = map { $_ => 1 } @_;
  my $img_url = $self->{'species_defs'}->img_url;
  my @labels  = values %{$self->{'image_config'}{'hover_labels'} || {}};
     @labels  = grep $filters{$_->{'class'}}, @labels if scalar keys %filters;
  my ($html, %done);
  
  foreach my $label (@labels) {
    next if $done{$label->{'class'}};
    
    my $desc = join '', map "<p>$_</p>", split /; /, $label->{'desc'};
    my $renderers;
    
    foreach (@{$label->{'renderers'}}) {
      $renderers .= sprintf(qq{
        <li class="$_->{'val'}%s">
          <a href="$_->{'url'}" class="config constant" rel="$label->{'component'}">
            <img src="${img_url}render/$_->{'val'}.gif" alt="$_->{'text'}" title="$_->{'text'}" />%s $_->{'text'}
          </a>
        </li>},
        $_->{'current'} ? (' current', qq{<img src="${img_url}tick.png" class="tick" alt="Selected" title="Selected" />}) : ('', '')
      );
    }
    
    $html .= sprintf(qq{
      <div class="hover_label floating_popup %s">
        <p class="header">%s</p>
        %s
        %s
        <img class="height" src="${img_url}blank.gif" alt="Height" title="" />
        %s
        <a href="$label->{'fav'}[1]" class="config constant favourite%s" rel="$label->{'component'}" title="Favourite track"></a>
        <a href="$label->{'off'}" class="config constant" rel="$label->{'component'}"><img src="${img_url}16/cross.png" alt="Turn track off" title="Turn track off" /></a>
        <div class="desc">%s</div>
        <div class="config">%s</div>
        <div class="height"><p class="auto">Set track to auto-adjust height</p><p class="fixed">Set track to fixed height</p></div>
        <div class="url">%s</div>
        <div class="spinner"></div>
      </div>},
      $label->{'class'},
      $label->{'header'},
      $label->{'desc'}     ? qq{<img class="desc" src="${img_url}16/info.png" alt="Info" title="Info" />}                                  : '',
      $renderers           ? qq{<img class="config" src="${img_url}16/setting.png" alt="Change track style" title="Change track style" />} : '',
      $label->{'conf_url'} ? qq{<img class="url" src="${img_url}16/link.png" alt="Link" title="URL to turn this track on" />}              : '',
      $label->{'fav'}[0]   ? ' selected' : '',
      $desc,
      $renderers           ? qq{<p>Change track style:</p><ul>$renderers</ul>}                                                : '',
      $label->{'conf_url'} ? qq{<p>Copy <a href="$label->{'conf_url'}">this link</a> to force this track to be turned on</p>} : ''
    );
  }
  
  return $html;
}

1;
