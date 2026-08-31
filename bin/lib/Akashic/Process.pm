#!/usr/bin/perl
# Version 1.0.1.0      06-June-2021
#*******************************************************************************
#
# Akashic::Process.pm - Additions to the Akashic class for processing
#
# Utility subroutines for Processing text files for the Akashic data structures.
#
#*******************************************************************************
# History:
#   2021.05.12 earth.love oK Created from script to store in the class
#   2021.04.16 earth.love oK refactored from processtext.pl
#   2021.04.14 earth.love oK Updated
#   2021.04.07 earth.love oK Updated
#   2021.04.04 earth.love oK Created
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
# PROCESS MANAGEMENT
#----------------------------------------#
#
# SetFilesInput <filename(s)>
#   - Set Input Files specification for processing
#
# GetFilesInput()
#   - Get Input Files specification
#
# ShowProcessingHeader()
#   - Show the environment setup
#
# SetStartTime()
#   - Get the start time and remove CR
#
# TimeDiffHMS <starttime> <endtime>
#   - Returns the Hours:Minutes:Seconds based on the time difference in seconds
#   - Use stamdard time() to get start and end
#
# ShowStatistics()
#   - Show the summary statistics
#
# ProcessWords  (<TextFile(s)>/"<STDIN>") <ROOT> <SHOW_STATS> <SORT_DATA>
#   - Processes the text file or files into the Akashic database
#   - Process all lines of the text file(s) or standard input and stores the text in either:
#     WORDS   - text is a plain word (ignoring punctuation) without space or dot [ .]
#     PHRASES - text contains spaces between words ("word phrase")
#     PATHS   - text contains dot between words and no spaces ("word.path.earth")
#   If no filenames are specified, reads from standard input <STDIN>.
#   - SHOW_STATS (1/0) - Show statistics; default 1
#   - SORT_DATA  (1/0) - (1) Sort data automatically (CAT.dat, CATS.dat, INDEX.dat, DOWN.dat); default 1
#                      - (0) Sort the datafiles after the process
#                      - This is a huge performance boost when adding large data sets, especially paths like Locations or Domains
#   - Check ShowProcessUsage below for more details on Environment Variables.
#   NOTE: PROCESS_words.pl is provided to call this subroutine from the command line
#
# ProcessTrees(files) - DEVELOPMENT
#
# ProcessPaths(files) - DEVELOPMENT
#
# ProcessLOCS(files) - DEVELOPMENT
#
# ProcessCOMMS(files) - DEVELOPMENT
#
# ProcessGUILDS(files) - DEVELOPMENT
#
# ProcessPATHS(files) - DEVELOPMENT
#
# ProcessJOB(files) - DEVELOPMENT
#
# ProcessSELF(files) - DEVELOPMENT
#
# ProcessBooks(files) - DEVELOPMENT
#
# ProcessTimeLine(files) - DEVELOPMENT
#
#----------------------------------------#
# Domain Creation Subroutines
#----------------------------------------#
# MakeRootDir
#   - Create the RootDir based on the Root name, checking for Root Subdirs (ie LANGS/ENG)
#
# CreateWordBase <ROOT> <OBJECT> <NAME> <SHORT> <DESC> <COLOR>
#   - Create the _WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES directories
#     under the <ROOT> passed in, under the DomainDir
#   - ROOT defaults to _ROOT
#   - NAME, SHORT, DESC, COLOR are put in the ROOT directory as (NAME.dat DESC.dat COLOR.dat ...)
#
#----------------------------------------#
# Domain Maintenance Subroutines
#----------------------------------------#
# SortRootDataFiles ["<ROOT>*"] ["<word/phrase/path>*"] ["<datafile(s)>*"] [DaysBack]
#   - Refreshes the index data in the Akashic Domain Directory for the
#     ROOT(s) specified (blank is default for All roots in ROOTS.dat)
#   - Sort all of the index files (INDEX.dat, DOWN.dat, CAT.dat, CATS.dat) in the ROOT specified
#   - DaysBack - only sort files newer than this date (may be decimal: 0.25)
#   - Called by REFRESH_akashic.pl
#
# RefreshTreeData ["<ROOT>*"] ["<word/phrase/path>*"] ["<datafile(s)>*"] ["<TREE>*"] [DaysBack]
#   - Refreshes the cached data in TREES as changes occur in source data
#   - Called by REFRESH_trees.pl
#
#----------------------------------------#
# USAGE ROUTINES
#----------------------------------------#
#
# ShowProcessUsage()
#   - Show Usage and environment variables used
#
#*******************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';
use Cwd qw(abs_path);
use Fcntl qw(:mode);
use File::Find;
use File::Copy;   # Adds 'copy' and 'move' subs
use File::Spec;

#
# Load Akashic core and Write routine
#
use Akashic::Write;


#*******************************************************************************
#*******************************************************************************
# PROCESS MANAGEMENT
#*******************************************************************************
#*******************************************************************************


################################################################################
#
# SetFilesInput <filename(s)>
# GetFilesInput()
#
# - Set and Get routines for defining Input Files
#
################################################################################
sub Akashic::SetFilesInput
{
  my ( $self, $lFiles ) = @_;
  $self->{_gFiles} = $lFiles;
}
sub Akashic::GetFilesInput
{
  my ( $self  ) = @_;
  return $self->{_gFiles};
}


