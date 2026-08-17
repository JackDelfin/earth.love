#!/usr/bin/perl
# Version 1.0.1.0      01-Jun-2021
#*******************************************************************************
#
# Orbit::Akashic.pm
#
# Custimizable Orbit configuration for Akashic implementation
#
#*******************************************************************************
# History:
#   2021.05.30 earth.love oK Created
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Orbit for Perl.
#
# Orbit for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Orbit for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Orbit for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
#----------------------------------------#
# INITIALIZATION ROUTINES
#----------------------------------------#
#
# initOrbitAkashic()
#   - Initialize Orbit/Akashic connection
#
# SetInputParams()
#   - Define the primary parameters for Akashic earth.love pages
#
# SetFormFields($CGIabbrev, $CGIparam)
#   - Set and get the form fields from the "formfields" parameter
#
# SetParamTokens($CGIabbrev, $CGIparam, $OToken, $value)
#   - Set the page parameters as Tokens
#
# SetWordTokens($pWord, $bNoPartial)
#   - Set the Word tokens for use in Akashic Orbit pages
#
# UploadFile($Filename, $Location)
#   - Process an uploaded file
#
#*******************************************************************************
package Orbit;
use strict;
use warnings;
use File::Find;

#
# Load the Akashic core and Utilities, and Earth addons
#
use Orbit::Print;
use Orbit::Config;
use Akashic::Earth;


#*******************************************************************************
#
# initOrbitAkashic()
#
# - Initialize Orbit/Akashic connection
#
#*******************************************************************************
sub Orbit::initOrbitAkashic
{
  my ( $self ) = @_;
  my $O = $self;
  # Initialize Akashic database - BIG A
  my $A = Akashic->new();

  # Link the Akashic class to Orbit
  $O->SetAkashic($A);

  # Set _Domain _DomainDir internal Orbit class variables
  $O->SetDomain($A->{_Domain}, $A->{_DomainDir});
  # Set the Domain tokens - must have reference
  $O->Set_Token('ENV_DOMAIN',              $A->{_Domain});
  $O->Set_Token('ENV_DOMAINDIR',           $A->{_DomainDir});

  # Turn off statistics by default for Orbit - keep package defaults
  #$O->SetShowStats(0);   # For batch processing Show Stats or not
  #$O->SetLogStats(0);    # Log some cool page and word statistics
  #$O->SetShowOutput(1);  # Show output for batch processing

  #
  # Define the primary parameters for Akashic earth.love pages
  #
  $O->SetInputParams();

  # Get and reset Uprint Buffer
  my $msg = $self->GetUprintBuf();
  $O->RegisterMessage($msg) if ($msg ne "");

  # Important settings for Akashic interaction with Orbit
  # - keep the messaging and stats quiet,
  # - but do sort data dynamically as new words are added
  $A->SetVar('SortData',   '1');   # Turn on/off SortData - Don't sort index data as new items added
  $A->SetVar('ShowStats',  '0');   # Turn on/off ShowStats - Don't show statistics for processing
  $A->SetVar('LogStats',   '0');   # Turn on/off LogStats - Don't even log statistics
  $A->SetVar('ShowOutput', '0');   # Turn on/off ShowOutput - Don't show processing messages

} #initOrbitAkashic


#*******************************************************************************
#
# SetInputParams()
#
# - Define the primary parameters for Akashic earth.love pages
#
#*******************************************************************************
sub Orbit::SetInputParams
{
  my ( $O ) = @_;
  #
  # Define the primary parameters for Akashic earth.love pages
  # Initialize and get parameters from CGI
  $O->SetParamTokens('d',  'domain',   'DOMAIN',   '');
  $O->SetParamTokens('r',  'root',     '',         '');   # Orbit ROOT Token set internally in $O->SetRoot
  $O->SetParamTokens('pr', 'proot',    'PROOT',    '');   # Prior Root for Navigation
  $O->SetParamTokens('nr', 'nroot',    'NROOT',    '');   # Next Root for Navigation
  $O->SetParamTokens('o',  'object',   'OBJECT',   '');
  $O->SetParamTokens('l',  'lang',     '',         '');   # Orbit LANG Token set internally in $O->SetLanguage
  $O->SetParamTokens('t',  'tree',     'TREE',     '');
  $O->SetParamTokens('b',  'branch',   'BRANCH',   '');
  $O->SetParamTokens('w',  'word',     'WORD',     '');
  $O->SetParamTokens('nw', 'nword',    'NWORD',    '');   # Next Word for Navigation
  $O->SetParamTokens('dt', 'datatype', 'DATATYPE', '');
  $O->SetParamTokens('p',  'page',     'PAGE',     '');
  $O->SetParamTokens('np', 'npage',    'NPAGE',    '');   # Next Page for Navigation
  $O->SetParamTokens('l',  'list',     'LIST',     '');   # Values: LIST BO (Bubble)
  $O->SetParamTokens('m',  'menu',     'MENU',     '');
  $O->SetParamTokens('n',  'nav',      'NAV',      '');
  $O->SetParamTokens('pm', 'pmenu',    'PMENU',    '');
  $O->SetParamTokens('nm', 'nmenu',    'NMENU',    '');   # Next Menu for Navigation
  $O->SetParamTokens('s',  'step',     'STEP',     '');
  $O->SetParamTokens('z',  'steps',    'STEPS',    '');
  $O->SetParamTokens('a',  'action',   'ACTION',   '');
  # Set the form fields as tokens as passed in with 'formfields'
  $O->SetFormFields('ff',  'formfields');

} #SetInputParams


