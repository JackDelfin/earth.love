#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Test::More;
use lib 'bin/lib';
use Orbit::Orbit7;

{
  package Local::CGI;

  sub new {
    my ($class, %params) = @_;
    return bless { params => \%params }, $class;
  }

  sub param {
    my ($self, $name) = @_;
    return keys %{$self->{params}} if !defined($name);
    return $self->{params}{$name};
  }
}

{
  package Local::Akashic;

  sub isWord {
    my ($self, $value) = @_;
    return defined($value) && $value =~ /\A[A-Za-z0-9-]+\z/ ? 1 : 0;
  }

  sub isPhrase {
    my ($self, $value) = @_;
    return defined($value) && $value =~ /\A[A-Za-z0-9-]+(?: [A-Za-z0-9-]+)+\z/ ? 1 : 0;
  }

  sub isPath {
    my ($self, $value) = @_;
    return defined($value) && $value =~ /\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/ ? 1 : 0;
  }
}

sub test_orbit {
  my (%args) = @_;
  return bless {
    _TOKENS          => {},
    _Utils           => CoreUtils->new(),
    _Akashic         => bless({ _Utils => CoreUtils->new() }, 'Local::Akashic'),
    _cgi             => $args{cgi} || Local::CGI->new(),
    _Domain          => 'EARTH',
    _DomainDir       => '/srv/earth.love/',
    _TOKEN_MODIFIERS => {},
    _OML_FUNCTIONS   => {},
    _FN_GROUPS_LOADED => {},
    _BackupExt       => '_BACK',
    _RecursiveCount  => 0,
    _RecursiveMax    => 100,
    _ParseMax        => 1000,
    _bLogStats       => 0,
    _StatsCnt        => 0,
    _STATS           => {},
  }, 'Orbit';
}

subtest 'non-recursive tokens terminate OML expansion' => sub {
  my $orbit = test_orbit();
  $orbit->{_ProbeExecutions} = 0;
  $orbit->{_OML_FUNCTIONS}->{PROBE} = sub {
    $orbit->{_ProbeExecutions}++;
    return 'function-executed';
  };
  $orbit->Set_Token('SENTINEL', 'expanded');
  $orbit->Set_Token('INTERNAL', '#SENTINEL#');
  $orbit->SetUntrustedToken('REQUEST_VALUE', '#SENTINEL#');
  $orbit->SetUntrustedToken('REQUEST_FUNCTION', '#PROBE[]#');

  is($orbit->Parse('#INTERNAL#', 0), 'expanded', 'internal tokens retain recursive expansion');
  is($orbit->Parse('#REQUEST_VALUE#', 0), '#SENTINEL#', 'untrusted OML-shaped text is emitted literally');
  is($orbit->Parse('#REQUEST_FUNCTION#', 0), '#PROBE[]#', 'untrusted function syntax is emitted literally');
  is($orbit->{_ProbeExecutions}, 0, 'untrusted function syntax is never invoked');
  is($orbit->GetTokenRecursiveFlag('REQUEST_VALUE'), 0, 'request token is marked non-recursive');

  $orbit->Set_Token('REQUEST_VALUE', '#SENTINEL#');
  is($orbit->GetTokenRecursiveFlag('REQUEST_VALUE'), 0, 'ordinary updates cannot accidentally promote tainted data');
  is($orbit->Parse('#REQUEST_VALUE#', 0), '#SENTINEL#', 'updated tainted data remains inert');

  $orbit->SetTrustedToken('REQUEST_VALUE', '#SENTINEL#');
  is($orbit->Parse('#REQUEST_VALUE#', 0), 'expanded', 'promotion is possible only through the explicit trusted API');
};

subtest 'environment headers are bounded, escaped, and non-recursive' => sub {
  local %ENV = (
    HTTP_HOST       => 'earth.love',
    HTTP_USER_AGENT => '#PROBE[]# <script>',
    REQUEST_SCHEME  => 'https',
    SERVER_PORT     => '443',
    REQUEST_METHOD  => 'GET',
  );
  my $orbit = test_orbit();
  $orbit->{_ProbeExecutions} = 0;
  $orbit->{_OML_FUNCTIONS}->{PROBE} = sub {
    $orbit->{_ProbeExecutions}++;
    return 'function-executed';
  };
  $orbit->LoadEnvTokens();

  my $agent = $orbit->Get_Token('ENV_HTTP_USER_AGENT');
  is($agent, '&num;PROBE[]&num; &lt;script&gt;', 'markup and OML delimiters are escaped before storage');
  is($orbit->_SanitizeEnvTokenValue('A' x 1100, 1024), 'A' x 1024, 'environment values are capped before storage');
  is($orbit->GetTokenRecursiveFlag('ENV_HTTP_USER_AGENT'), 0, 'environment token is non-recursive');
  is($orbit->Parse('#ENV_HTTP_USER_AGENT#', 0), $agent, 'rendering the header cannot execute nested OML');
  is($orbit->{_ProbeExecutions}, 0, 'environment function syntax never reaches the function dispatcher');
  is($orbit->Get_Token('ENV_HOST'), 'https://earth.love', 'valid host is composed without an implicit port');

  local $ENV{HTTP_HOST} = 'earth.love#SENTINEL#';
  $orbit = test_orbit();
  $orbit->LoadEnvTokens();
  is($orbit->Get_Token('ENV_HOST'), '', 'invalid Host syntax is not composed into ENV_HOST');
};

