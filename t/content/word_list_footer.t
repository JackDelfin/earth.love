#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path);
use File::Spec;
use FindBin;
use Test::More;

use lib File::Spec->catdir($FindBin::Bin, '..', '..', 'bin', 'lib');
use Orbit::Orbit7;

my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $templates = File::Spec->catdir($repo, 'bin', '_TEMPLATES');

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "read $path: $!";
  local $/;
  my $text = <$fh>;
  close($fh) or die "close $path: $!";
  return $text;
}

sub test_orbit {
  return bless {
    _TOKENS           => {},
    _Utils            => CoreUtils->new(),
    _TOKEN_MODIFIERS  => {},
    _OML_FUNCTIONS    => {},
    _FN_GROUPS_LOADED => {},
    _TEMPLATEDIRS     => { 0 => $templates.'/' },
    _TemplateExt      => '.oml',
    _BackupExt        => '_BACK',
    _RecursiveCount   => 0,
    _RecursiveMax     => 100,
    _ParseMax         => 1000,
    _bLogStats        => 0,
    _bShowComments    => 0,
    _StatsCnt         => 0,
    _STATS            => {},
    _Token            => '',
    _Function         => '',
    _Arguments        => '',
    _bFlush           => 0,
  }, 'Orbit';
}

sub step {
  my ($max, $direction, $floor) = @_;
  $floor = 7 if (!defined($floor));
  my $orbit = test_orbit();
  $orbit->Set_Token('_datamax', $max);
  $orbit->Set_Token('MAX_DEF', $floor);
  return $orbit->Parse('#TRIM[#OML[EL_FN_DATA_MAX_STEP]['.$direction.']#]#', 0);
}

my $show_word = slurp(File::Spec->catfile($templates, 'LANGS', 'ENG', 'EL_SHOW_WORD.oml'));
my $search_core = File::Spec->catfile($templates, 'EL_SHOW_SEARCH_CORE.oml');
my $show_search = slurp($search_core);
my $show_more = slurp(File::Spec->catfile($templates, 'EL_NAV_SHOW_MORE.oml'));
my $tokens = slurp(File::Spec->catfile($templates, 'EL_TOKENS.oml'));
my $tokens_search = slurp(File::Spec->catfile($templates, 'EL_TOKENS_SEARCH.oml'));
my $header = slurp(File::Spec->catfile($templates, 'EL_HEADER.oml'));
my $step_fn = slurp(File::Spec->catfile($templates, 'EL_FN_DATA_MAX_STEP.oml'));
my $data_pm = slurp(File::Spec->catfile($repo, 'bin', 'lib', 'Orbit', 'OML', 'Function', 'Data.pm'));
my $nav_index = slurp(File::Spec->catfile($templates, 'MENU', 'EL_NAV_INDEX.oml'));
my $search_roots = slurp(File::Spec->catfile($templates, 'EL_SEARCH_ROOTS.oml'));

subtest 'search entry points include a distinct shared implementation' => sub {
  for my $root ('', qw(BOOKS COMMS GUILDS JOBS LOCS MENU PERSONS SPIRITS LANGS/ENG)) {
    my $directory = File::Spec->catdir($templates, $root);
    my $path = File::Spec->catfile($directory, 'EL_SHOW_SEARCH.oml');
    my $name = ($root eq '' ? '' : $root.'/').'EL_SHOW_SEARCH';
    like(slurp($path), qr/\A\s*#INC\[EL_SHOW_SEARCH_CORE\]#\s*\z/,
      "$name contains only the shared core include");

    my $orbit = test_orbit();
    $orbit->{_TEMPLATEDIRS} = { 0 => $directory.'/', 1 => $templates.'/' };
    is($orbit->SearchTemplateDirs('EL_SHOW_SEARCH'), $path,
      "$name resolves with the root directory before the shared library");
    is($orbit->SearchTemplateDirs('EL_SHOW_SEARCH_CORE'), $search_core,
      "$name resolves the shared core without selecting itself");
  }

  my $sequence = join('.*', map { quotemeta($_) } (
    '#INC![EL_FORM_SEARCH][#MSG_SEARCH#]#',
    '#INC![EL_SEARCH_WORD]#',
    '#STOP[#WORD.NOTEXISTS#]#',
    '#INC[EL_TOKENS_SEARCH]#',
    '#INC![EL_SEARCH_RESULTS]#',
  ));
  like($show_search, qr/$sequence/s,
    'the shared core retains the form, word, empty-word guard, tokens, and results in order');
};

