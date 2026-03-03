#!/usr/bin/perl
# Version 1.0.1.0      27-Jun-2021
#*******************************************************************************
#
# Akashic::Data.pm
#
# Data File Read Utility (Get Data) subroutines for the Akashic class
#
#*******************************************************************************
# History:
#   2021.06.27 earth.love oK Refactored from Akashic::Utils
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Akashic for Perl.
#
# Akashic for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Akashic for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Akashic for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
#----------------------------------------#
# Datafile Read Utilities
#----------------------------------------#
#
# GetPartialDir <directory>
#   - Returns the lowest directory that exists in the directory path
#
# GetPartialWord <directory>
#   - Returns the letters/words of the word/phrase for the PartialDir
#
# GetWordDataFileDir <root> <word=word/phrase/path> <Index=datafile.dat> <bRelPath>
#   - Returns the fully structured filename associated with the Root, Word, Datafile, "" if not exists.
#   - Word (File) is searched off the Domain and ROOT in WORDS/PHRASES/PATHS
#   - The Datafile extension defaults to .dat, and does not need to be included on the Datafile
#   - An alternate Datafile extension may be provided by simply including it on the Datafile name.
#     Alternate extensions are searced and validated in _DataExtAlt (.txt .oml .log)
#   - bRelPath (1/0) - Return Relative Path to Domain, including Root and Word/Phrase/Path directory
#
# GetWordData <root> <phrase/word/path> <datafile.dat> [Search] [StartLine] [MaxLines]
#   - Return the contents of the file in an @ARRAY
#   - File is searched off the earth.love Domain and ROOT in WORDS/PHRASES/PATHS
#
# GetWordText <root> <phrase/word/path> <datafile.dat> [Search] [StartLine] [MaxLines]
#   - Return the contents of the file as a string with carriage returns (Raw text return)
#   - File is searched off the Akashic Domain and ROOT specified (_WORDS/_PHRASES/_PATHS)
#
# GetWordField <root> <phrase/word/path> <datafile.dat>
#   - Return the first line of the datafile, which holds only one data element
#
# GetWordRecord <root> <phrase/word/path> <datafile.dat>
#   - Return the first record of the datafile, which holds a delimited set of values
#
# GetFile <filename> <separator>
#   - Returns the contents of the file as a string with carriage returns
#   - Expects a fully qualified or relative filename (with directory prefix)
#   - <separator> specifies record separator (default \n)
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#
# Load Akashic core
#
use Akashic::Utils;


################################################################################
# DATA FILE ROUTINES
################################################################################


################################################################################
#
# GetPartialDir <directory>
#
# - Returns the lowest directory that exists in the directory path
#
################################################################################
sub Akashic::GetPartialDir
{
  my ( $self, $Dir ) = @_;

  my $lPath = "";

  # Build an array of directories from the one passed in
  my @DIRS = split('/', $Dir);

  # Return lowest directory that exists
  # i.e. w/o/r/d/s/words -> maybe returns w/o/r (which contains DOWN.dat for searching)
  # Check until we don't find a valid directory
  foreach my $d (@DIRS) {
    $d .= '/';
    # Skip Domain and Root directory for a partial directory
    if ($d eq $self->{_DomainDir} || $d eq $self->{_RootDir}) {
      $lPath = $lPath.$d;
      next;
    }
    last if (!-d $lPath.$d);
    $lPath = $lPath.$d;
  }
  # Free array memory
  undef @DIRS;

  # Don't return Domain or Root directory for a partial directory
  $lPath = "" if ($lPath eq $self->{_DomainDir} || $lPath eq $self->{_RootDir});
  $lPath = "" if (!-d $lPath);

  # Set the package variable for partial directory so other processes can access
  if ($lPath ne "") {
    $self->{_PartialDir} = $lPath;
  }

  return $lPath;
} #GetPartialDir