#*******************************************************************************
#
# ShowProcessingHeader
#
# - Show the environment setup
#
#*******************************************************************************
sub Akashic::ShowProcessingHeader
{
  my ( $self  ) = @_;

  # Show processing message
  $self->Uprint("==================================================\n");
  $self->Uprint(" Akashic Root : ".$self->{_RootDir}."\n");
  #$self->Uprint("   WORDS Dir   : ".$self->{_WORDS}."\n");
  #$self->Uprint("   PHRASES Dir : ".$self->{_PHRASES}."\n");
  #$self->Uprint("   PATHS Dir   : ".$self->{_PATHS}."\n");
  $self->Uprint("==================================================\n");
} #ShowProcessingHeader


#*******************************************************************************
#
# SetStartTime()
#
# - Get the start time and remove CR
#
#*******************************************************************************
sub Akashic::SetStartTime
{
  my ( $self  ) = @_;

  $self->{_gStartTime} = localtime();
} #SetStartTime


#*******************************************************************************
#
# TimeDiffHMS <starttime> <endtime>
#
# - Returns the Hours:Minutes:Seconds based on the time difference in seconds
# - Use stamdard time() to get start and end
#
#*******************************************************************************
sub Akashic::TimeDiffHMS
{
  my ( $self, $starttime, $endtime ) = @_;
  my $SECdiff = $endtime - $starttime;
  my $HMS = sprintf("%d:%02d:%02d"
              ,int($SECdiff/60/60)   # Hours
              ,int(($SECdiff - int($SECdiff/60/60)*60*60) / 60)    # Minutes
              ,$SECdiff   # Seconds - Hours - Minutes
                 - int($SECdiff/60/60)*60*60   # Horus
                 - int(($SECdiff - int($SECdiff/60/60)*60*60) / 60)*60    # Minutes
            );
  return $HMS;
} #TimeDiffHMS


#*******************************************************************************
#
# ShowStatistics()
#
# - Show the summary statistics
#
#*******************************************************************************
sub Akashic::ShowStatistics
{
  my ( $self  ) = @_;
  # Check for the SHOW stats directive
  return if (!$self->GetShowStats());

  #
  # Wrap Up and Print Summary
  #
  $self->{_gEndTime} = localtime();
  $self->{_gEndTime} =~ s/\n//;
  $self->Uprint("\n\n");
  # Only show if data present
  if ($self->{_gWordCnt} > 0) {
    $self->Uprint("-----------------------\n");
    $self->Uprint("-- WORDS Summary\n");
    $self->Uprint("-----------------------\n");
    $self->Uprint("Words  : ".$self->{_gWordCnt}."\n");
    $self->Uprint("Dupes  : ".$self->{_gWordDupeCnt}."\n");
    $self->Uprint("New    : ".$self->{_gWordNewCnt}."\n");
  }
  # Only show if data present
  if ($self->{_gPhraseCnt} > 0) {
     $self->Uprint("\n-----------------------\n");
     $self->Uprint("-- PHRASES Summary\n");
     $self->Uprint("-----------------------\n");
     $self->Uprint("Phrases: ".$self->{_gPhraseCnt}."\n");
     $self->Uprint("Dupes  : ".$self->{_gPhraseDupeCnt}."\n");
     $self->Uprint("New    : ".$self->{_gPhraseNewCnt}."\n");
  }
  # Only show if data present
  if ($self->{_gPathCnt} > 0) {
     $self->Uprint("\n-----------------------\n");
     $self->Uprint("-- PATHS Summary\n");
     $self->Uprint("-----------------------\n");
     $self->Uprint("Paths  : ".$self->{_gPathCnt}."\n");
     $self->Uprint("Dupes  : ".$self->{_gPathDupeCnt}."\n");
     $self->Uprint("New    : ".$self->{_gPathNewCnt}."\n");
  }
  # Show the Catalog statistics
  $self->ShowStats('Catalog Files');
  #
  $self->Uprint("-----------------------\n");
  $self->Uprint("Start: ".$self->{_gStartTime}."\n");
  $self->Uprint("End  : ".$self->{_gEndTime}."\n");
} #ShowStatistics


