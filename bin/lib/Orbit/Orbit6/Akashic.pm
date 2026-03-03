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
#*******************************************************************************
package Orbit;
use strict;
use warnings;
use File::Find;

#
# Load the Akashic core and Utilities, and Earth addons
#
use Orbit::Orbit6::Print;
use Orbit::Orbit6::Config;
use Akashic::Earth;


################################################################################
#
# initOrbitAkashic()
#
# - Initialize Orbit/Akashic connection
#
################################################################################
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


################################################################################
#
# SetInputParams()
#
# - Define the primary parameters for Akashic earth.love pages
#
################################################################################
sub Orbit::SetInputParams
{
  my ( $O ) = @_;
  #
  # Define the primary parameters for Akashic earth.love pages
  # Initialize and get parameters from CGI
  $O->SetParamTokens('d',  'domain', 'DOMAIN', '');
  $O->SetParamTokens('r',  'root',   'ROOT',   '');
  $O->SetParamTokens('o',  'object', 'OBJECT', '');
  $O->SetParamTokens('l',  'lang',   'LANG',   '');
  $O->SetParamTokens('w',  'word',   'WORD',   '');
  $O->SetParamTokens('p',  'page',   'PAGE',   '');
  $O->SetParamTokens('m',  'menu',   'MENU',   '');
  $O->SetParamTokens('pm', 'pmenu',  'PMENU',  '');
  $O->SetParamTokens('s',  'step',   'STEP',   '');
  $O->SetParamTokens('z',  'steps',  'STEPS',  '');
  $O->SetParamTokens('a',  'action', 'ACTION', '');
  # Set the form fields as tokens as passed in with 'formfields'
  $O->SetFormFields('ff',  'formfields');

} #SetInputParams


################################################################################
#
# SetFormFields()
#
# - Set and get the form fields from the "formfields" parameter
#
################################################################################
sub Orbit::SetFormFields
{
  my ( $O, $CGIabbrev, $CGIparam ) = @_;

  # Get and set FORMFIELDS Token
  my $Fields = $O->SetParamTokens($CGIabbrev, $CGIparam, $CGIparam, '');

  return 0 if (!defined($Fields) || $Fields eq '');

  # Create an array of the form fields
  my @FIELDARR = split(',', $Fields);
  my $ffToken = "";

  # Loop through the Form Fields array and set Tokens from the parameters
  foreach my $ff (@FIELDARR) {
    if ($ff ne "") {
      $ffToken = $ff;
      # Don't use Required indicator (_req) for storing value
      $ffToken =~ s/_req$//i;
      $O->SetParamTokens('', $ff, $ffToken, '');
    }
  }
  undef @FIELDARR;

  return 1;
} #SetFormFields


################################################################################
#
# SetParamTokens()
#
# - Set the page parameters as Tokens
#
################################################################################
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

  # Trim the spaces
  $value = $U->trim($value);

  ##########################################
  # DEFAULTS
  ##########################################
  #
  # WORD DEFAULTS
  if ($CGIparam eq 'word') {
    # Change underscores (_) to spaces if this word is a phrase
    $value =~ s/_/ /g;
    # Set the other word type tokens if this param is 'word'
    $O->SetWordTokens($value);
  }

  #
  # PAGE DEFAULTS
  $value = 'DEFAULT' if ($CGIparam eq 'page' && $value eq "");

  #
  # LANG DEFAULTS
  if ($CGIparam eq 'lang') {
    $value = 'ENG' if ($value eq "");
    # Set the Lang variable in Akashic
    $A->SetVar('Lang', $value);
    my $Root = $O->Get_Token('Root');
    # Reset Langs root to the specific language
    if ($Root eq '' || $Root =~ /^LANGS$/i) {
      # Set the Root variable to LANGS.<lang>
      $A->SetVar('Root', 'LANGS.'.$value);
      $O->SetRoot($value, $A->GetVar('RootDir'));
      $O->Set_Token('ROOT', 'LANGS.'.$value);
    }
  }

  #
  # ROOT DEFAULTS
  if ($CGIparam eq 'root') {
    # Set ROOT if not specified to LANGS/ENG
    $value = 'LANGS' if ($value eq '');   # Default root to LANGS
    if ($value eq "" || $value =~ /^LANGS$/i) {
      $value = $O->Get_Token('LANG');
      if ($value ne '') {
        $value = 'LANGS.'.$value;
      }
    }
    # Set the Root variable to LANGS.<lang>
    $A->SetVar('Root', $value);
    $O->SetRoot($value, $A->GetVar('RootDir'));
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
    $O->Set_Token($OToken, $value);
  }

  ##########################################
  # END: DEFAULTS
  ##########################################

  return $value;

} #SetParamTokens


################################################################################
#
# SetWordTokens()
#
# - Set the Word tokens for use in Akashic Orbit pages
#
################################################################################
sub Orbit::SetWordTokens
{
  my ( $O, $pWord, $bNoPartial ) = @_;

  return if (!defined($pWord) || $pWord eq "");
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
    $O->Set_Token('_WORD_', $pWord);
  # PHRASE
  } elsif ($A->isPhrase($pWord)) {
    $WordType = "Phrase";
    $O->Set_Token('_PHRASE_', $pWord);
  # PATH
  } elsif ($A->isPath($pWord)) {
    $WordType = "Path";
    $O->Set_Token('_PATH_', $pWord);
  } else {
    $WordType = "Bad Word";
    $O->Set_Token('_BADWORD_', $pWord);
    $O->RegisterMessage("#MSG_BADWORD#");
    $O->Set_Token('_WORDTYPE_', $WordType);
    return 0;
  }

  $O->Set_Token('_WORDTYPE_', $WordType);

  # Get the context directory for Word/Phrase/Path
  my $WordDir = $A->GetTextDir($O->GetRoot(), $pWord);

  # Make sure directory exists and set WORDFOUND
  if (-d $WordDir) {
    $O->Set_Token('_WORDFOUND_', '1');
    $O->Set_Token('_WORDDIR_', $WordDir);
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
      $O->Set_Token('_PARTIALWORD_', $A->GetPartialWord( $WordDir ));
    }
    $O->Set_Token('_WORDDIR_', $WordDir);
  }

  return 1;
} #SetWordTokens


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic;
#******************************************************************************************
1;

#END Orbit::Akashic;