################################################################################
#
# GetPartialWord <directory>
#
# - Returns the letters/words of the word/phrase for the PartialDir
#
################################################################################
sub Akashic::GetPartialWord
{
  my ( $self, $Dir ) = @_;

  my $type = "";
  my $bFound = 0;
  $Dir = $self->{_PartialDir} if (!defined($Dir) || $Dir eq "");
  return ""  if (!defined($Dir) || !-d $Dir);

  # Remove trailing / if present
  $Dir =~ s/\/$//g;

  # Check for WORD path - strip off everything up to and including
  $type = $self->{_WORDS};
  if (index($Dir, $type) != -1) {
    $Dir =~ s/^.*$type//g;
    $Dir =~ s/\///g;
    $bFound = 1;
  } elsif (index($Dir, $self->{_PHRASES}) != -1) {
    # Check for PHRASES path
    $type = $self->{_PHRASES};
    $Dir =~ s/^.*$type//g;
    $Dir =~ s/\// /g;
    $bFound = 1;
  } elsif (index($Dir, $self->{_PATHS}) != -1) {
    # Check for PATHS path
    $type = $self->{_PATHS};
    $Dir =~ s/^.*$type//g;
    $Dir =~ s/\//\./g;
    $bFound = 1;
  }

  $Dir = "" if (!$bFound);

  return $Dir;
} #GetPartialWord


################################################################################
#
# GetWordDataFileDir <root> <word=word/phrase/path> <Index=datafile.dat> <bRelPath>
#
# - Returns the fully structured filename associated with the Root, Word, Datafile, "" if not exists.
# - Word (File) is searched off the Domain and ROOT in WORDS/PHRASES/PATHS
# - The Datafile extension defaults to .dat, and does not need to be included on the Datafile
# - An alternate Datafile extension may be provided by simply including it on the Datafile name.
#   Alternate extensions are searced and validated in _DataExtAlt (.txt .oml .log)
# - bRelPath (1/0) - Return Relative Path to Domain, including Root and Word/Phrase/Path directory
#
################################################################################
sub Akashic::GetWordDataFileDir
{
  my ( $self, $Root, $Word, $DataFile, $bRelPath ) = @_;

  $Root = "_ROOT" if (!defined($Root) || $Root eq "");
  # Standardize Root
  $Root = $self->StandardizeRoot($Root);

  # Default Relative Path OFF - return Fully Qualified path  
  $bRelPath = 0 if (!defined($bRelPath) || $bRelPath ne '1');

  $Word = "_ROOT" if (!defined($Word) || $Word eq "");

  # Reset the PartialDir variable
  $self->{_PartialDir} = "";

  # Simple check for all parameters present
  return "" if (!defined($DataFile) || $DataFile eq "" || $Word eq "");

  # Get any data extension if specified
  my $DataExt = "";
  if (index($DataFile, '.') != -1) {
    $DataExt =~ s/^.*\./\./g;
    $DataExt =~ tr/[A-Z]/[a-z]/;   # Lowercase data extension by convention
  }

  # Leave if we don't have a valid Data Extension if present (not in _DataExtAlt)
  if ($DataExt ne ""
    && $DataExt ne $self->{_DataExt}
    && index($self->{_DataExtAlt}, ','.$DataExt.',') == -1
    ) {
    return "";
  }

  # Add the DEFAULT datafile extension if missing, and auto capitalize datafile
  if (index($DataFile, '.') == -1) {
    # Data files are capitalized by convention (if not specified with an extension)
    $DataFile =~ tr/[a-z]/[A-Z]/;
    $DataFile .= $self->{_DataExt};
  }

  my $lDataFile = "";
  my $WordDir = "";
  my $RelDir = "";   # Relative Directory

  #
  # Get the datafile fully qualified name
  #
  # Get the cached directory if available so we don't need to look it up every time
  if ( $Word eq $self->{_gWordCache}   # input word is cached (match on case exactly
    && $Root eq $self->{_Root}         # ROOT has to be the same as well
    && defined($self->{_gWordDirCache})
    && $self->{_gWordDirCache} ne ""
    && !$bRelPath
    ) {
    # Use the cached directory and add the datafile to the end
    $lDataFile = $self->{_gWordDirCache}.$DataFile;
  } else {
    # Get the appropriate home directory for the WORD/PHRASE/PATH relative to ROOT
    if      ($Root eq '_DOM') {
      # Special case: _DOM is the Domain home directory
      $WordDir = $self->{_DomainDir};
      $RelDir  = '';
    } elsif ($Word eq '_ROOT') {
      # Set the ROOT off the Domain
      $self->SetVar('Root', $Root);  # Other logic fires when we change the ROOT
      # Special case: _ROOT is the Root home directory
      $WordDir = $self->{_RootDir};
      $RelDir  = $self->{_Root}.'/';
    } else {
      $RelDir  = $self->GetTextDir($Root, $Word, 1);   # Get Relative Directory
      $WordDir = $self->{_RootDir}.$RelDir;
    }

    #
    # Special case for DOWN and INDEX when searching for undefined word directory
    # Search up the tree to find the file
    #
    if (!-d $WordDir) {
      my $bPartialDir = 0;
      if ($DataFile eq $self->{_Data}->{'_DOWN'}
        ||$DataFile eq $self->{_Data}->{'_INDEX'}
          ) {
        #
        # Get partial directory
        #
        $WordDir = $self->GetPartialDir($WordDir);
        # If not found or above root, set to null
        if ($WordDir eq "" || index($WordDir, $self->{_DomainDir}) != 0) {
          $WordDir = "";
        }
      }

      # Don't use cachedir for partial directories
      $self->{_gWordCache}    = "";
      $self->{_gWordDirCache} = "";
    } elsif (!$bRelPath && -e $WordDir.$DataFile) {
      # Reset the cache directory name
      # Don't reset for Relative Directories
      # Essentially, this procedure maintains the cache variables
      $self->{_gWordCache}    = $Word;
      $self->{_gWordDirCache} = $WordDir;
    }

    # Make sure WordDir exists
    if ($WordDir ne "" && -d $WordDir) {
      # Set the filename to check below
      $lDataFile = $WordDir.$DataFile;
    } else {
      # Not under domain directory - leave
      return "";
    }
  }

  # See if the datafile exists
  if ($lDataFile ne "" && -e $lDataFile) {
    # See if we're returning the relative path
    if (!$bRelPath) {
      # Return Full path
      return $lDataFile;
    } else {
      # Return Relative path
      return $RelDir.$DataFile;
    }
  }

  # Data file not found
  return "";
} #GetWordDataFileDir