#*******************************************************************************
#
# Akashic::ProcessWords  (<TextFile(s)>/"<STDIN>") <ROOT> <SHOW_STATS> <SORT_DATA>
#
# - Processes the text file or files into the Akashic database
#
# Process all lines of the text file(s) or standard input and stores the text in either:
#   WORDS   - text is a plain word (ignoring punctuation) without space or dot [ .]
#   PHRASES - text contains spaces between words ("word phrase")
#   PATHS   - text contains dot between words and no spaces ("word.path.earth")
#
# If no filenames are specified, reads from standard input <STDIN>.
#
# SHOW_STATS (1/0) - Show statistics; default 1
# SORT_DATA  (1/0) - (1) Sort data automatically (CAT.dat, CATS.dat, INDEX.dat, DOWN.dat); default 1
#                  - (0) Sort the datafiles after the process
#                  - This is a huge performance boost when adding large data sets, especially paths like Locations or Domains
#
# Check ShowProcessUsage below for more details on Environment Variables.
#
# NOTE: PROCESS_words.pl is provided to call this subroutine from the command line
#*******************************************************************************
sub Akashic::ProcessWords
{
  my ( $self, $pFiles, $Root, $bShowStats, $bSortData ) = @_;

  # Get the input parameters (files)
  # Try to read from environment variable if not specified
  if (!defined($pFiles) || $pFiles eq "") {
    $pFiles = $ENV{'ELTEXTFILES'};
  }
  # Use STDIN for input if file not specified or STDIN
  if (!defined($pFiles) || $pFiles eq "" || $pFiles =~ /^STDIN$/i) {
    $pFiles = "STDIN";
  }
  # Set the Global files input parameter for use in sub-routines
  $self->SetVar('gFiles', $pFiles);

  # Get the ROOT parameter if specified
  if (defined($Root) && $Root ne "") {
    # Set the Root, which sets the RootDir as well
    $self->SetVar('Root', $Root);

    # Check if RootDir exists
    if (!-d $self->{_RootDir}) {
      $self->Uprint("Error: Root Directory does not exist: [".$self->{_RootDir}."]\n");
      # Check the environment
      if ($self->CheckEnvironment()) {
        return 1;
      }
    }
  }

  $bShowStats = 1 if (!defined($bShowStats) || $bShowStats ne "0");
  $bSortData = 1  if (!defined($bSortData) || $bSortData ne "0");

  #
  # Set optimization parameters
  #
  $self->{_bShowStats} = $bShowStats;
  # Don't sort while processing large datasets
  $self->{_bSortData} = $bSortData;

  #
  # Create the environment specified Category as a Word if not using FileName base
  #
  $self->SetCategory($Root);

  #
  # Show processing message
  #
  $self->ShowProcessingHeader();

  $self->Uprint("======= ".$pFiles." =======\n");

  #
  # Local Variables
  #
  my $lFile="";

  #
  # Loop through the file / STDIN
  #
  if ($pFiles eq "STDIN") {
    #
    # Read through standard input
    #
    while (<STDIN>) {
      #
      # Find the words on the line and process each individually
      #
      $self->ProcessLine($Root, $_);
    }
    return 0;
  }

  #
  # Make sure file(s) exists
  #
  if (!-e $pFiles) {
    # Check for wildcards (*?)
    if (`ls $pFiles` eq "") {
      $self->Uprint("File(s) not found: ".$pFiles."\n\n");
      $self->ShowProcessUsage();
      exit 1;
    }
  }
  #
  # Loop through all the files
  #
  # Get the array of files
  # DEV NOTE: UNIX ONLY SYNTAX - NEED ANOTHER SOLUTION FOR CROSS-PLATFORM
  my @FILES=`ls $pFiles`;

  # Get the start time
  $self->SetStartTime();

  #
  # Loop through the files
  #
  for (my $i=0; $i<@FILES; $i++) {
    #
    # Get the next filename
    #
    $lFile = $FILES[$i];
    $lFile =~ s/\n//;   # remove CR from filename

    #
    # Set the File Category for processing
    #
    $self->SetFileCategory($Root, $lFile);

    #
    # Show processing message for multiple files
    #
    $self->Uprint("\n======= ".$lFile." =======\n") if (@FILES > 1);

    #
    # Open the TEXT file
    #
    open(FILE, "<$lFile")
      || do {
              $self->Uprint("Could not open file $lFile : $!\n");
              $self->ShowProcessUsage();
              exit -1;
             };
    #
    # Loop through the file
    #
    my $row=0;
    while (<FILE>) {
      # Check for a header row on first record, which defines data elements in the file
	  if ($row == 0
	    ||$_ =~ /^!HEADER:.*$/i
	    ||$_ =~ /^!HEAD:.*$/i
	    ||$_ =~ /^!H:.*$/i
	    ) {
        $row++;
	    # Example:
	    # !HEAD:LOC|GEO
	    # 00501.Holtsville.NY.USA|40.8172,-73.0451
	    # Remove the !Header: prefix on the line to just get column names
	    $_ =~ s/^!H.*://gi;
	    # Set the column names
	    #$self->GetColumnNames($_);   # AkashicUtils
	  }

      #
      # Find the words on the line and process each individually
      #
      $self->ProcessLine($Root, $_);
    } #end while
    #
    # Close the file
    #
    close(FILE);
  } #end for
  # Remove the array from memory
  undef @FILES;

  #
  # Show the summary statistics
  #
  if ($self->{_bShowStats}) {
    $self->ShowStatistics();
  } else {
    $self->Uprint("\n");
  }

  return 0;
} #END Akashic::ProcessWords


#*******************************************************************************
#*******************************************************************************
# DOMAIN   CREATION    ROUTINES
#*******************************************************************************
#*******************************************************************************


#*******************************************************************************
#
# MakeRootDir
#
# - Create the RootDir based on the Root name, checking for Root Subdirs (ie LANGS.ENG COMMS.JOBS etc)
#
#*******************************************************************************
sub Akashic::_NormalizeRootForCreate
{
  my ( $self, $root ) = @_;

  return if (!defined($root) || ref($root) || $root eq '' || length($root) > 255);
  return if ($root =~ /[\x00-\x20\x7f\\]/);

  my @segments = split(/[\.\/]/, $root, -1);
  return if (!@segments);
  for my $segment (@segments) {
    # Private roots remain valid for the trusted domain-build tools.  The web
    # ROOT flow applies the narrower public-only grammar before reaching here.
    return if ($segment !~ /\A(?:[A-Za-z][A-Za-z0-9_-]*|_[A-Za-z][A-Za-z0-9_-]*)\z/
      || length($segment) > 64);
    $segment =~ tr/[a-z]/[A-Z]/;
  }

  return join('/', @segments);
}