#*******************************************************************************
#
# _InvalidRequestParameter / _ValidateRequestParameter
#
# - CGI parameters which select templates, roots, or control flow are structure,
#   not free-form content.  Validate them before setters can use them in paths,
#   dynamic includes, or internal state.
#
#*******************************************************************************
sub Orbit::_InvalidRequestParameter
{
  my ( $O ) = @_;
  $O->{_InvalidRequestInput} = 1;
  $O->RegisterError('The request contains an invalid parameter.');
  return 0;
} #_InvalidRequestParameter


sub Orbit::_ValidateRequestParameter
{
  my ( $O, $CGIparam, $value ) = @_;
  return '' if (!defined($value));
  return $value if (!defined($CGIparam) || $CGIparam eq '' || $value eq '');

  my $valid = 1;
  my $fallback = '';

  if ($CGIparam eq 'lang') {
    $valid = ($value =~ /\A[A-Za-z]{2,8}\z/) ? 1 : 0;
    $fallback = 'ENG';
  } elsif ($CGIparam eq 'page' || $CGIparam eq 'npage') {
    $valid = ($value =~ /\A[A-Za-z][A-Za-z0-9_]{0,127}\z/) ? 1 : 0;
    $fallback = ($CGIparam eq 'page') ? 'DEFAULT' : '';
  } elsif ($CGIparam =~ /\A(?:object|menu|nav|pmenu|nmenu|datatype|action|list)\z/) {
    $valid = ($value =~ /\A[A-Za-z][A-Za-z0-9_-]{0,63}\z/) ? 1 : 0;
  } elsif ($CGIparam eq 'tree' || $CGIparam eq 'branch') {
    $valid = (length($value) <= 160
      && $value =~ /\A[A-Za-z][A-Za-z0-9_-]{0,62}(?:\.[A-Za-z][A-Za-z0-9_-]{0,62})*\z/) ? 1 : 0;
  } elsif ($CGIparam eq 'word' || $CGIparam eq 'nword') {
    my $candidate = $value;
    $candidate =~ s/_/ /g;
    my $A = $O->{_Akashic};
    $valid = (length($candidate) <= 80
      && $candidate !~ /[\x00-\x1f\x7f]/
      && defined($A) && ref($A)
      && (($A->can('isWord') && $A->isWord($candidate))
        || ($A->can('isPhrase') && $A->isPhrase($candidate))
        || ($A->can('isPath') && $A->isPath($candidate)))) ? 1 : 0;
    $value = $candidate if ($valid);
  } elsif ($CGIparam =~ /\A(?:root|proot|nroot)\z/) {
    my $canonical = uc($value);
    $canonical =~ s/\./\//g;
    $valid = (length($canonical) <= 160
      && $canonical =~ m{\A[A-Z0-9-]+(?:/[A-Z0-9-]+)*\z}
      && $canonical !~ m{(?:^|/)_}
      && $canonical !~ /\.\.|[\\\x00-\x1f\x7f]/) ? 1 : 0;
    $fallback = ($CGIparam eq 'root') ? 'LANGS' : '';
  } elsif ($CGIparam eq 'step' || $CGIparam eq 'steps') {
    $valid = ($value =~ /\A(?:0|[1-9][0-9]{0,3})\z/) ? 1 : 0;
    $fallback = '0';
  } elsif ($CGIparam eq 'domain') {
    $valid = (length($value) <= 253
      && $value =~ /\A[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\z/
      && $value !~ /\.\./) ? 1 : 0;
    my $A = $O->{_Akashic};
    $fallback = (defined($A) && ref($A)) ? ($A->GetVar('Domain') // '') : '';
  }

  if (!$valid) {
    $O->_InvalidRequestParameter();
    $O->{_InvalidRootInput} = 1 if ($CGIparam =~ /\A(?:root|proot|nroot)\z/);
    return $fallback;
  }
  return $value;
} #_ValidateRequestParameter


#*******************************************************************************
#
# SetFormFields($CGIabbrev, $CGIparam)
#
# - Set and get the form fields from the "formfields" parameter
#
#*******************************************************************************
sub Orbit::SetFormFields
{
  my ( $O, $CGIabbrev, $CGIparam ) = @_;

  # Get and set FORMFIELDS Token
  my $Fields = $O->SetParamTokens($CGIabbrev, $CGIparam, $CGIparam, '');

  return 0 if (!defined($Fields) || $Fields eq '');
  if (ref($Fields) || length($Fields) > 4096) {
    $O->{_InvalidFormFieldsInput} = 1;
    $O->_InvalidRequestParameter();
    $O->SetUntrustedToken($CGIparam, '');
    return 0;
  }

  # Create an array of the form fields
  my @FIELDARR = split(',', $Fields);
  if (@FIELDARR > 64) {
    $O->{_InvalidFormFieldsInput} = 1;
    $O->_InvalidRequestParameter();
    $O->SetUntrustedToken($CGIparam, '');
    return 0;
  }
  my $ffToken = "";
  my @valid_fields;
  my %seen;
  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  my $script = $ENV{'SCRIPT_NAME'} // '';
  $script =~ s{.*/}{};
  my $mutation_post = ($method eq 'POST'
    && $script =~ /\Ael(?:new|add|edit|del)(?:7)?(?:\.pl)?\z/i) ? 1 : 0;

  # Loop through the Form Fields array and set Tokens from the parameters
  foreach my $ff (@FIELDARR) {
    if ($ff ne "") {
      # Mutation data fields are underscored identifiers.  Read-only pagination
      # fields are generated as DATAFILE + Q/S/M.  Nothing else may manufacture
      # a token name from request data.
      my $is_data_field = ($ff =~ /\A_[A-Za-z](?:[A-Za-z0-9_]{0,62}[A-Za-z0-9])?(?:_req)?\z/i) ? 1 : 0;
      my $is_page_field = ($ff =~ /\A[A-Za-z][A-Za-z0-9_]{0,61}[QSM]\z/) ? 1 : 0;
      my $upper = uc($ff);
      $upper =~ s/_REQ\z//;
      my $reserved = ($upper =~ /\A(?:ENV_.*|AUTH.*|CSRF.*|RETURN_TO|ROOT|PROOT|NROOT|DOMAIN|OBJECT|LANG|TREE|BRANCH|WORD|NWORD|DATATYPE|PAGE|NPAGE|LIST|MENU|NAV|PMENU|NMENU|STEP|STEPS|ACTION|FORMFIELDS|ERROR_TEXT|SUCCESS_TEXT|MESSAGE_TEXT)\z/
        || $upper =~ /\A_(?:ORBIT|DEBUG|STATIC)\z/
        || $upper =~ /\A_(?:DEBUG|STATIC|WORD|PHRASE|PATH|BADWORD|WORDTYPE|WORDFOUND|WORDDIR|PARTIALWORD|FORMFIELDS|DOMAINDIR|ROOT(?:_[A-Z0-9]+)*)_\z/) ? 1 : 0;
      # Underscored data fields belong only to POSTs handled by the dedicated
      # mutation CGIs.  Read-only Q/S/M pagination values are accepted by the
      # generic page route, but are constrained before becoming dynamic tokens:
      # offsets/maxima are numeric (or All), and searches cannot contain OML or
      # markup delimiters that a helper could promote through GETTOKEN.
      my $field_value = scalar $O->{_cgi}->param($ff);
      $field_value = '' if (!defined($field_value));
      my $page_value_valid = 1;
      if ($is_page_field) {
        my $suffix = substr($upper, -1, 1);
        $page_value_valid = ($suffix eq 'Q')
          ? (length($field_value) <= 256
            && $field_value !~ /[\x00-\x1f\x7f#<>"`]/)
          : ($field_value =~ /\A(?:[0-9]{1,9}|All)\z/i);
      }
      if ((!$is_data_field && !$is_page_field)
          || ($is_data_field && !$mutation_post)
          || !$page_value_valid || $reserved || $seen{$upper}++) {
        $O->{_InvalidFormFieldsInput} = 1;
        $O->_InvalidRequestParameter();
        next;
      }
      $ffToken = $ff;
      # Don't use Required indicator (_req) for storing value
      $ffToken =~ s/_req$//i;
      $O->SetParamTokens('', $ff, $ffToken, '');
      push @valid_fields, $ff;
    }
  }
  $O->SetUntrustedToken($CGIparam, join(',', @valid_fields));
  undef @FIELDARR;

  return @valid_fields ? 1 : 0;
} #SetFormFields


#*******************************************************************************
#
# SetParamTokens($CGIabbrev, $CGIparam, $OToken, $value)
#
# - Set the page parameters as Tokens
#
#*******************************************************************************
sub Orbit::SetParamTokens
{
  my ( $O, $CGIabbrev, $CGIparam, $OToken, $value ) = @_;
  my $A = $O->{_Akashic};
  my $U = $A->{_Utils};

  $value = "" if (!defined($value));

  #
  # Get the CGI environment params if no value specified
  #
  if ($value eq "") {
    $value = $O->getCGIParam($CGIabbrev) if (defined($CGIabbrev) && $CGIabbrev ne "");
    $value = $O->getCGIParam($CGIparam) if (defined($CGIparam) && $CGIparam ne "" && (!defined($value) || $value eq ""));
    $value = "" if (!defined($value));
  }

  if (ref($value)) {
    $O->_InvalidRequestParameter();
    $value = '';
  }

  # Trim the spaces
  $value = $U->trim($value);

  # Structural request selectors are validated before any state/path setter sees them.
  $value = $O->_ValidateRequestParameter($CGIparam, $value);

  ##########################################
  # DEFAULTS
  ##########################################
  #
  # WORD DEFAULTS
  if ($CGIparam eq 'word') {
    # Change underscores (_) to spaces if this word is a phrase
    $value =~ s/_/ /g;
    # Set the other word type tokens if this param is 'word'
    if ($value ne '' && !$O->SetWordTokens($value)) {
      $O->_InvalidRequestParameter();
      $value = '';
    }
  }

  #
  # PAGE DEFAULTS
  $value = 'DEFAULT' if ($CGIparam eq 'page' && $value eq "");

  #
  # LANG DEFAULTS
  if ($CGIparam eq 'lang') {
    $value = 'ENG' if ($value eq "");
    # Set the _Lang for the user in Orbit - also sets the Lang variable in Akashic
    $O->SetLanguage($value);
    $O->SetUntrustedToken('LANG', $O->Get_Token('LANG'));
    my $Root = $O->Get_Token('Root');
    # Reset Langs root to the specific language
    if ($Root eq '' || $Root =~ /^LANGS$/i) {
      # Set the Root variable to LANGS.<lang>
      $O->SetRoot('LANGS.'.$value);
    }
  }

  #
  # ROOT DEFAULTS
  if ($CGIparam eq 'root') {
    # Set ROOT if not specified to LANGS/ENG
    $value = 'LANGS' if ($value eq '');   # Default root to LANGS

    # Root is a directory selector.  Public requests may address content roots only;
    # internal namespaces (_ORBIT, _ROOT, and any underscored segment), traversal,
    # backslashes, and control characters are never valid CGI input.
    my $safe_root = uc($value);
    $safe_root =~ s/\./\//g;
    if (length($safe_root) > 160
      || $safe_root !~ m{\A[A-Z0-9-]+(?:/[A-Z0-9-]+)*\z}
      || $safe_root =~ m{(?:^|/)_}
      || $safe_root =~ /\.\.|[\\\x00-\x1f\x7f]/
      ) {
      $O->RegisterError('#MSG[Invalid root]#');
      $O->{_InvalidRootInput} = 1;
      $value = 'LANGS';
    }
    if ($value =~ /^LANGS$/i) {
      my $Lang = $O->Get_Token('LANG');
      $value .= '.'.$Lang if ($Lang ne '');
    }
    # Set the Root variable to LANGS.<lang>
    $O->SetRoot($value);
    $O->SetUntrustedToken('ROOT', $O->Get_Token('ROOT'));
  }

  #
  # DOMAIN DEFAULTS
  if ($CGIparam eq 'domain') {
    # Set DOMAIN directory if not specified
    $value = $A->GetVar('Domain') if ($value eq '');   # Default root to LANGS
    # Set the Root variable to LANGS.<lang>
    $A->SetVar('Domain', $value);
    $O->SetDomain($value, $A->GetVar('DomainDir'));
  }

  #
  # Set the Token in Orbit if specified
  #
  if ($OToken ne "") {
    $O->SetUntrustedToken($OToken, $value);
  }

  ##########################################
  # END: DEFAULTS
  ##########################################

  return $value;

} #SetParamTokens


#*******************************************************************************
#
# SetWordTokens($pWord, $bNoPartial)
#
# - Set the Word tokens for use in Akashic Orbit pages
#
#*******************************************************************************
sub Orbit::SetWordTokens
{
  my ( $O, $pWord, $bNoPartial ) = @_;

  return if (!defined($pWord) || ref($pWord) || $pWord eq "");
  $bNoPartial = '0' if (!defined($bNoPartial) || $bNoPartial ne '1');

  my $A = $O->{_Akashic};
  my $WordType = "";
  my $found = 1;

  #
  # Get the appropriate Word Type of object: WORD PHRASE PATH
  #
  # WORD
  if ($A->isWord($pWord)) {
    $WordType = "Word";
    $O->SetUntrustedToken('_WORD_', $pWord);
  # PHRASE
  } elsif ($A->isPhrase($pWord)) {
    $WordType = "Phrase";
    $O->SetUntrustedToken('_PHRASE_', $pWord);
  # PATH
  } elsif ($A->isPath($pWord)) {
    $WordType = "Path";
    $O->SetUntrustedToken('_PATH_', $pWord);
  } else {
    $WordType = "Bad Word";
    my $safe_word = $pWord;
    $safe_word =~ s/&/&amp;/g;
    $safe_word =~ s/</&lt;/g;
    $safe_word =~ s/>/&gt;/g;
    $safe_word =~ s/"/&quot;/g;
    $safe_word =~ s/'/&apos;/g;
    $safe_word =~ s/#/&num;/g;
    $O->SetUntrustedToken('_BADWORD_', $safe_word, 1);
    $O->RegisterMessage("#MSG_BADWORD#");
    $O->Set_Token('_WORDTYPE_', $WordType);
    return 0;
  }

  $O->Set_Token('_WORDTYPE_', $WordType);

  # Get the Next Root if specified
  my $nextRoot = $O->Get_Token('NROOT');

  # Get the context directory for Word/Phrase/Path
  my $WordDir = "";
  #if ($nextRoot eq "") {
    $WordDir = $A->GetTextDir($O->GetRoot(), $pWord);
  #} else {
  #  $WordDir = $A->GetTextDir($nextRoot, $pWord);
  #}

  # Make sure directory exists and set WORDFOUND
  if (-d $WordDir) {
    $O->Set_Token('_WORDFOUND_', '1');
    $O->Set_Token('_WORDDIR_', $WordDir);
    
    # Set the object to WORD if it was SEARCH and we found a word
    if ($O->GetToken('OBJECT') =~ /.*SEARCH.*/i) {
      $O->SetToken('OBJECT', 'WORD');
    }
  } elsif (!$bNoPartial) {
    # Get the partial lowest directory since it doesn't exist (maybe a new word)
    $O->RegisterMessage("#MSG_WORDNOTFOUND#");

    # Get partial directory
    $WordDir = $A->GetPartialDir($WordDir);

    # Make sure the directory exists now
    if (!-d $WordDir) {
      # Directory does not exist - Start back at home
      $O->Set_Token('PAGE', 'DEFAULT');
      $WordDir = "";
    }

    # Check for partial word directory to show suggestions
    if ($WordDir ne "") {
      $O->SetUntrustedToken('_PARTIALWORD_', $A->GetPartialWord( $WordDir ));
    }
    $O->Set_Token('_WORDDIR_', $WordDir);
  }

  return 1;
} #SetWordTokens


#*******************************************************************************
#
# UploadFile($CGIParam, $Filename, $Location)
#
#   - Process an uploaded file
#
#*******************************************************************************
sub Orbit::UploadFile
{
  my ( $self, $CGIParam, $Filename, $Location ) = @_;
  
  $Filename = "" if (!defined($Filename) || $Filename eq '');
  
  #
  # Get just the filename without path information
  #
  $Filename =~ s/.*[\/\\](.*)/$1/;
  
  my $UPLOAD_HANDLE = $self->{_cgi}->upload("upload");
  
  open UPLOAD, ">$Location/$Filename";
  binmode UPLOAD;
  
  while ( <$UPLOAD_HANDLE> )
  {
    print UPLOAD;
  }
  close UPLOAD;
  
} #UploadFile


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic;
#******************************************************************************************
1;

#END Orbit::Akashic;
