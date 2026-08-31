#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Copy qw(copy);
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

use CGI;
use lib File::Spec->catdir($FindBin::Bin, '..', '..', 'bin', 'lib');
use Orbit::Orbit7;

sub make_domain {
  my ($base, $name) = @_;
  my $domain = File::Spec->catdir($base, $name);
  make_path(
    File::Spec->catdir($domain, '_WEB'),
    File::Spec->catdir($domain, 'COMMS'),
    map { File::Spec->catdir($domain, 'LANGS', $_) }
      qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES),
  );
  return abs_path($domain);
}

sub orbit_for_query {
  my ($document_root, $host, $query) = @_;
  $query = '' if (!defined($query));
  CGI->initialize_globals() if CGI->can('initialize_globals');
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD    => 'GET',
    DOCUMENT_ROOT     => $document_root,
    QUERY_STRING      => $query,
    REQUEST_URI       => ($query eq '' ? '/o/page' : '/o/page?'.$query),
    HTTP_HOST         => $host,
    REQUEST_SCHEME    => 'https',
    HTTPS             => 'on',
    SERVER_PORT       => '443',
    REMOTE_ADDR       => '192.0.2.10',
  );
  return Orbit->new();
}

my $temporary = tempdir(CLEANUP => 1);
my $domain = make_domain($temporary, 'home.example');
my $document_root = File::Spec->catdir($domain, '_WEB');

subtest 'bare /o/page opens the Action Navigator' => sub {
  my $orbit = orbit_for_query($document_root, 'home.example', '');
  is($orbit->GetRoot(), 'COMMS', 'home request binds the COMMS root');
  is($orbit->Get_Token('MENU'), 'action', 'home request selects the action menu');
  is($orbit->Get_Token('PAGE'), 'DEFAULT', 'home request still uses the DEFAULT page');
  is($orbit->Get_Token('OBJECT'), '', 'home request does not invent a SEARCH object');
};

subtest 'explicit root, object, word, and menu requests are unchanged' => sub {
  my $persons = orbit_for_query($document_root, 'home.example', 'r=PERSONS');
  is($persons->GetRoot(), 'PERSONS', 'an explicit root is not rewritten to COMMS');
  is($persons->Get_Token('MENU'), '', 'an explicit root does not receive the action menu');

  my $word = orbit_for_query($document_root, 'home.example', 'r=PERSONS&o=PERSON&w=jane');
  is($word->GetRoot(), 'PERSONS', 'a content request keeps its root');
  is($word->Get_Token('OBJECT'), 'PERSON', 'a content request keeps its object');
  is($word->Get_Token('MENU'), '', 'a content request does not receive the action menu');

  my $index = orbit_for_query($document_root, 'home.example', 'r=MENU&m=index');
  is($index->GetRoot(), 'MENU', 'an explicit menu request keeps its root');
  is($index->Get_Token('MENU'), 'index', 'an explicit menu request keeps its menu');

  my $action = orbit_for_query($document_root, 'home.example', 'r=COMMS&m=action');
  is($action->GetRoot(), 'COMMS', 'the Action Navigator URL keeps COMMS');
  is($action->Get_Token('MENU'), 'action', 'the Action Navigator URL keeps action');
};

subtest 'header letters moved into the flower dropdown' => sub {
  my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
  my $buttons = do {
    local $/;
    open(my $fh, '<', File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_NAV_BUTTONS.oml'))
      or die "read EL_NAV_BUTTONS.oml: $!";
    <$fh>;
  };
  my $menus = do {
    local $/;
    open(my $fh, '<', File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_NAV_MENUS.oml'))
      or die "read EL_NAV_MENUS.oml: $!";
    <$fh>;
  };
  my $default = do {
    local $/;
    open(my $fh, '<', File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'DEFAULT.oml'))
      or die "read DEFAULT.oml: $!";
    <$fh>;
  };

  unlike($buttons, qr/<B>M<\/B>/, 'header no longer shows the M roots button');
  unlike($buttons, qr/<B>O<\/B>/, 'header no longer shows the O community button');
  unlike($buttons, qr/<B>A<\/B>/, 'header no longer shows the A action button');
  unlike($buttons, qr/<B>E<\/B>/, 'header no longer shows the E library button');
  like($buttons, qr/NAV_BACK/, 'header still offers a back button when a prior menu exists');

  unlike($menus, qr/\[index\]\[Index\]/, 'flower dropdown no longer lists a separate Index item');
  like($menus, qr/#MSG\[ROOTS\]#/, 'flower dropdown labels the former M destination as ROOTS');
  like($menus, qr/el-hex-menu/, 'flower dropdown is marked so it can stack above sticky box headers');
  like($menus, qr/root=MENU&menu=index&tree=mother/,
    'ROOTS in the flower dropdown uses the former Main Index destination');

  like($default, qr/#OBJECT=EXISTS\[#MENU#\]/,
    'DEFAULT does not force SEARCH when a navigator menu is already selected');
};

sub copy_tree {
  my ($src, $dst) = @_;
  find({
    no_chdir => 1,
    wanted   => sub {
      my $rel = File::Spec->abs2rel($File::Find::name, $src);
      return if ($rel eq '.');
      my $target = File::Spec->catfile($dst, $rel);
      if (-d $File::Find::name) {
        make_path($target);
      } elsif (-f $File::Find::name) {
        make_path((File::Spec->splitpath($target))[1]);
        copy($File::Find::name, $target) or die "copy $File::Find::name: $!";
      }
    },
  }, $src);
}

subtest 'rendered home page shows Action Navigator without header letters' => sub {
  my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
  my $templates_dst = File::Spec->catdir($domain, '_ROOT', '_TEMPLATES');
  make_path($templates_dst);
  copy_tree(File::Spec->catdir($repo, 'bin', '_TEMPLATES'), $templates_dst);

  my $orbit = orbit_for_query($document_root, 'home.example', '');
  $orbit->SetCommandLineOn();
  $orbit->SetPrintOutputOff();
  my $html = $orbit->ShowPage();
  $html = '' if (!defined($html));

  unlike($html, qr/<B>M<\/B>/, 'rendered header has no M badge');
  unlike($html, qr/<B>O<\/B>/, 'rendered header has no O badge');
  unlike($html, qr/<B>A<\/B>/, 'rendered header has no A badge');
  unlike($html, qr/<B>E<\/B>/, 'rendered header has no E badge');
  like($html, qr/Action Navigator/, 'rendered home page is the Action Navigator');
  like($html, qr/ROOTS/, 'rendered flower dropdown includes ROOTS');
  like($html, qr/root=MENU&menu=index&tree=mother/,
    'rendered ROOTS link keeps the former Main Index destination');
};

done_testing();