subtest 'every data box uses the simplified toolbar in a sticky header' => sub {
  like($tokens, qr/NEXT_PREV\s*=\[#INC\[EL_NAV_SHOW_MORE\]#\]/,
    'the default list toolbar is the simplified show more/less control');
  like($tokens, qr/LIST\s+=EQUAL\[#LIST#\]\[list\]\[list\]\[button\]/,
    'list style only stays list; any other value including language ENG becomes default');
  like($tokens_search, qr/_DATA_HEAD_=\[.*#NEXT_PREV#/s,
    'search box headers render the toolbar');
  unlike($tokens_search, qr/_DATA_FOOT_=\[#NEXT_PREV#/,
    'search box footers no longer hold the toolbar');
  like($header, qr/\.el-box-head\s*\{[^}]*position:\s*sticky/s,
    'box headers stick when they scroll off screen');
  like($show_word, qr/EL_SEARCH_CATS/, 'Categories box stays on the word layout');
  like($show_word, qr/EL_SEARCH_PHRASES/, 'Phrases box stays on the word layout');
  unlike($show_word, qr/NEXT_PREV\s*=\[#INC\[EL_NAV_SHOW_MORE\]#\]/,
    'word pages inherit the global toolbar instead of overriding it');
  unlike($show_search, qr/NEXT_PREV\s*=\[#INC\[EL_NAV_SHOW_MORE\]#\]/,
    'word search pages inherit the global toolbar instead of overriding it');
  like($nav_index, qr/EL_SEARCH_ROOTS/, 'the ROOTS navigator still loads the roots list');
  like($search_roots, qr/EL_TOKENS_SEARCH/, 'the ROOTS list uses the shared search box chrome');
};

subtest 'toolbar is show more/less, search, and list/default toggle' => sub {
  like($show_more, qr/#MSG\[show more\]#/, 'toolbar offers show more');
  like($show_more, qr/#MSG\[show less\]#/, 'toolbar offers show less');
  like($show_more, qr/name="#_datafile#Q"/, 'toolbar keeps a per-box search field');
  like($show_more, qr/name="#_datafile#M"/, 'search keeps the current max via a hidden field');
  like($show_more, qr/name="list"/, 'search preserves list vs default style');
  like($show_more, qr/name="menu"/, 'search preserves the current menu so ROOTS stays on index');
  like($show_more, qr/name="tree"/, 'search preserves tree so ROOTS keeps tree=mother');
  like($show_more, qr/&list=#LIST#/, 'show more/less keep the current list style');
  like($show_more, qr/&list=#_list_other#/, 'toolbar toggles list vs default style');
  like($show_more, qr/#MSG\[#_list_label#\]#/, 'toggle is labeled list or default');
  unlike($show_more, qr/<select/i, 'toolbar has no page-size dropdown');
  unlike($show_more, qr/MAX_RECORDS/, 'toolbar does not render numeric page-size options');
  unlike($show_more, qr/BUTTON_BO/, 'toolbar does not use the old empty BubblesOff control');
  unlike($show_more, qr/&laquo;|&raquo;/, 'toolbar has no prev/next paging arrows');
  unlike($show_more, qr/BUTTON_GO|value="Go"/, 'toolbar has no separate Go control');
  like($show_more, qr/&lang=#LANG#/, 'toolbar links pass language as lang= so list= can work');
  like($show_more, qr/m=#MENU#&tree=#TREE#/, 'toolbar links keep menu and tree');
  unlike($show_more, qr/[&?]l=list\b/, 'list style is not the language abbrev l=');
  like($step_fn, qr/MORE jumps to All/, 'max helper documents the All jump');
  like(slurp(File::Spec->catfile($repo, 'bin', 'lib', 'Orbit', 'Akashic.pm')),
    qr/SetParamTokens\('',\s*'list'/,
    'list style is read from list= so it cannot steal the language l= parameter');
};

subtest 'DATA sets next/prev before the box header is parsed' => sub {
  my $next_at = index($data_pm, q{Set_Token($datafile.'_NEXT'});
  my $head_at = index($data_pm, 'Parse($a1');
  ok($next_at >= 0 && $head_at > $next_at,
    'show more in the header can see whether more rows exist');
};

subtest 'show more jumps to All and show less returns to the floor' => sub {
  is(step('7', 'MORE'), 'All', 'show more from the default max is All');
  is(step('10', 'MORE'), 'All', 'show more from an intermediate size is All');
  is(step('All', 'MORE'), '', 'show more is empty when already showing All');

  is(step('All', 'LESS'), '7', 'show less from All is MAX_DEF');
  is(step('10', 'LESS'), '7', 'show less from an intermediate size is MAX_DEF');
  is(step('7', 'LESS'), '7', 'show less at the floor stays at the floor');
  is(step('All', 'LESS', 10), '10', 'show less uses a raised MAX_DEF as the floor');
};

done_testing();
