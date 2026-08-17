#!/usr/bin/perl

use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'bin/lib';
use Orbit::Orbit7;

my $temporary = tempdir(CLEANUP => 1);
my $nested = File::Spec->catdir($temporary, 'LANGS', 'ENG');
make_path($nested);

my $default = File::Spec->catfile($temporary, 'DEFAULT.oml');
my $english = File::Spec->catfile($nested, 'EL_SHOW_WORD.oml');
for my $path ($default, $english) {
  open(my $fh, '>:raw', $path) or die "open $path: $!";
  print {$fh} "safe template\n";
  close($fh) or die "close $path: $!";
}

my $orbit = bless {
  _TEMPLATEDIRS => { 0 => $temporary.'/' },
  _TemplateDir  => $temporary.'/',
  _TemplateExt  => '.oml',
}, 'Orbit';

is($orbit->SearchTemplateDirs('DEFAULT'), $default, 'simple template identifier resolves');
is(
  $orbit->SearchTemplateDirs('LANGS/ENG/EL_SHOW_WORD'),
  $english,
  'project-relative template subdirectories resolve',
);

for my $unsafe (
  '../DEFAULT',
  'LANGS/../../DEFAULT',
  '/DEFAULT',
  'LANGS\\ENG\\EL_SHOW_WORD',
  'LANGS//ENG/EL_SHOW_WORD',
  'DEFAULT.oml',
  "DEFAULT\0",
  'LANGS/ENG/#PAGE#',
) {
  is($orbit->SearchTemplateDirs($unsafe), '', "unsafe template name is rejected: [$unsafe]");
}

done_testing();