subtest 'form field values are inert and cannot choose arbitrary token names' => sub {
  local $ENV{REQUEST_METHOD} = 'POST';
  local $ENV{SCRIPT_NAME} = '/o/elnew';
  my $orbit = test_orbit(
    cgi => Local::CGI->new(
      formfields => '_text,ENV_HOST',
      _text      => 'prefix #PROBE[]# suffix',
      ENV_HOST   => '#SENTINEL#',
    ),
  );
  $orbit->Set_Token('SENTINEL', 'expanded');
  $orbit->{_ProbeExecutions} = 0;
  $orbit->{_OML_FUNCTIONS}->{PROBE} = sub {
    $orbit->{_ProbeExecutions}++;
    return 'function-executed';
  };
  $orbit->Set_Token('ENV_HOST', 'https://earth.love');

  ok($orbit->SetFormFields('ff', 'formfields'), 'at least one valid form field is accepted');
  is($orbit->Get_Token('FORMFIELDS'), '_text', 'invalid/reserved field names are removed from the field list');
  is($orbit->Get_Token('ENV_HOST'), 'https://earth.love', 'reserved tokens cannot be overwritten through formfields');
  is($orbit->GetTokenRecursiveFlag('_TEXT'), 0, 'form value token is marked non-recursive');
  is(
    $orbit->Parse('#_TEXT#', 0),
    'prefix #PROBE[]# suffix',
    'OML-shaped form text is emitted as data and is never recursively evaluated',
  );
  is($orbit->{_ProbeExecutions}, 0, 'form function syntax never reaches the function dispatcher');
  ok($orbit->{_InvalidFormFieldsInput}, 'invalid token-name input is recorded');
};

subtest 'public formfields cannot manufacture presentation tokens' => sub {
  local $ENV{REQUEST_METHOD} = 'GET';
  local $ENV{SCRIPT_NAME} = '/o/page';
  my $orbit = test_orbit(
    cgi => Local::CGI->new(
      formfields => '_TOPNAV1,INDEXQ,INDEXS,INDEXM',
      _TOPNAV1   => '<h1>injected</h1>',
      INDEXQ     => '#OML[EL_DEBUG]#',
      INDEXS     => '<b>1</b>',
      INDEXM     => 'All',
    ),
  );

  ok($orbit->SetFormFields('ff', 'formfields'), 'the valid bounded page-size field is retained');
  is($orbit->Get_Token('FORMFIELDS'), 'INDEXM', 'mutation, executable search, and nonnumeric paging fields are rejected');
  is($orbit->Get_Token('_TOPNAV1'), '', 'a public request cannot populate a raw presentation token');
  is($orbit->Get_Token('INDEXM'), 'All', 'bounded pagination input remains available');
  ok($orbit->{_InvalidFormFieldsInput}, 'rejected token manufacture marks the request invalid');
};

subtest 'request structure is validated before tokenization' => sub {
  my $orbit = test_orbit();

  is($orbit->_ValidateRequestParameter('lang', '#SENTINEL#'), 'ENG', 'invalid language falls back safely');
  is($orbit->_ValidateRequestParameter('page', '../EL_LOGON'), 'DEFAULT', 'template traversal is rejected');
  is($orbit->_ValidateRequestParameter('object', '#DEBUG[]#'), '', 'executable object syntax is rejected');
  is($orbit->_ValidateRequestParameter('nroot', '_ORBIT/_AUTH'), '', 'protected next root is rejected');
  is($orbit->_ValidateRequestParameter('nword', '#DEBUG[]#'), '', 'executable next-word syntax is rejected');
  is($orbit->_ValidateRequestParameter('step', '1#STOP[]#'), '0', 'non-numeric step is rejected');
  ok($orbit->{_InvalidRequestInput}, 'structural validation records invalid input');

  is($orbit->_ValidateRequestParameter('lang', 'ENG'), 'ENG', 'valid language is retained');
  is($orbit->_ValidateRequestParameter('page', 'EL_SHOW'), 'EL_SHOW', 'valid template identifier is retained');
  is($orbit->_ValidateRequestParameter('root', 'LANGS/ENG'), 'LANGS/ENG', 'valid public root is retained');
  is($orbit->_ValidateRequestParameter('nword', 'two_words'), 'two words', 'valid next phrase is normalized safely');
  is($orbit->_ValidateRequestParameter('tree', 'carpenter.classes.earth'), 'carpenter.classes.earth', 'bounded dotted tree path is retained');
  is($orbit->_ValidateRequestParameter('branch', 'one..two'), '', 'empty dotted branch segments are rejected');
  is($orbit->_ValidateRequestParameter('step', '12'), '12', 'bounded numeric step is retained');

  $orbit->SetParamTokens('w', 'word', 'WORD', '#PROBE[]#');
  is($orbit->Get_Token('WORD'), '', 'invalid free-form word cannot remain as a structural WORD token');
};

done_testing;
