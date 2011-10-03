package EnsEMBL::Selenium;
use strict;
use Test::More;
use base 'Test::WWW::Selenium';

# return user defined timeout, or a default
sub _timeout {  return $_[0]->{_timeout} || 5000 }

# Wait until there are no ajax loading indicators or errors shown in the page
# Loading indicators are only shown if loading takes >500ms so need to pause before we start checking
sub ensembl_wait_for_ajax {
  my ($self, $timeout, $pause) = @_;
  
  $pause ||= 500;  
 
  $self->pause($pause)
  and $self->wait_for_condition(
    'var $ = selenium.browserbot.getCurrentWindow().jQuery;
    !($(".ajax_load").length || $(".ajax_error").length || $(".syntax-error").length)',
    $timeout || $self->_timeout
  ); 
}

# Wait for a 200 Ok response, then wait until all ajax loaded
# For some reason the Ensembl 'Internal Server Error' page is mistaken for a 200 Ok, so also check for this
sub ensembl_wait_for_page_to_load {
  my ($self, $timeout) = @_;
  
  $timeout ||= $self->_timeout;

  $self->wait_for_page_to_load($timeout)
  and ok($self->get_title !~ /Internal Server Error|404 error/i, 'No Internal or 404 Server Error')
  and $self->ensembl_wait_for_ajax($timeout);
}

# Open a ZMenu by title for the given imagemap panel or if title not provided will get the coords based on the area tag for the given imagemap panel (id of div for class js_panel)
# e.g. $sel->ensembl_open_zmenu('contigviewtop', 'ASN2') or $sel->ensembl_open_zmenu('GenomePanel')
sub ensembl_open_zmenu {
  my ($self, $panel, $title) = @_;
  
  $title ? my $tag = 'area[title^=#$title]' : my $tag = 'area[href^=#vdrag]'; 

  $self->run_script(qq/
    var coords = \$('$tag', '#$panel').attr('coords').split(',');
    Ensembl.PanelManager.panels.$panel.makeZMenu({pageX:0, pageY:0}, {x:coords[0], y:coords[1]});
  /)
  and $self->ensembl_wait_for_ajax;
}

# Open a ZMenu by position on the given imagemap panel
# e.g. $sel->ensembl_open_zmenu_at('contigviewtop', '160,100')
sub ensembl_open_zmenu_at {
  my ($self, $panel, $pos) = @_;
  
  my ($x, $y) = split /,/, $pos;  
  $self->run_script("Ensembl.PanelManager.panels['$panel'].makeZMenu({pageX:0, pageY:0}, {x:$x, y:$y});")
  and $self->ensembl_wait_for_ajax;
}

# Click links on ensembl but can only be used for link opening page, not ajax popup
# e.g. $sel->ensembl_click_links(["link=Tool","link=Human"], '5000');
sub ensembl_click_links {
  my ($self, $links, $timeout) = @_;
  
  if (ref $links eq 'ARRAY') {
    foreach my $link (@{$links}) {
      my ($locator, $timeout) = ref $link eq 'ARRAY' ? @$link : ($link, $timeout || $self->_timeout);
      if ($self->is_element_present($locator)) {
        print "$locator FAILED \n\n" unless $self->click_ok($locator) and $self->ensembl_wait_for_page_to_load_ok($timeout);
      } else {
        print "***missing*** $locator\n";
      }
    }
  }
}

# check if all the images (ajax one) on the page have been loaded successfully
sub ensembl_images_loaded {
  my ($self) = @_;
  
  $self->run_script(qq{
    var complete = 0;
     jQuery('img.imagemap').each(function () {
       if (this.complete) {
         complete++;
       }
     });     
     if (complete === Ensembl.images.total) {
       jQuery('body').append("<p>All images loaded successfully</p>");
     }
  });
  $self->is_text_present_ok("All images loaded successfully");  
}

1;