################################################################################
#
# GetWordData <root> <phrase/word/path> <datafile.dat> [Search] [StartLine] [MaxLines]
#
# - Return the contents of the file in an @ARRAY
# - File is searched off the earth.love Domain and ROOT in WORDS/PHRASES/PATHS
# - MAKE SURE TO "undef @arr" after you've used the data
# - Search     - filter out the lines of the file by this phrase (optional)
# - StartLine  - line number (offset 1) to start reading
# - MaxLines   - Maximum number of lines to read and return
#
################################################################################
sub Akashic::GetWordData
{
  my ( $self, $Root, $Word, $DataFile, $lSearch, $lStartLine, $lMaxLines ) = @_;
  use Core::Search;
  my $U = $self->{_Utils};

  my @arr;

  $Word = "" if (!defined($Word));
  $Root = "" if (!defined($Root));
  $lSearch = "" if (!defined($lSearch));
  # Defaults for Start/Max
  $lStartLine  = 1  if (!defined($lStartLine) || !($lStartLine =~ /.*[-0-9.].*/));   # Make sure a number is present
  $lMaxLines   = -1 if (!defined($lMaxLines)  || !($lMaxLines  =~ /.*[-0-9.].*/));

  # Standardize the search expression
  $lSearch = $U->FixSearchString($lSearch);

  # Simple check for all parameters present
  if (!defined($DataFile) || $DataFile eq "") {
    $DataFile = "";
    # Leave silently - not a real request
    #$self->Uprint("GetWordData Error: File not specified [$Root][$Word][$DataFile]\n");
    return @arr;
  }

  #
  # Get the Datafile full path
  #
  my $lDataFile = $self->GetWordDataFileDir($Root, $Word, $DataFile);
  return @arr if ($lDataFile eq "" || !-e $lDataFile);

  #
  # Open the file and read the contents
  #
  my $row = 0;
  my $i = 0;
  open(DFILE, '<', $lDataFile) or die;  # UTF-8 Fix
#  open(DFILE, '<:encoding(UTF-8)', $lDataFile) or die;
  while (<DFILE>) {
    $row++;
    $_ =~ s/\n//;   # remove CR
    # Check the search expression
    if ( $lSearch eq ""
      || $_ =~ m/^.*$lSearch.*$/i
      || $U->FindInList($_, $lSearch, "", 1)
      ) {
      # Get the specifed rows for Start/Max, or all if not specified
      if ($row >= $lStartLine
        && ( $lMaxLines == -1
          || $row <= $lStartLine + $lMaxLines-1
          )
        ) {
        # Assign line to the array
        $arr[$i] = $_;
        $i++;
      }
    } else {
      # did not process row
      $row--;
    } #if search
    # Leave if this is the last row we read
    last if ($lMaxLines != -1 && $row >= $lStartLine + $lMaxLines-1);
  }
  close(DFILE);

  return @arr;
} #GetWordData


