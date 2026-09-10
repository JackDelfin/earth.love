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
    map { File::Spec->catdir($domain, 'LANGS', 'ENG', $_) }
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
my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $templates = File::Spec->catdir($repo, 'bin', '_TEMPLATES');
my @navigators = (
  [action       => 'Action Navigator'],
  [comms        => 'Community Navigator'],
  [comm_self    => 'Self'],
  [comm_mission => 'Mission - Care for Planet'],
  [comm_plan    => 'Plan'],
  [comm_values  => 'Community Values'],
  [comm_path    => 'Path'],
  [comm_vision  => 'Vision for a Shared Planet'],
  [comm_nature  => 'Spirituality'],
);
my @people_petals = qw(Create Find Meet Teach Lead Learn Connect);

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "read $path: $!";
  local $/;
  my $text = <$fh>;
  close($fh) or die "close $path: $!";
  return $text;
}

sub render_query {
  my ($query) = @_;
  my $orbit = orbit_for_query($document_root, 'home.example', $query);
  $orbit->SetCommandLineOn();
  $orbit->SetPrintOutputOff();
  return $orbit->ShowPage() // '';
}

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

subtest 'COMMS navigator stubs include the MENU originals' => sub {
  for my $navigator (@navigators) {
    my $name = 'EL_NAV_'.uc($navigator->[0]);
    like(slurp(File::Spec->catfile($templates, 'COMMS', $name.'.oml')),
      qr/\A\s*#INC\[MENU\/\Q$name\E\]#\s*\z/,
      "COMMS/$name contains only the MENU include");
    like(slurp(File::Spec->catfile($templates, 'MENU', $name.'.oml')),
      qr/\b(?:Petal_[1-7]|EL_VIEW_FLOWER)\b/,
      "MENU/$name retains the petal or flower navigation markup");
  }
};

subtest 'PERSONS navigator keeps its own identity and seven petals' => sub {
  my $source = slurp(File::Spec->catfile($templates, 'PERSONS', 'EL_NAV_PERSONS.oml'));
  like($source, qr/FlowerHead\s*=\[People Navigator\]/, 'the heading names People');
  like($source, qr/PMENU\s*=\[PERSONS\]/, 'the parent menu is PERSONS');
  like($source, qr/<h3 class="#CLASS_FLOWER_HEAD# w3-red">/, 'the heading uses Root red');
  unlike($source, qr/Locations|LOCS|w3-orange/, 'no Locations identity remains');
  for my $i (0 .. $#people_petals) {
    my $number = $i + 1;
    my $petal = $people_petals[$i];
    like($source, qr/_NAV\Q$number\E\s*=\[\Q$petal\E\]/, "petal $number is $petal");
    like($source, qr/_subroot\Q$number\E\s*=\[PERSONS_\Q$petal\E\]/,
      "$petal points to its PERSONS subroot");
  }
  like(slurp(File::Spec->catfile($templates, 'LOCS', 'EL_NAV_LOCS.oml')),
    qr/FlowerHead\s*=\[Locations Navigator\]/, 'LOCS keeps Locations Navigator');
};

my $templates_dst = File::Spec->catdir($domain, '_ROOT', '_TEMPLATES');
make_path($templates_dst);
copy_tree($templates, $templates_dst);

subtest 'rendered home page shows Action Navigator without header letters' => sub {
  my $html = render_query('');

  unlike($html, qr/<B>M<\/B>/, 'rendered header has no M badge');
  unlike($html, qr/<B>O<\/B>/, 'rendered header has no O badge');
  unlike($html, qr/<B>A<\/B>/, 'rendered header has no A badge');
  unlike($html, qr/<B>E<\/B>/, 'rendered header has no E badge');
  like($html, qr/Action Navigator/, 'rendered home page is the Action Navigator');
  like($html, qr/ROOTS/, 'rendered flower dropdown includes ROOTS');
  like($html, qr/root=MENU&menu=index&tree=mother/,
    'rendered ROOTS link keeps the former Main Index destination');
  like($html, qr/<footer\b[^>]*>.*?Updated:.*?<\/footer>\s*<\/body>\s*<\/html>\s*\z/s,
    'bare /o/page renders through the footer and closes the document');
};

subtest 'COMMS navigator URLs render through the footer' => sub {
  for my $navigator (@navigators) {
    my ($menu, $heading) = @$navigator;
    subtest "r=COMMS&m=$menu" => sub {
      my $html = render_query('r=COMMS&m='.$menu);
      like($html, qr/<h2\b[^>]*>\s*\Q$heading\E\s*<\/h2>/,
        'the MENU original renders its navigator heading');
      like($html, qr/<table\b[^>]*>.*?w3-circle.*?<\/table>/s,
        'the navigator renders its flower petals');
      like($html, qr/<footer\b[^>]*>.*?Updated:.*?<\/footer>\s*<\/body>\s*<\/html>\s*\z/s,
        'the navigator renders through the footer and closes the document');
    };
  }
};

subtest 'PERSONS navigator renders People petals through the footer' => sub {
  my $html = render_query('r=PERSONS&m=PERSONS');
  like($html, qr/<h3\b[^>]*\bw3-red\b[^>]*>\s*People Navigator\s*<\/h3>/,
    'the People Navigator heading renders in red');
  unlike($html, qr/Locations Navigator|menu=LOCS_/, 'the navigator has no Locations heading or petals');
  my ($flower) = $html =~ /<h3\b[^>]*>\s*People Navigator\s*<\/h3>.*?(<table\b[^>]*>.*?<\/table>)/s;
  ok(defined($flower), 'the navigator renders its flower');
  $flower //= '';
  my @petals = $flower =~ /href="[^"]*&pmenu=PERSONS&menu=PERSONS_([^"]+)"/g;
  is_deeply([sort @petals], [sort @people_petals], 'all seven links target the People petals');
  for my $petal (@people_petals) {
    like($flower,
      qr/<a\b[^>]*href="[^"]*&pmenu=PERSONS&menu=PERSONS_\Q$petal\E"[^>]*>\s*<div\b[^>]*\bw3-circle\b[^>]*>\s*<h4><b>\Q$petal\E<\/b><\/h4>\s*<\/div>\s*<\/a>/,
      "$petal renders as a labeled flower link");
  }
  like($html, qr/<footer\b[^>]*>.*?Updated:.*?<\/footer>\s*<\/body>\s*<\/html>\s*\z/s,
    'the People Navigator renders through the footer and closes the document');
};

done_testing();