sub Akashic::_PrepareRootWritePath
{
  my ( $self, $root ) = @_;

  my $normalized = $self->_NormalizeRootForCreate($root);
  return if (!defined($normalized));

  my $domain_dir = $self->{_DomainDir};
  return if (!defined($domain_dir) || $domain_dir eq '' || !-d $domain_dir);
  my $domain_real = abs_path($domain_dir);
  return if (!defined($domain_real) || !-d $domain_real);

  my @segments = split('/', $normalized);
  my $root_dir = File::Spec->catdir($domain_real, @segments);
  my $relative = File::Spec->canonpath(File::Spec->abs2rel($root_dir, $domain_real));
  return if (File::Spec->file_name_is_absolute($relative)
          || $relative eq '..'
          || $relative =~ m{\A\.\.(?:[\\/]|\z)});

  # Every already-existing root component must be a real directory at its
  # expected canonical location.  A symlink is rejected even when it happens
  # to point back inside the domain.
  my $path = $domain_real;
  for my $segment (@segments) {
    $path = File::Spec->catdir($path, $segment);
    my @stat = lstat($path);
    next if (!@stat);
    return if (S_ISLNK($stat[2]) || !S_ISDIR($stat[2]));
    my $path_real = abs_path($path);
    return if (!defined($path_real) || $path_real ne $path);
  }

  # Pin all subsequent writes to the canonical domain rather than retaining a
  # caller-supplied alias that could later be replaced with a symlink.
  $self->SetVar('DomainDir', $domain_real);
  $self->SetVar('Root', $normalized);
  $self->{_RootDir} = $root_dir.'/';

  return ($domain_real, $root_dir, \@segments);
}


sub Akashic::MakeRootDir
{
  my ( $self ) = @_;

  my ($domain_dir, $dir, $segments) = $self->_PrepareRootWritePath($self->{_Root});
  if (!defined($domain_dir)) {
    $self->Uprint("\nMakeRootDir: Invalid or unsafe Root path\n");
    return 1;
  }

  if (!-d $dir) {
    my $path = $domain_dir;
    for my $segment (@{$segments}) {
      $path = File::Spec->catdir($path, $segment);
      my @stat = lstat($path);
      if (@stat) {
        if (S_ISLNK($stat[2]) || !S_ISDIR($stat[2])) {
          $self->Uprint("\nMakeRootDir: Unsafe path [$path]\n");
          return 1;
        }
        next;
      }
      unless (mkdir $path) {
        $self->Uprint("\nMakeRootDir: Error creating [$path]\n");
        return 1;
      }
      @stat = lstat($path);
      my $path_real = abs_path($path);
      if (!@stat || S_ISLNK($stat[2]) || !S_ISDIR($stat[2])
        || !defined($path_real) || $path_real ne $path) {
        $self->Uprint("\nMakeRootDir: Unsafe created path [$path]\n");
        return 1;
      }
    }
    $self->Uprint("Created Root: $dir\n");
    return 0;
  }
  return 0;
} #END Akashic:MakeRootDir


sub Akashic::_EnsureRootChildDirectory
{
  my ( $self, $dir ) = @_;

  my @stat = lstat($dir);
  if (@stat) {
    return 1 if (S_ISLNK($stat[2]) || !S_ISDIR($stat[2]));
    my $real = abs_path($dir);
    return 1 if (!defined($real) || $real ne File::Spec->canonpath($dir));
    return 0;
  }

  return 1 if (!mkdir($dir));
  @stat = lstat($dir);
  my $real = abs_path($dir);
  return 1 if (!@stat || S_ISLNK($stat[2]) || !S_ISDIR($stat[2])
    || !defined($real) || $real ne File::Spec->canonpath($dir));
  return 0;
}


sub Akashic::_ConfiguredRootChildNames
{
  my ( $self ) = @_;

  my @children;
  for my $member (qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES)) {
    my $child = $self->{$member};
    # These settings are intentionally configurable, but each one still names
    # one directory immediately below the root.  Never let an environment or
    # SetVar override turn it into a path.
    return if (!defined($child) || ref($child) || length($child) > 64
      || $child !~ /\A(?:[A-Za-z][A-Za-z0-9_-]*|_[A-Za-z][A-Za-z0-9_-]*)\z/);
    push @children, $child;
  }

  return \@children;
}


