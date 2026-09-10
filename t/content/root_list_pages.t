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

my @pages = (
  { root => 'COMMS', object => 'COMM', prompt => 'Search for Community',
    heading => 'Communities', button => 'Create Community', restore => 0,
    boxes => [ [COMMS => 'Communities'], [LINKS => 'Links'], [FEDS => 'Federations'] ],
    item_field => 'Community Name' },
  { root => 'BOOKS', object => 'BOOK', prompt => 'Search Books',
    heading => 'Books', button => 'Create Book', restore => 0,
    boxes => [ [BOOKS => 'Books'] ] },
  { root => 'PERSONS', object => 'PERSON', prompt => 'Search People',
    heading => 'People', button => 'Create Person', restore => 1,
    boxes => [ [PERSONS => 'People'] ], item_field => 'Full Name' },
  { root => 'JOBS', object => 'JOB', prompt => 'Search Projects',
    heading => 'Projects', button => 'Create Project', restore => 1,
    boxes => [ [JOBS => 'Projects'] ] },
  { root => 'GUILDS', object => 'GUILD', prompt => 'Search Guilds',
    heading => 'Guilds', button => 'Create Guild', restore => 1,
    boxes => [ [GUILDS => 'Guilds'] ], item_field => 'Guild Name' },
  { root => 'LOCS', object => 'LOC', prompt => 'Search Locations',
    heading => 'Locations', button => 'Create Location', restore => 1,
    boxes => [ [PATHS => 'Location Paths'], [PHRASES => 'Locations'] ] },
  { root => 'SPIRITS', object => 'SPIRIT', prompt => 'Search Love',
    heading => 'Love', button => 'Create Spirituality', restore => 1,
    boxes => [ [SPIRITS => 'Love'] ], item_field => 'Spiritual Community Name' },
);

my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $source_templates = File::Spec->catdir($repo, 'bin', '_TEMPLATES');
my $temporary = tempdir(CLEANUP => 1);
my $domain = File::Spec->catdir($temporary, 'lists.example');
my $document_root = File::Spec->catdir($domain, '_WEB');
my $templates = File::Spec->catdir($domain, '_ROOT', '_TEMPLATES');
my $word = 'listprobe';

sub slurp {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "read $path: $!";
  local $/;
  my $text = <$fh>;
  close($fh) or die "close $path: $!";
  return $text;
}

sub write_file {
  my ($path, $text) = @_;
  make_path((File::Spec->splitpath($path))[1]);
  open(my $fh, '>:raw', $path) or die "write $path: $!";
  print {$fh} $text;
  close($fh) or die "close $path: $!";
}

