# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/local/bin/perl

=pod
 Wrapper script for selenium tests. 
 Takes one argument (release number) plus two JSON configuration files:
 - configure connection and select which tests are run in a particular batch
 - configure species to test (optional)

 The purpose of the latter file is to remove dependency on the web code.
 Instead, a helper script is used to dump some useful parts of the
 web configuration, which should then be eyeballed to ensure it looks OK.

  Example of use:

  perl run_tests.pl --release=80 --config=link_checker.conf --species=release_80_species.conf
=cut

use strict;
use warnings;
no warnings 'uninitialized';

use FindBin qw($Bin);
use Getopt::Long;
use LWP::UserAgent;
use JSON;

use vars qw( $SERVERROOT );

BEGIN {
  $SERVERROOT = "$Bin/../../..";
  unshift @INC,"$SERVERROOT/../public-plugins/selenium/modules";  
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;    
}

my ($release, $config, $species);

GetOptions(
  'release=s' => \$release,
  'config=s'  => \$config,
  'species=s' => \$species,
);

die 'Please provide a configuration file!' unless $config;

## Read configurations
my ($conf_string, $spp_string);
{
  local $/;
  my $fh;
  open $fh, '<', "conf/$config";
  $conf_string .= $_ for <$fh>;
  close $fh;
  open $fh, '<', "conf/$species";
  $spp_string .= $_ for <$fh>;
  close $fh;
} 
my $CONF          = $conf_string ? from_json($conf_string)  : {};
my $SPECIES       = $spp_string ? from_json($spp_string) : {};

## Validate main configuration
unless ($CONF->{'host'}) {
  die "You must specify the selenium host, e.g. ???";
}

unless ($CONF->{'url'} && $CONF->{'url'} =~ /^http/) {
  die "You must specify a url to test against, eg. http://www.ensembl.org";
}

unless (($CONF->{'modules'} && scalar(@{$CONF->{'modules'}||[]}))
        || ($CONF->{'modules'} && scalar(@{$CONF->{'modules'}||[]}))) {
  die "You must specify at least one test module, eg. ['Generic']";
}

unless (ref($CONF->{'modules'}[0]) eq 'HASH' && $CONF->{'modules'}[0]{'tests'} && scalar(@{$CONF->{'modules'}[0]{'tests'}||[]})) {
  die "You must specify at least one test method, eg. ['homepage']";
}

$SPECIES = {'none'} unless keys %$SPECIES;

my $browser = $CONF->{'browser'}  || 'firefox';
my $port    = $CONF->{'port'}     || '4444';
my $timeout = $CONF->{'timeout'}  || 50000;
my $verbose = $CONF->{'verbose'}  || 0;

=pod
# check to see if the selenium server is online(URL returns OK if server is online).
my $ua = LWP::UserAgent->new(keep_alive => 5, env_proxy => 1);
$ua->timeout(10);
my $response = $ua->get("http://$host:$port/selenium-server/driver/?cmd=testComplete");
if($response->content ne 'OK') { 
  print "\nSelenium Server is offline or IP Address is wrong !!!!\n";
  exit;
}
=cut

## Basic config for test modules
my $test_config = {
                    url     => $CONF->{'url'},
                    host    => $CONF->{'host'},
                    port    => $port,
                    browser => $browser,
                    conf    => {
                                release => $CONF->{'release'},
                                timeout => $timeout,
                                },
                    verbose => $verbose,  
                  };


## Separate out the tests by species/non-species
my $test_suite = {
                  'non_species' => [],
                  'species'     => {},
                  };

foreach my $module (@{$CONF->{'modules'}}) {
  my $species = $module->{'species'} || [];
  if ($species eq 'all') {
  }
  elsif (scalar(@$species)) {
    foreach my $sp (@$species) {
      if ($test_suite->{'species'}{$sp}) {
        push @{$test_suite->{'species'}{$sp}}, $module;
      }
      else {
        $test_suite->{'species'}{$sp} = [$module];
      }
    }
  }
  else {
    push @{$test_suite->{'non_species'}}, $module,
  }
}

## Run any non-species-specific tests first 
foreach my $module (@{$test_suite->{'non_species'}}) {
  my $module_name = $module->{'name'};
  foreach my $test_set (@{$module->{'tests'}||[]}) {
    run_test($module_name, $test_config, $test_set);    
  }
}

## Loop through the relevant tests for each species
foreach my $sp (keys %{$test_suite->{'species'}}) {
  foreach my $module (@{$test_suite->{'species'}{$sp}}) {
    my $module_name = $module->{'name'};
    foreach my $test_set (@{$module->{'tests'}}) {
      $test_config->{'species'} = $species;
      run_test($module_name, $test_config, $test_set);    
    }
  }
}

print "TEST RUN COMPLETED\n\n";

################# SUBROUTINES #############################################

sub run_test {
  my ($module, $config, $tests) = @_;

  ## Try to use the package
  my $package = "EnsEMBL::Selenium::Test::$module";
  eval("use $package");
  if ($@) {
    write_to_log("TEST FAILED: Couldn't use $package\n$@");
    return;
  }
  my @test_names = keys @{$tests||[]};
  unless (@test_names) {
    write_to_log("TEST FAILED: No methods specified for test module $package");
    return;
  }

  my $object = $package->new(%{$config||{}});

  ## Run the tests
  foreach my $name (@test_names) {
    my $method = 'test_'.$name;
    if ($object->can($method)) {
      my $error = $object->$method($tests->{$name});
      write_to_log($error) if $error;
    }
    else {
      write_to_log("TEST FAILED: No such method $method in package $package");
    }
  }
}

sub write_to_log {
  my $message = shift;
  ## TODO Replace with proper logging
  print "$message\n";
}