#*******************************************************************************
#
# CreateWordBase <ROOT> <OBJECT> <NAME> <SHORT> <DESC> <COLOR>
#
# - Create the _WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES directories
#   under the <ROOT> passed in, under the DomainDir
# - ROOT defaults to _ROOT
# - NAME, SHORT, DESC, COLOR are put in the ROOT directory as (NAME.dat DESC.dat COLOR.dat ...)
#
# i.e. /LOVE/earth.love/_ROOT/_WORDS
#      /LOVE/earth.love/_ROOT/_PHRASES
#      /LOVE/earth.love/_ROOT/_PATHS
#      /LOVE/earth.love/_ROOT/_TREES
#      /LOVE/earth.love/_ROOT/_TEMPLATES
#      /LOVE/earth.love/_ROOT/_DATES
#
#*******************************************************************************
sub Akashic::CreateWordBase
{
  my ( $self, $Root, $pObject, $pName, $pShort, $pDesc, $pColor ) = @_;
  my $dir = "";

  my $effective_root = (defined($Root) && $Root ne '') ? $Root : $self->{_Root};
  my ($domain_dir, $root_dir) = $self->_PrepareRootWritePath($effective_root);
  if (!defined($domain_dir)) {
    $self->Uprint("\nCreateWordBase: Invalid or unsafe Root path\n");
    return 1;
  }
  my $root_children = $self->_ConfiguredRootChildNames();
  if (!defined($root_children)) {
    $self->Uprint("\nCreateWordBase: Invalid root child directory setting\n");
    return 1;
  }
  # Define Object within Root
  $pObject = $Root if (!defined($pObject) || $pObject eq "");
  $pName  = "" if (!defined($pName));
  $pShort = $pName if (!defined($pShort) || $pShort eq "");
  $pDesc  = "" if (!defined($pDesc));
  $pColor = "" if (!defined($pColor));

  $dir = $root_dir;

  #
  # Create the Root directory if needed
  #
  if (!-d $dir) {
    # Make the directory that's in _RootDir, including subdirs
    # Leave if not successful
    return 1 if ($self->MakeRootDir());

    # Create the Domain and Root structure datafiles, including NAME, DESC, COLOR files if specified
    # Add Domain info if not present
    $self->AddIndexLine($self->{_DomainDir}, $self->{_Data}->{'_DOMAIN'},  $self->{_DomainDir}, 'CREATE ONELINE');
    $self->AddIndexLine($self->{_DomainDir}, $self->{_Data}->{'_DOMAINS'}, $self->{_DomainDir}, 'UNIQUE');

    # Record the Root in the Domain and Root
    $self->AddIndexLine($self->{_DomainDir}, $self->{_Data}->{'_ROOTS'}, $self->{_Root}, 'UNIQUE');
    $self->AddIndexLine($self->{_RootDir},   $self->{_Data}->{'_ROOT'},  $self->{_Root}, 'ONELINE');

    # Add NAME to ROOT
    if ($pName ne "") {
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_NAME'},  $pName, 'ONELINE');
      # Add the name to description if pDesc is blank
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_DESC'},  $pName, 'ONELINE') if ($pDesc eq '');
    }
    # Add OBJECT to ROOT
    if ($pObject ne "") {
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_OBJECT'},  $pObject, 'ONELINE');
    }
    # Add SHORT to ROOT
    if ($pShort ne "") {
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_SHORT'},  $pShort, 'ONELINE');
    }
    # Add DESC to ROOT
    if ($pDesc ne "") {
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_DESC'},  $pDesc, 'ONELINE');
    }
    # Add COLOR to ROOT
    if ($pColor ne "") {
      $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_COLOR'},  $pColor, 'ONELINE');
    }
    # Add audit files to ROOT
    $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_CREATED'},  $self->Timestamp(), 'CREATE ONELINE');
    $self->AddIndexLine($self->{_RootDir}, $self->{_Data}->{'_UPDATED'},  $self->Timestamp(), 'ONELINE');
  }

  # Configured child namespaces are part of the trusted root path. Existing
  # symlinks/non-directories are errors; never accept them merely because -d
  # follows their target.
  for my $child (@{$root_children}) {
    $dir = File::Spec->catdir($self->{_RootDir}, $child);
    if ($self->_EnsureRootChildDirectory($dir)) {
      $self->Uprint("Unable to create safe directory $dir\n");
      return 1;
    }
  }

  return 0;
} #CreateWordBase


################################################################################
# DOMAIN   MAINTENANCE    ROUTINES
################################################################################