sub copy_tree {
  my ($src, $dst) = @_;
  find({
    no_chdir => 1,
    wanted => sub {
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

sub row_text {
  my ($root, $datafile, $search_word) = @_;
  return lc($root.' '.$datafile.' '.($search_word ? 'word' : 'root').' fixture');
}

make_path($document_root, $templates,
  map { File::Spec->catdir($domain, 'LANGS', 'ENG', $_) }
    qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES));
copy_tree($source_templates, $templates);

# Use real WordBase files so every result layout has visible data, both at the
# root and under a nonempty WORD. All data and copied templates stay in /tmp.
for my $page (@pages) {
  my $rootdir = File::Spec->catdir($domain, $page->{root});
  my $worddir = File::Spec->catdir($rootdir, '_WORDS', split(//, $word), $word);
  make_path($worddir);
  write_file(File::Spec->catfile($rootdir, 'NAME.dat'), $page->{heading}."\n");
  write_file(File::Spec->catfile($worddir, 'WORD.dat'), $word."\n");
  my %datafiles = map { $_ => 1 }
    ((map { $_->[0] } @{$page->{boxes}}), qw(CATS PHRASES LINKS WORDS));
  for my $dir ($rootdir, $worddir) {
    for my $datafile (sort keys %datafiles) {
      write_file(File::Spec->catfile($dir, $datafile.'.dat'),
        row_text($page->{root}, $datafile, $dir eq $worddir ? $word : '')."\n");
    }
  }
}

sub orbit_for_query {
  my ($query) = @_;
  CGI->initialize_globals() if CGI->can('initialize_globals');
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD => 'GET',
    DOCUMENT_ROOT => $document_root,
    QUERY_STRING => $query,
    REQUEST_URI => '/o/page?'.$query,
    HTTP_HOST => 'lists.example',
    REQUEST_SCHEME => 'https',
    HTTPS => 'on',
    SERVER_PORT => '443',
    REMOTE_ADDR => '192.0.2.10',
  );
  my $orbit = Orbit->new();
  my $rootdir = File::Spec->catdir($templates, $orbit->GetRoot());
  $orbit->{_TEMPLATEDIRS} = { 0 => $rootdir.'/', 1 => $templates.'/' };
  $orbit->SetCommandLineOn();
  $orbit->SetPrintOutputOff();
  return $orbit;
}

sub token_state {
  my ($orbit) = @_;
  return [ map { $orbit->Get_Token($_) // '' } qw(ROOT ROOT_BACK OBJECT) ];
}

# Observe the real resolver without replacing any OML, data, or routing logic.
sub with_lookups {
  my ($render) = @_;
  my @lookups;
  my $resolve = Orbit->can('SearchTemplateDirs');
  no warnings 'redefine';
  local *Orbit::SearchTemplateDirs = sub {
    my ($orbit, $name) = @_;
    push @lookups, { name => $name, state => token_state($orbit) };
    return $resolve->(@_);
  };
  my $html = $render->() // '';
  return ($html, \@lookups);
}

sub assert_list {
  my ($html, $page, $search_word, $with_boxes) = @_;
  my ($root, $object, $heading, $prompt, $button) =
    @{$page}{qw(root object heading prompt button)};
  like($html, qr/<h2\b[^>]*>\s*\Q$heading\E\s*<\/h2>/,
    'EL_HEADER_ROOT renders the root name');
  my ($form) = $html =~ /(<form\b[^>]*\bname="search"[^>]*>.*?<\/form>)/s;
  ok(defined($form), 'the list search form renders');
  $form //= '';
  like($form, qr/<label>\Q$prompt\E<\/label>/, 'the exact search prompt survives includes');
  like($form, qr/<input\b[^>]*name="word"[^>]*value="\Q$search_word\E"/,
    'the word field retains the query');
  for my $field ([root => $root], [object => 'search'], [page => 'el_show']) {
    my ($name, $value) = @$field;
    like($form, qr/<input\b[^>]*type="hidden"[^>]*name="\Q$name\E"[^>]*value="\Q$value\E"/,
      "search preserves hidden $name=$value");
  }
  for my $box (@{$page->{boxes}}) {
    my ($datafile, $label) = @$box;
    my $row = row_text($root, $datafile, $search_word);
    like(lc($html), qr/\Q$row\E/, "$datafile uses this root's result data")
      if ($with_boxes || $root eq 'LOCS');
    like($html, qr/<h3>\Q$label\E<\/h3>/, "$datafile retains its box heading")
      if ($with_boxes);
  }
  if ($root eq 'COMMS') {
    my ($comms, $links, $feds) = map { quotemeta(row_text($root, $_, $search_word)) }
      qw(COMMS LINKS FEDS);
    my $columns = $with_boxes
      ? qr/<div class="w3-third">.*?$comms.*?<div class="w3-third">.*?$links.*?<div class="w3-third">.*?$feds/s
      : qr/(?:<div class="w3-third">\s*<\/div>\s*){3}/;
    like($html, qr/<div class="w3-row w3-container w3-round-xlarge">\s*$columns/s,
      'COMMS retains Communities, Links, and Federations in three columns');
  }
  if ($with_boxes) {
    if ($search_word eq '') {
      unlike($html, qr/<h3>Categories<\/h3>/, 'empty WORD skips the general search results');
    } else {
      like($html, qr/<h3>Categories<\/h3>/, 'nonempty WORD renders the general search results');
      my $category = row_text($root, 'CATS', $search_word);
      like($html, qr/\Q$category\E/, 'general results use the nonempty WORD data');
    }
  }
  my $destination = '/o/elnew?r='.$root.'&o='.lc($object).'&p=el_new';
  like($html,
    qr/<div class="w3-container w3-center">\s*<a\b[^>]*href="\Q$destination\E">\Q$button\E<\/a>\s*<\/div>/,
    'the centered create button keeps its label and destination');
  unlike($html, qr/(?:IF)?INCLUDE: Template not found|!!HALT_EXECUTION!!/,
    'all includes complete without leaking parser control text');
}

sub assert_footer {
  my ($html) = @_;
  like($html, qr/<footer\b[^>]*>.*?Updated:.*?<\/footer>\s*<\/body>\s*<\/html>\s*\z/s,
    'rendering reaches the footer and closes the document');
}

subtest 'wrapper source and root-first lookup' => sub {
  for my $page (@pages) {
    my ($root, $object, $prompt) = @{$page}{qw(root object prompt)};
    my $path = File::Spec->catfile($templates, $root, 'EL_SHOW_'.$root.'.oml');
    my $source = slurp($path);
    my @lines = ('#ROOT=['.$root.']#', '#OBJECT=['.$object.']#',
      '#INC[EL_SHOW_ROOT]['.$prompt.']#');
    push @lines, '#RESTORE[ROOT]#' if ($page->{restore});
    my $expected = join('\s*', map { quotemeta($_) } @lines);
    like($source, qr/\A\s*$expected\s*\z/,
      "$root is a thin include with its explicit root, singular object, and exact prompt");
    if ($page->{restore}) {
      like($source, qr/#RESTORE\[ROOT\]#\s*\z/, "$root keeps its trailing RESTORE");
    } else {
      unlike($source, qr/#RESTORE\[ROOT\]#/, "$root has no trailing RESTORE");
    }
    unlike($source, qr/#BACKUP\[/, "$root adds no backup");
    my $orbit = orbit_for_query('r='.$root);
    is($orbit->SearchTemplateDirs('EL_SHOW_'.$root), $path,
      "$root resolves its wrapper before the shared library");
    is($orbit->SearchTemplateDirs('EL_SHOW_ROOT'),
      File::Spec->catfile($templates, 'EL_SHOW_ROOT.oml'),
      "$root resolves EL_SHOW_ROOT to the distinct shared body");
  }
};

subtest 'shared body preserves its arguments and qualified include order' => sub {
  my $source = slurp(File::Spec->catfile($templates, 'EL_SHOW_ROOT.oml'));
  my $sequence = join('.*?', map { quotemeta($_) } (
    '#STOP[#ROOT.NOTEXISTS#]#',
    '#STOP[#OBJECT.NOTEXISTS#]#',
    '#_list_search_prompt_=PARSE[#_1_#]#',
    '#INC[EL_HEADER_ROOT]#',
    '#INC[EL_FORM_SEARCH][#_list_search_prompt_#]#',
    '#INC[EL_SEARCH_RESULTS]#',
    '#OML[#ROOT.upper#/EL_SEARCH_#ROOT#]#',
    '<div class="w3-container w3-center">',
    '#OML[#ROOT.upper#/EL_NEW_#OBJECT#_BUT]#',
    '</div>',
  ));
  like($source, qr/$sequence/s,
    'the prompt is eagerly saved before the header, form, results, layout, and button');
  unlike($source, qr/#(?:ROOT|OBJECT|searchmsg)\s*=/i,
    'the shared body uses caller-supplied root and object without the unused searchmsg');
  unlike($source, qr/#OML\[EL_(?:SEARCH_|NEW_)/,
    'the layout and button do not use unqualified lookup');
  unlike($source, qr/#(?:BACKUP|RESTORE)\[ROOT\b/,
    'the shared body adds no ROOT backup or restore');
};

subtest 'shared body stops when ROOT or OBJECT is missing' => sub {
  for my $missing (qw(ROOT OBJECT)) {
    my $orbit = orbit_for_query('r=PERSONS&o=PERSON&p=el_show');
    $orbit->Delete_Token($missing);
    my $before = token_state($orbit);
    my ($html, $lookups) = with_lookups(sub {
      $orbit->Parse('#INC[EL_SHOW_ROOT][Search People]#caller continues', 0);
    });
    like($html, qr/\A\s*caller continues\z/, "missing $missing stops only the shared include");
    is_deeply([map { $_->{name} } @$lookups], ['EL_SHOW_ROOT'],
      "missing $missing stops before nested includes");
    is_deeply(token_state($orbit), $before, "missing $missing does not invent caller state");
  }
};

subtest 'all seven list routes with empty and nonempty WORD' => sub {
  for my $page (@pages) {
    for my $search_word ('', $word) {
      my $root = $page->{root};
      my $query = 'r='.$root.'&o='.$root.'&p=el_show&w='.$search_word;
      subtest $query => sub {
        my $orbit = orbit_for_query($query);
        my ($html, $lookups) = with_lookups(sub { $orbit->ShowPage() });
        assert_list($html, $page, $search_word, 0);
        assert_footer($html);
        is_deeply(token_state($orbit), [$root, $root, $page->{object}],
          'ROOT, ROOT_BACK, and singular OBJECT retain their route state');
        my @sequence = ('EL_HEADER_ROOT', 'EL_FORM_SEARCH', 'EL_SEARCH_RESULTS',
          $root.'/EL_SEARCH_'.$root, $root.'/EL_NEW_'.$page->{object}.'_BUT');
        my %wanted = map { $_ => 1 } @sequence;
        is_deeply([map { $_->{name} } grep { $wanted{$_->{name}} } @$lookups],
          \@sequence, 'header, form, results, qualified layout, and qualified button run in order');

        # The wrappers assume search-box tokens supplied by their caller. Also
        # exercise that context with the real shared chrome, without changing
        # the bare ShowPage baseline above or stubbing EL_GET_DATA.
        my $boxed = orbit_for_query($query);
        $boxed->Parse('#INC[EL_TOKENS_SEARCH]#', 0);
        my $box_html = $boxed->ShowPage() // '';
        assert_list($box_html, $page, $search_word, 1);
        assert_footer($box_html);
      };
    }
  }
};

subtest 'existing missing-item fallbacks reach their list wrappers' => sub {
  for my $page (@pages) {
    my ($root, $object) = @{$page}{qw(root object)};
    my $source = slurp(File::Spec->catfile($templates, $root, 'EL_SHOW_'.$object.'.oml'));
    if (!$page->{item_field}) {
      unlike($source, qr/#ifOML\[#_WORDFOUND_\.0\.NOT#\]/,
        "$root still has no missing-item fallback");
      next;
    }
    my $target = ($root eq 'GUILDS' ? '#ROOT.upper#/' : '').'EL_SHOW_#ROOT#';
    like($source, qr/#ifOML\[#_WORDFOUND_\.0\.NOT#\]\[\Q$target\E\]#\s*#STOP\[#_WORDFOUND_\.0\.NOT#\]#/,
      "$root preserves its existing fallback and stop");
    my $orbit = orbit_for_query('r='.$root.'&o='.$object.'&p=el_show');
    isnt($orbit->Get_Token('_WORDFOUND_'), '1', "$root has no item word");
    my $html = $orbit->ShowPage() // '';
    assert_list($html, $page, '', 0);
    unlike($html, qr/\Q$page->{item_field}\E/, "$root does not render item fields");
    assert_footer($html);
    is_deeply(token_state($orbit), [$root, $root, $object],
      "$root fallback preserves root and object state");
  }
};

subtest 'nested header includes cannot consume the search prompt' => sub {
  for my $page (@pages) {
    my $root = $page->{root};
    my $orbit = orbit_for_query('r='.$root.'&o='.$root.'&p=el_show');
    $orbit->Parse('#INC[EL_TOKENS]##INC[EL_TOKENS_SEARCH]#', 0);
    # This real nested include assigns and deletes _1_ while the header renders.
    $orbit->Set_Token('_root_name_', '#OML[EL_FN_ROOT_NAME]['.$root.']#');
    my $html = $orbit->Parse('#INC['.$root.'/EL_SHOW_'.$root.']#', 0);
    assert_list($html, $page, '', 1);
  }
};

subtest 'wrapper RESTORE differences preserve a distinct caller backup' => sub {
  # Supply a real button at the restored root in the temporary template copy.
  # Its lookup must happen after COMMS/EL_SEARCH_COMMS restores ROOT.
  my $alternate_button = File::Spec->catfile($templates, 'LANGS', 'ENG', 'EL_NEW_COMM_BUT.oml');
  copy(File::Spec->catfile($templates, 'COMMS', 'EL_NEW_COMM_BUT.oml'), $alternate_button)
    or die "copy $alternate_button: $!";
  for my $page (@pages) {
    my ($root, $object) = @{$page}{qw(root object)};
    my $orbit = orbit_for_query('r='.$root.'&p=el_show');
    $orbit->Parse('#INC[EL_TOKENS]##INC[EL_TOKENS_SEARCH]#', 0);
    $orbit->Set_Token('ROOT', 'BOOKS');
    $orbit->Set_Token('ROOT_BACK', 'LANGS/ENG');
    $orbit->Set_Token('OBJECT', 'CALLER');
    my ($html, $lookups) = with_lookups(sub {
      $orbit->Parse('#INC['.$root.'/EL_SHOW_'.$root.']#', 0);
    });
    my $button_root = $root eq 'COMMS' ? 'LANGS/ENG' : $root;
    is_deeply([map { [$_->{name}, @{$_->{state}}] }
      grep { $_->{name} =~ m{/EL_NEW_\Q$object\E_BUT\z} } @$lookups],
      [[$button_root.'/EL_NEW_'.$object.'_BUT', $button_root, 'LANGS/ENG', $object]],
      "$root evaluates the qualified button path with the current ROOT");
    my $final_root = ($page->{restore} || $root eq 'COMMS') ? 'LANGS/ENG' : $root;
    is_deeply(token_state($orbit), [$final_root, 'LANGS/ENG', $object],
      "$root keeps its prior ROOT / ROOT_BACK / OBJECT behavior");
    assert_list($html, $page, '', 1);
  }
};

subtest 'POL plural-object include and following navigation still complete' => sub {
  my $source = slurp(File::Spec->catfile($templates, 'POL.oml'));
  like($source, qr/#OBJECT=\[COMMS\]#.*?#TMP=INCLUDE\[#ROOT\.upper#\/EL_SHOW_#OBJECT#\]#/s,
    'POL keeps its plural object and qualified list include');
  my $orbit = orbit_for_query('r=COMMS&p=pol');
  my ($html, $lookups) = with_lookups(sub { $orbit->ShowPage() });
  is_deeply([map { $_->{state} } grep { $_->{name} eq 'COMMS/EL_SHOW_COMMS' } @$lookups],
    [['COMMS', 'COMMS', 'COMMS']], 'POL enters the wrapper with a plural OBJECT');
  is_deeply(token_state($orbit), ['COMMS', 'COMMS', 'COMM'],
    'POL finishes the list and navigator with singular COMM');
  like($orbit->Get_Token('TMP'), qr/Action Navigator/, 'POL reaches its following navigator include');
  like($html, qr/<\/body>\s*<\/html>\s*\z/, 'POL closes its document');
  for my $search_word ('', $word) {
    my $nav = orbit_for_query('r=COMMS&o=COMMS&p=el_show&m=action&w='.$search_word);
    my $nav_html = $nav->ShowPage() // '';
    like($nav_html, qr/<h2\b[^>]*>\s*Communities\s*<\/h2>.*?<h2\b[^>]*>\s*Action Navigator\s*<\/h2>/s,
      'the list is followed by the requested Action Navigator');
    assert_footer($nav_html);
    is_deeply(token_state($nav), ['COMMS', 'COMMS', 'COMM'],
      'following navigation retains the list root and singular object');
  }
};

done_testing();