################################################################################
#
# GetWordText <root> <phrase/word/path> <datafile.dat> [Search] [StartLine] [MaxLines]
#
# - Return the contents of the file as a string with carriage returns (Raw text return)
# - File is searched off the Akashic Domain and ROOT specified (_WORDS/_PHRASES/_PATHS)
################################################################################
sub Akashic::GetWordText
{
  my ( $self, $Root, $Word, $DataFile, $lSearch, $lStartLine, $lMaxLines ) = @_;
  use Core::Search;
  my $U = $self->{_Utils};

  $Root = "" if (!defined($Root));
  $Word = "" if (!defined($Word));
  $lSearch = "" if (!defined($lSearch));
  # Defaults for Start/Max
  $lStartLine  = 1  if (!defined($lStartLine) || !($lStartLine =~ /.*[-0-9.].*/));   # Make sure a number is present
  $lMaxLines   = -1 if (!defined($lMaxLines)  || !($lMaxLines  =~ /.*[-0-9.].*/));

  # Standardize the search expression
  $lSearch = $U->FixSearchString($lSearch);

  # Simple check for all parameters present
  if (!defined($DataFile) || $DataFile eq "") {
    $DataFile = "";
    $self->Uprint("GetWordText Error: File not specified [$Root][$Word][$DataFile]\n");
    return "";
  }

  # Get the Datafile full path
  my $lDataFile = $self->GetWordDataFileDir($Root, $Word, $DataFile);
  return "" if ($lDataFile eq "");

  my $lContents = "";

  #
  # Open the file
  #
  open(DFILE, '<', $lDataFile);  # UTF-8 Fix
#  open(DFILE, '<:encoding(UTF-8)', $lDataFile);

  #
  # Simple Case - read entire file - no search/start/max
  #
  if ($lSearch eq "" && $lStartLine == 1 && $lMaxLines == -1) {
    while (<DFILE>) {
      # Assign line to the buffer
      $lContents .= $_;
    }
  } else {
    #
    # Processing for Search/Start/Max
    #
    my $row = 0;
    while (<DFILE>) {
      $row++;
      $_ =~ s/\n//;   # remove CR
      # Check the search expression
      if ( $lSearch eq ""
        #|| $_ =~ m/^.*$lSearch.*$/i
        || $U->FindInList($_, $lSearch, "", 1)
        ) {
        # Get the specifed rows for Start/Max, or all if not specified
        if ($row >= $lStartLine
          && ( $lMaxLines == -1
            || $row <= $lStartLine + $lMaxLines-1
            )
          ) {
          # Assign line to the buffer
          $lContents .= $_."\n";
        }
      } else {
        # did not process row
        $row--;
      } #if search
      # Leave if this is the last row we read
      last if ($lMaxLines != -1 && $row >= $lStartLine + $lMaxLines-1);
    }
  }
  close(DFILE);

  # Return the RAW text from the file
  return $lContents;
} #GetWordText