################################################################################
#
# SortRootDataFiles
#
#     ["<ROOT>*"]   ["<word/phrase/path>*"]   ["<datafile(s)>*"]   [DaysBack]
#
# Refreshes the index data in the Akashic Domain Directory for the
# ROOT(s) specified (blank is default for All roots in ROOTS.dat)
#
# ex) ./REFRESH_akashic.pl /LOVE/earth.love_DEV "LANGS/*" "index" "" 7
#
#*******************************************************************************
# Parameters:
#
#   "<ROOT>*"
#         - Root Directory under Domain
#           Default "" is ALL Roots.
#
#   "<word/phrase/path>*"
#         - word, phrase, or path to specifically update.
#           Default "*" is ALL objects.
#           If a CATegory is specified, all items below will also be refreshed.
#           Categories are defined by a CAT.dat file (as default).
#
#   "<datafile(s)>*"
#         - List of datafiles under root to search for when generating a
#           page for the element.
#           Default "" is ALL datafiles.
#           "index,word,phrase,path,tree,date"
#
#   DaysBack
#         - Check for changed data this many Days Back.
#           Default "" is all data.
#
#
# Called by: REFRESH_akashic.pl
################################################################################
# - Sort all of the index files (INDEX.dat, DOWN.dat, CAT.dat, CATS.dat) in the ROOT specified
# - DaysBack - only sort files newer than this date (may be decimal: 0.25)
################################################################################
sub Akashic::SortRootDataFiles
{
  my ( $self, $Roots, $Words, $Datafiles, $DaysBack ) = @_;
  use Core::Search;
  use Core::Math;
  my $U = $self->{_Utils};

  $Roots     = "!ALL!" if (!defined($Roots) || $Roots eq "" || $Roots eq "*" || $Roots =~ /^ALL$/i);
  $Roots     =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $Words     = "!ALL!" if (!defined($Words) || $Words eq "" || $Words eq "*" || $Words =~ /^ALL$/i);
  $Words     =~ tr/[A-Z]/[a-z]/ if ($Words ne "!ALL!");   # Change to lowercase for comparision since paths are in lowercase
  $Datafiles = "!ALL!" if (!defined($Datafiles) || $Datafiles eq "" || $Datafiles eq "*" || $Datafiles =~ /^ALL$/i);
  $Datafiles =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $DaysBack  = -1 if (!defined($DaysBack) || $DaysBack eq "" || !($DaysBack =~ /^[-0-9\.]*$/));

  # Get the ROOTS directory name
  my $ROOTS = $self->{_DomainDir}.$self->{_Data}->{'_ROOTS'};

  # open the ROOTS file
#  if (!open(SOURCE, '<', $ROOTS)) {   # UTF-8 Fix
  if (!open(SOURCE, '<:encoding(UTF-8)', $ROOTS)) {
    $self->Uprint("SortRootDataFiles: ERROR: Could not open $ROOTS!\n");
    return 0;
  }
  #
  # LOOP through all ROOTS.dat that match pattern $Roots
  #
  foreach my $rowRoot (<SOURCE>) {
    # Remove trailing CR if present
    $rowRoot =~ s/\n//;

    # See if the root specified is in the list
    if ($Roots eq "!ALL!"
      ||$U->FindInList($rowRoot, $Roots)
      ) {
      # Set the root in Akashic
      $self->SetVar('Root', $rowRoot);

      $self->Uprint("======= Sorting Indexes for ROOT: $rowRoot (".$self->{_RootDir}.") =======\n");

      #########################################
      # Find the files and process
      #########################################
      find( sub {$self->SortIndexFiles($Datafiles, $Words, $DaysBack),}, $self->{_RootDir});

      $self->Uprint("\n");   # End of stats
    }
  } #foreach
  close(SOURCE);

  # Show statistics
  $self->ShowStats('Index Sorts') if ($self->GetShowStats());

  return 1;

  #################################################
  # Embedded subroutine for find
  # Search for INDEX / DOWN / CAT / CATS and sort
  #################################################
  sub Akashic::SortIndexFiles
  {
    my ( $self, $Datafiles, $Words, $DaysBack ) = @_;
    my $U = $self->{_Utils};

    # Don't traverse _TREES for Refresh
    $File::Find::prune = 1 if (/_TREES/);

    # Get the directory for the file
    my $dir = $File::Find::name;
    my $ext =  $self->{_DataExt};
    $dir =~ s/\/[A-Z-_]*$ext//g;   # Remove datafile (ie PHRASE.dat) to just leave directory home
    $dir .= '/' if ($dir ne "");

    # Get the file base name
    my $filename = $File::Find::name;
    $filename =~ s/^.*\///g;   # Remove everything up to the last / - ie PHRASE.dat returned

    # get the data file base
    my $data = $filename;
    $data =~ s/\..*$//gi;   # Strip off extension - ie PHRASE returned

    # Get the word/phrase/path we're processing
    my $word = $self->GetWordFromFile($File::Find::name);

    # See if we process this WORD
    if ($Words ne '!ALL!'
      && !$U->FindInList($word, $Words)
      ) {
      return 1;
    }

    # See if we process this DATAFILE
    if ($Datafiles ne '!ALL!'
      && !$U->FindInList($data, $Datafiles)
      ) {
      return 1;
    }

    # -T - only text files
    # Sort: INDEX / DOWN / CAT / CATS .dat
    if (-T
      && ($filename eq $self->{_Data}->{'_INDEX'}
        ||$filename eq $self->{_Data}->{'_DOWN'}
        ||$filename eq $self->{_Data}->{'_CAT'}
        ||$filename eq $self->{_Data}->{'_CATS'}
        #||$filename eq $self->{_Data}->{'_WORDS'}
        #||$filename eq $self->{_Data}->{'_PHRASES'}
        #||$filename eq $self->{_Data}->{'_PATHS'}
        #||$filename eq $self->{_Data}->{'_DATES'}
        )
       ) {
      #########################################
      # Sort the file
      #########################################
      $self->FileAddSort($File::Find::name, '', 'UNIQUE');

      # Show progress if Words are specified
      if ($Words ne "!ALL!") {
        $self->Uprint("Sorting: Data:[$data] Word:[$word]\n");
      }

      # Leave if not running stats
      return if (!$self->GetLogStat());

      # Update the stats.  _Sorts contains grand total
      $self->AddStat("_Sort $data");
      $self->AddStat("_Sort_Root (".$self->{_Root}.")");
      $self->AddStat("_Sorts");

      # Don't print Progress Markers if a word was specified
      return 1 if ($Words ne "!ALL!");

      #
      # Show Progress Marker
      #
      my $tot = $self->GetStat("_Sort_Root (".$self->{_Root}.")");
      if ($U->mod($tot, 10000) == 0
        ||$tot == 1000
        ||$tot == 100
        ||$tot == 10
        ||$tot == 1
        ) {
        $self->Uprint("\n") if ($tot != 1);
        $self->Uprint("Sorts: ".$tot.' ');
      }
      # Print . periodically
      if      ($tot >= 10000) {
        $self->Uprint(".") if ($U->mod($tot, 500) == 0);
      } elsif ($tot < 10) {
        $self->Uprint(".");
      } elsif ($tot < 100) {
        $self->Uprint(".") if ($U->mod($tot, 5) == 0);
      } elsif ($tot < 1000) {
        $self->Uprint(".") if ($U->mod($tot, 50) == 0);
      } elsif ($tot < 10000) {
      $self->Uprint(".") if ($U->mod($tot, 500) == 0);
      }
    }
  } #SortIndexFiles

} #SortRootDataFiles


