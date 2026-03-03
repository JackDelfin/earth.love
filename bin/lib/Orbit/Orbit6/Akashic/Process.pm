#!/usr/bin/perl
# Version 1.0.1.0      09-Jun-2021
#*******************************************************************************
#
# Orbit::Akashic::Process.pm
#
# Orbit configuration for Akashic Data Processing
#
#*******************************************************************************
# History:
#   2021.06.09 earth.love oK Created
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
# PROCESSING UTILITIES
#----------------------------------------#
#
# RefreshPageData
#     ["<ROOT>*"]   ["<word/phrase/path>*"]   ["<datafile(s)>*"]   [DaysBack]
#   - Refreshes the cached OML pages (HTML files) in the Akashic Domain Directory for the
#   - ROOT(s) specified (blank is default for All roots in ROOTS.dat)
#   - Called by: REFRESH_pages.pl
#
#*******************************************************************************
package Orbit;
use strict;
use warnings;

#
# Load the Orbit Config and Akashic core and Write Utilities, and Earth addons
#
use Orbit::Orbit6::Config;
#use Akashic::Stats;
use Akashic::Write;


#******************************************************************************************/
#       BATCH   PROCESSING    UTILITIES
#******************************************************************************************/


################################################################################
#
# RefreshPageData
#
#     ["<ROOT>*"]   ["<word/phrase/path>*"]   ["<datafile(s)>*"]   [DaysBack]
#
# Refreshes the cached OML pages (HTML files) in the Akashic Domain Directory for the
# ROOT(s) specified (blank is default for All roots in ROOTS.dat)
#
#*******************************************************************************
# Parameters:
#
#   "<ROOT>*"
#         - Root Directory under Domain.
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
#             "index,word,phrase,path,tree,date"
#
#   DaysBack
#         - Check for changed data this many Days Back.
#           Default "" is all data.
#
# Called by: REFRESH_pages.pl
################################################################################
sub Orbit::RefreshPageData {
  my ( $self, $Roots, $Words, $Datafiles, $DaysBack, $LogLevel ) = @_;
  my $O = $self;
  # Get local Akashic and CoreUtils pointer
  my $A = $O->{_Akashic};
  use Core::Search;
  my $U = $O->{_Utils};

  # Set the Orbit Log Statistics Level (1-9) - default 1; Minimum 1
  $LogLevel = 1 if (!defined($LogLevel) || length($LogLevel) ne '1' || $LogLevel lt '1' || $LogLevel gt '9');

  # Turn on statistics for Page Refresh
  $O->SetLogStats($LogLevel);   # Set LogStats Level - Log the stats in memory
  $O->SetShowStats(1);  # Turn on ShowStats  - Show statistics at end
  $O->SetShowOutput(1); # Turn on/off ShowOutput - Show processing messages
  $O->SetBatchMode(1);  # Set the batch mode flag to disable show statistics and changing stats logging level within individual pages since we're collecting for the batch
  # SetDomain was done in Orbit-Akashic-Init, but we might want to change here in the future for batch processing
  #$O->SetDomain($A->GetVar('DomainDir'));  # Set the batch mode flag to disable show statistics and changing stats logging level within individual pages since we're collecting for the batch

  $Roots     = "!ALL!" if (!defined($Roots) || $Roots eq "" || $Roots eq "*" || $Roots =~ /^ALL$/i);
  $Roots     =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $Words     = "!ALL!" if (!defined($Words) || $Words eq "" || $Words eq "*" || $Words =~ /^ALL$/i);
  $Words     =~ tr/[A-Z]/[a-z]/ if ($Words ne "!ALL!");   # Change to lowercase for comparision since paths are in lowercase
  $Datafiles = "!ALL!" if (!defined($Datafiles) || $Datafiles eq "" || $Datafiles eq "*" || $Datafiles =~ /^ALL$/i);
  $Datafiles =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
  $DaysBack  = -1 if (!defined($DaysBack) || $DaysBack eq "" || !($DaysBack =~ /^[-0-9\.]*$/));

  # Get the ROOTS.dat directory name - Use Orbit GetDomainDir to make sure we're linked
  my $ROOTS = $O->GetDomainDir().$A->{_Data}->{'_ROOTS'};

  # open the ROOTS file
  if (!open(SOURCE, '<:encoding(UTF-8)', $ROOTS)) {
    $self->Uprint("RefreshPageData: ERROR: Could not open ROOTS.dat: $ROOTS!\n");
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
      $A->SetVar('Root', $rowRoot);
      $O->SetRoot($rowRoot, $A->GetVar('RootDir'));
      $O->Set_Token('ROOT', 'LANGS.'.$value);

      $self->Uprint("======= Refresh Orbit Pages for ROOT: $rowRoot (".$A->{_RootDir}.") =======\n");

      #########################################
      # Find the files and process
      #########################################
      find( sub {$O->FindPageFiles($Datafiles, $Words, $DaysBack),}, $A->{_RootDir});

      $self->Uprint("\n");   # End of stats
    }
  } #foreach
  close(SOURCE);

  # Show statistics
  $self->ShowStats('Page Refreshes');

  return 1;

  #################################################
  # Embedded subroutine for find
  # Search for INDEX / DOWN / CAT / CATS / WORD / PHRASE / PATH / DATE / TREE
  #################################################
  sub Orbit::FindPageFiles
  {
    my ( $self, $Datafiles, $Words, $DaysBack ) = @_;
    my $O = $self;
    my $A = $O->{_Akashic};
    my $U = $O->{_Utils};

    # Don't search down _TEMPLATES or process directories
    $File::Find::prune = 1 if (/_TEMPLATES/);

    # Get the directory for the file
    my $dir = $File::Find::name;
    my $ext =  $A->{_DataExt};
    $ext =~ s/\./\\\./;   # Treat . as \. for RegEx
    $dir =~ s/\/[A-Z-_]*$ext//g;   # Remove datafile (ie PHRASE.dat) to just leave directory home
    $dir .= '/' if ($dir ne "");

    # Get the file base name
    my $filename = $File::Find::name;
    $filename =~ s/^.*\///g;   # Remove everything up to the last / - ie PHRASE.dat returned

    # get the data file base
    my $data = $filename;
    $data =~ s/\..*$//gi;   # Strip off extension - ie PHRASE returned

    # Get the word/phrase/path we're processing
    my $word = $A->GetWordFromFile($File::Find::name);

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
    # Datafiles: index,word,phrase,path,tree,date
    if (-T
      && ($filename eq $A->{_Data}->{'_INDEX'}
        ||$filename eq $A->{_Data}->{'_WORD'}
        ||$filename eq $A->{_Data}->{'_PHRASE'}
        ||$filename eq $A->{_Data}->{'_PATH'}
        #||$filename eq $A->{_Data}->{'_DOWN'}
        #||$filename eq $A->{_Data}->{'_CAT'}
        #||$filename eq $A->{_Data}->{'_CATS'}
        #||$filename eq $A->{_Data}->{'_DATE'}
        #||$filename eq $A->{_Data}->{'_TREE'}
        )
       ) {
      ####################################
      #
      # Refresh the Page
      #
      $O->Set_Token('ROOT', $A->{_Root});
      $O->Set_Token('DATA', $data);
      $O->Set_Token('WORD', $word);
      $O->Set_Token('OBJECT', 'DATA_'.$data);
      #
      # Set for Command Line Batch
      $O->SetCommandLineOn();
      $O->SetPrintOutputOff();
      #
      my $OUT = $O->ShowPage('EL_SHOW');

      # Get the output file: datafile.html
      my $dataLower = $data;
      $dataLower =~ tr/[A-Z]/[a-z]/;   # lowercase datafile for .html output
      my $PageOut = $dir.$dataLower.'.html';

      # Show progress if Words are specified
      if ($Words ne "!ALL!") {
        $self->Uprint("Writing: Data:[$data] Word:[$word] Page:[$PageOut]\n");
      }

      # Open the OutFile for writing
      if (!open(DEST, '>:encoding(UTF-8)', $PageOut)) {
        $self->Uprint("\nRefreshPageData: ERROR: Could not write $PageOut!\n");
        return 0;
      }
      # Write the page
      print DEST $OUT;
      # Close the file
      close(DEST);

      # Clear all Tokens for next round
      $O->ResetTokenTable();

      #
      ####################################

      # Leave if not running stats
      return if (!$self->GetLogStat());

      #
      # Update the stats.  _Pages contains grand total
      #
      $self->AddStat("_Page_Data $data");
      $self->AddStat("_Page_Root (".$A->{_Root}.")");
      $self->AddStat("__Pages Total");

      # Don't print Progress Markers if a word was specified
      return 1 if ($Words ne "!ALL!");

      #
      # Show Progress Marker
      #
      my $tot = $self->GetStat("_Page_Root (".$A->{_Root}.")");
      if ($U->mod($tot, 10000) == 0
        ||$tot == 1000
        ||$tot == 100
        ||$tot == 10
        ||$tot == 1
        ) {
        $self->Uprint("\n") if ($tot != 1);
        $self->Uprint("Pages: ".$tot.' ');
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
  } #FindPageFiles

} #RefreshPageData


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic::Process;
#******************************************************************************************
1;

#END Orbit::Akashic::Process;