################################################################################
#
# GetWordField <root> <phrase/word/path> <datafile.dat>
#
# - Return the first line of the datafile, which holds only one data element
################################################################################
sub Akashic::GetWordField
{
  my ( $self, $Root, $Word, $DataFile ) = @_;

  $Root = "" if (!defined($Root));
  # Phrase = _ROOT to access datafiles in the _ROOT directory (name, color, created, updated, CATALOGS LINKS etc)
  $Word = "" if (!defined($Word));

  # Simple check for all parameters present
  if (!defined($DataFile) || $DataFile eq "") {
    $DataFile = "";
    $self->Uprint("GetWordText Error: File not specified [$Root][$Word][$DataFile]  Use phrase '_ROOT' for root access.\n");
    return "";
  }

  # Get the Datafile full path
  my $lDataFile = $self->GetWordDataFileDir($Root, $Word, $DataFile);
  return "" if ($lDataFile eq "");

  my $lContents = "";

  #
  # Open the file and read the contents
  #
  # NOTE: Future development for limiting records read
  #
  my $row = 0;
  open(DFILE, '<', $lDataFile) or die;   # UTF-8 Fix
#  open(DFILE, '<:encoding(UTF-8)', $lDataFile) or die;
  $lContents = <DFILE>;
  $lContents =~ s/\n//;   # remove CR
  close(DFILE);

  # Return the RAW text from the file
  return $lContents;
} #GetWordField


################################################################################
#
# GetWordRecord <root> <phrase/word/path> <datafile.dat>
#
# - Return the first record of the datafile, which holds a delimited set of values
#
################################################################################
sub Akashic::GetWordRecord
{
  my ( $self, $Root, $Word, $DataFile ) = @_;
  
  $Root = "" if (!defined($Root));
  $Word = "" if (!defined($Word));

  # Simple check for all parameters present
  if (!defined($DataFile) || $DataFile eq "") {
    $DataFile = "";
    $self->Uprint("GetWordText Error: File not specified [$Root][$Word][$DataFile]\n");
    return "";
  }

  # Get the Datafile full path
  my $lDataFile = $self->GetWordDataFileDir($Root, $Word, $DataFile);
  return "" if ($lDataFile eq "");

  my $lContents = "";
  my @HEAD;
  my @DATA;

  #
  # Open the file and read the contents
  #
  # NOTE: Future development for limiting records read
  #
  my $row = 0;
  open(DFILE, '<', $lDataFile) or die;   # UTF-8 Fix
#  open(DFILE, '<:encoding(UTF-8)', $lDataFile) or die;
  $lContents = <DFILE>;
  $lContents =~ s/\n//;   # remove CR
  if ($lContents =~ /^!HEAD:.*$/i
    ||$lContents =~ /^!HEADER:.*$/i
    ||$lContents =~ /^!H:.*$/i
    ) {
    # Get the array of columns
    @HEAD = split('|', $lContents);
    # Get the data record next
    $lContents = <DFILE>;
    $lContents =~ s/\n//;   # remove CR
  }
  close(DFILE);

  # Build data array with colums as the Hash

  undef @HEAD;

  # Return the RAW text from the file
  return @DATA;
} #GetWordRecord


################################################################################
#
# GetFile <filename> <separator>
#
# - Returns the contents of the file as a string with carriage returns
# - Expects a fully qualified or relative filename (with directory prefix)
# - <separator> specifies record separator (default \n)
#
################################################################################
sub Akashic::GetFile
{
  my ( $self, $lFile, $SEP ) = @_;
  
  my $lContents="";

  # Simple check for all parameters present
  if (!defined($lFile) || $lFile eq "") {
    $self->Uprint("Error: File not passed to GetFile [$lFile]\n");
  }

  $SEP = "" if (!defined($SEP));

  # See if the datafile exists
  if (!-e $lFile) {
    # No  file by this name - return empty string
    $self->Uprint("GetFile: File not found: [$lFile]\n");
    return "";
  }

  #
  # Open the file and read all of the lines
  #
  open(DFILE, '<', $lFile)   # UTF-8 Fix
#  open(DFILE, '<:encoding(UTF-8)', $lFile)
    or die "GetFile: File not found during open: [$lFile]\n";
  while (<DFILE>) {
    if ($SEP ne "") {
      $_ =~ s/\n//;
      $_ .= $SEP;
    }
    $lContents .= $_;
  }
  close(DFILE);

  # Remove trailing SEP
  if ($SEP ne "") {
    $lContents = substr($lContents, 0, length($lContents)-length($SEP)) if (substr($lContents, length($lContents)-length($SEP)) eq $SEP);
  }

  # Return the RAW text from the file
  return $lContents;
} #GetFile


################################################################################
# END OF Akashic::Data.pm
################################################################################
1;