################################################################################
#
# RefreshTreeData
#
#     ["<ROOT>*"]   ["<word/phrase/path>*"]   ["<datafile(s)>*"]   ["<TREE>*"]   [DaysBack]
#
# Refreshes the cached data in TREES as changes occur in source data
#
#*******************************************************************************
# Parameters:
#
#   "<ROOT>*"
#         - Root Directory under Domain
#           Default "" is ALL Roots.
#
#   "<word/phrase/path>*"
#         - word, phrase, or path to specifically update.
#           Default "*" is ALL objects.
#           If a CATegory is specified, all items below will also be refreshed.
#           Categories are defined by a CAT.dat file (as default).
#
#   "<datafile(s)>*"
#         - List of datafiles under Root _TREES to search for
#           when refreshing cached data
#           Default "" is ALL Datafiles:
#             "index,words,phrases,paths,dates,def,links"
#
#   "<TREE>*"
#         - Tree Directory under Root / _TREES
#           Default "" is ALL Trees.
#
#   DaysBack
#         - Check for changed data this many Days Back.
#           Default "" is all data.
#
# Called by: REFRESH_trees.pl
################################################################################
sub Akashic::RefreshTreeData
{
  my ( $self, $Roots, $Words, $Datafiles, $Trees, $DaysBack ) = @_;
  use Core::Search;
  use Core::Math;
  my $U = $self->{_Utils};

  $Roots     = "!ALL!" if (!defined($Roots) || $Roots eq "" || $Roots eq "*" || $Roots =~ /^ALL$/i);
  $Roots     =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $Words     = "!ALL!" if (!defined($Words) || $Words eq "" || $Words eq "*" || $Words =~ /^ALL$/i);
  $Words     =~ tr/[A-Z]/[a-z]/ if ($Words ne "!ALL!");   # Change to lowercase for comparision since paths are in lowercase
  $Datafiles = "!ALL!" if (!defined($Datafiles) || $Datafiles eq "" || $Datafiles eq "*" || $Datafiles =~ /^ALL$/i);
  $Datafiles =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $DaysBack  = -1 if (!defined($DaysBack) || $DaysBack eq "" || !($DaysBack =~ /^[-0-9\.]*$/));

  $Trees     = "!ALL!" if (!defined($Trees) || $Trees eq "" || $Trees eq "*" || $Trees =~ /^ALL$/i);
  $Trees     =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention

  # Get the ROOTS directory name
  my $ROOTS = $self->{_DomainDir}.$self->{_Data}->{'_ROOTS'};
  my $TREES = "";

  # open the ROOTS file
#  if (!open(SOURCE, '<', $ROOTS)) {   # UTF-8 Fix
  if (!open(SOURCE, '<:encoding(UTF-8)', $ROOTS)) {
    $self->Uprint("RefreshTreeData: ERROR: Could not open $ROOTS!\n");
    return 0;
  }
  #
  # LOOP through all ROOTS.dat that match pattern $Roots
  #
  foreach my $rowRoot (<SOURCE>) {
    # Remove trailing CR if present
    $rowRoot =~ s/\n//;

    # See if the root specified is in the list
    if ($Roots eq "!ALL!"
      ||$U->FindInList($rowRoot, $Roots)
      ) {
      # Set the root in Akashic
      $self->SetVar('Root', $rowRoot);

      $self->Uprint("======= ROOT: $rowRoot (".$self->{_RootDir}.") =======\n");

      # Get the list of trees to search
      $TREES = $self->{_RootDir}.$self->{_TREES}.'/'.$self->{_Data}->{'_TREES'};

      # open the TREES file
#      if (!open(TREES, '<', $TREES)) {   # UTF-8 Fix
      if (!open(TREES, '<:encoding(UTF-8)', $TREES)) {
        $self->Uprint("RefreshTreeData: ERROR: Could not open $TREES!\n");
        return 0;
      }
      #
      # LOOP through all ROOTS.dat that match pattern $Roots
      #
      foreach my $rowTree (<TREES>) {
        # Remove trailing CR if present
        $rowTree =~ s/\n//;

        # See if the tree specified is in the list
        if ($Trees eq "!ALL!"
          ||$U->FindInList($rowTree, $Trees)
          ) {
          # Set the root in Akashic
          $self->SetVar('Tree', $rowTree);

          $self->Uprint("    === TREE: $rowTree (".$self->{_TreeDir}.") ===\n");

          #########################################
          # Find the files and process
          #########################################
          find( sub {$self->FindTreeFiles($Datafiles, $Words, $DaysBack),}, $self->{_TreeDir});

          $self->Uprint("\n");   # End of stats
        }
      } #foreach
      close(TREES);
    }
  } #foreach
  close(SOURCE);

  # Show statistics
  $self->ShowStats('Tree Refreshes') if ($self->{_bShowStats});

  return 1;

  #################################################
  # Embedded subroutine for find
  # Search for INDEX / DOWN / CAT / CATS and sort
  #################################################
  sub Akashic::FindTreeFiles
  {
    my ( $self, $Datafiles, $Words, $DaysBack ) = @_;
    my $U = $self->{_Utils};

    # Only look at _TREES for Refresh
    $File::Find::prune = 1 if (!/_TREES/);
    # Don't search down _TEMPLATES or process directories
    #$File::Find::prune = 1 if (/_TEMPLATES/);

    # Get the directory for the file
    my $dir = $File::Find::name;
    my $ext =  $self->{_DataExt};
    $dir =~ s/\/[A-Z-_]*$ext//g;   # Remove datafile (ie PHRASE.dat) to just leave directory home
    $dir .= '/' if ($dir ne "");

    # Get the file base name
    my $filename = $File::Find::name;
    $filename =~ s/^.*\///g;   # Remove everything up to the last / - ie PHRASE.dat returned

    # get the data file base
    my $data = $filename;
    $data =~ s/\..*$//gi;   # Strip off extension - ie PHRASE returned

    # Get the word/phrase/path we're processing
    my $word = $self->GetWordFromFile($File::Find::name);

    # See if we process this WORD
    if ($Words ne '!ALL!'
      && !$U->FindInList($word, $Words)
      ) {
      return 1;
    }

    # See if we process this DATAFILE
    if ($Datafiles ne '!ALL!'
      && !$U->FindInList($data, $Datafiles)
      ) {
      return 1;
    }

    # -T - only text files
    # Refresh Data in datafiles: "index,down,cat,words,phrases,paths,dates,def,links"
    if (-T
      && ($filename eq $self->{_Data}->{'_INDEX'}
        ||$filename eq $self->{_Data}->{'_DOWN'}
        ||$filename eq $self->{_Data}->{'_CAT'}
        #||$filename eq $self->{_Data}->{'_CATS'}
        ||$filename eq $self->{_Data}->{'_WORDS'}
        ||$filename eq $self->{_Data}->{'_PHRASES'}
        ||$filename eq $self->{_Data}->{'_PATHS'}
        ||$filename eq $self->{_Data}->{'_DATES'}
        ||$filename eq $self->{_Data}->{'_DEF'}
        ||$filename eq $self->{_Data}->{'_LINKS'}
        )
       ) {
      ####################################
      #
      # Refresh the data elements in the file
      #
      # RefreshTreeData  ($File::Find::name);
      $self->Uprint("...RefreshTreeData  ($File::Find::name) - CODE TO WRITE\n");

      # CODE TO WRITE
      # CODE TO WRITE
      # CODE TO WRITE

      # CODE TO WRITE

      # CODE TO WRITE
      # CODE TO WRITE
      # CODE TO WRITE

      #
      ####################################

      # Leave if not running stats
      return if (!$self->GetLogStat());

      # Update the stats.  _Trees contains grand total
      $self->AddStat("_Tree $data");
      $self->AddStat("_Tree_Root (".$self->{_Root}.")");
      $self->AddStat("_Trees");

      # Don't print Progress Markers if a word was specified
      return 1 if ($Words ne "!ALL!");

      #
      # Show Progress Marker
      #
      my $tot = $self->GetStat("_Tree_Root (".$self->{_Root}.")");
      if ($U->mod($tot, 10000) == 0
        ||$tot == 1000
        ||$tot == 100
        ||$tot == 10
        ||$tot == 1
        ) {
        $self->Uprint("\n") if ($tot != 1);
        $self->Uprint("Trees: ".$tot.' ');
      }
      # Print . periodically
      if      ($tot >= 10000) {
        $self->Uprint(".") if ($U->mod($tot, 500) == 0);
      } elsif ($tot < 10) {
        $self->Uprint(".");
      } elsif ($tot < 100) {
        $self->Uprint(".") if ($U->mod($tot, 5) == 0);
      } elsif ($tot < 1000) {
        $self->Uprint(".") if ($U->mod($tot, 50) == 0);
      } elsif ($tot < 10000) {
        $self->Uprint(".") if ($U->mod($tot, 500) == 0);
      }
    }
  } #FindTreeFiles

} #RefreshTreeData


################################################################################
# USAGE ROUTINES
################################################################################


################################################################################
#
# ShowProcessUsage
#
# - Show Usage
#
################################################################################
sub Akashic::ShowProcessUsage
{
  my ( $self ) = @_;

  # Check for the SHOW OUTPUT  directive
  return if (!$self->{_bShowOutput});

  print "Usage: $0 <textfile/STDIN>\n\n";

  print "  <TextFile/\"TextFile(s)\"/STDIN> (required)\n";
  print "      - Text file(s) with WORDS to add to the earth.love tree\n";

  print "\nEnvironment Variables (Unix: export; Windows: set)\n";
  print "  Ex) Unix:    export ELTEXTFILES=myfile.txt\n";
  print "      Windows: set ELTEXTFILES=myfile.txt\n";
  print "- EARTH_LOVE      - earth.love Domain directory\n";
  print "- ELROOT          - ROOT directory under Domain (default LANGS/ENG)\n";
  print "- ELTREE          - TREE directory under ELROOT (default TREE)\n";
  print "- ELBRANCH        - BRANCH directory under ELTREE (default LIST)\n";

  print "- ELWORDS         - WORDS directory name     (default _WORDS)\n";
  print "- ELPHRASES       - PHRASES directory name   (default _PHRASES)\n";
  print "- ELPATHS         - PATHS directory name     (default _PATHS)\n";
  print "- ELTREES         - TREES directory name     (default _TREES)\n";
  print "- ELTEMPLATES     - TEMPLATES directory name (default _TEMPLATES)\n";
  print "- ELDATES         - DATES directory name     (default _DATES)\n";

  print "- ELTEXTFILES     - Set TextFile(s) input parameter\n";
  print "- ELTEMPLATE      - Set Template input parameter\n";
  print "- ELWORDFOUNDTEXT - Word \"exists\" message output: SILENT BRIEF EXISTS SHOW\n";
  print "- ELLINEPHRASE    - Indicates the lines of the file being processed could be a phrase\n";
  print "                    (up to 80 characters), so save in _PHRASES as well as _WORDS when applicable\n";
  print "- ELCATFILE       - The name of the Category file for each word (default: CATS.dat)\n";
  print "- ELCATEGORY      - Record this Category for all words processed (added to CATS.dat)\n";
  print "    - If set to #FILEBASE#, the \"base\" filename will be used for the category (ex. Cooking.txt => Cooking)\n";

  print "\n";
  exit 1;
} #ShowProcessUsage


################################################################################
# END OF Akashic::Process.pm
################################################################################
1;
