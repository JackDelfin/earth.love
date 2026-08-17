#!/usr/bin/perl
# Version 1.0.1.0      09-Jun-2021
#*******************************************************************************
#
# Orbit::Akashic::New.pm
#
# Orbit configuration for Akashic Data Processing
#
#   ProcessNewRecords
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
package Orbit;
use strict;
use warnings;

#
# Load the Akashic core and Utilities, and Earth addons
#
use Akashic::Write;
use Akashic::Write::Data;


################################################################################
#
# ProcessNewRecords()
#
# - Process Akashic New Record transactions
#
################################################################################
sub Orbit::ProcessNewRecords
{
  my ( $self ) = @_;
  my $O = $self;
  my $A = $O->{_Akashic};
  my $U = $A->{_Utils};

  # Buffer the print output for Akashic package
  $self->BufUprint(1);

  my $bAddObjectData = 1;   # Add the Object index after creation (ie COMM.dat)

  my $root   = $O->Get_Token('ROOT');
  my $object = $O->Get_Token('OBJECT');
  $object    =~ tr/[a-z]/[A-Z]/;   # uppercase
  my $page   = $O->Get_Token('PAGE');
  $page      = 'el_new' if ($page eq "");
  my $action = $O->Get_Token('ACTION');
  my $word   = "";

  # A GET may display the editor-only form, but it must never reach storage.  POST
  # additionally requires the session-bound CSRF token.
  my $operation = ($object eq 'ROOT' || $object eq 'DOMAIN') ? 'system.create' : 'create';
  my ($route_allowed, $process_mutation) = $self->AuthorizeMutationRequest($root, $operation);
  if (!$route_allowed) {
    $O->Set_Token('PAGE', 'DEFAULT');
    return $O->Get_Token('PAGE');
  }
  if (!$process_mutation) {
    $O->Set_Token('PAGE', 'el_new');
    return 'el_new';
  }

  #***************************************
  #
  # Step variables and processing
  #
  my $step   = $U->GetNumber($O->Get_Token('STEP'),0);
  $step = 0 if ($step eq "");
  my $steps  = $U->GetNumber($O->Get_Token('STEPS'),0);
  $steps = 0 if ($steps eq "");

  #***************************************
  #
  # Controls
  #

  # Default Process Data Fields boolean - default YES
  my $bProcessData = 1;

  # Check Required Fields boolean - default YES
  my $bCheckRequired = 1;

  # Steps processing boolean - default YES
  my $bSteps = 0;
  $bSteps = 1 if ($step > 0 && $step <= $steps);


  #***************************************
  #
  # Get the primary key for NEW - _name
  #
  my $name   = $O->Get_Token('_name');
  # Trim the input
  $name = $A->StandardLineTrim($name);

  #***************************************
  #
  # Check for Actions
  #
  #***************************************
  #
  # PREV - Previous Page
  #
  if ($action =~ /^PREV$/i) {
    # Unset action since we're performing it
    $O->Delete_Token('ACTION');
    $O->Set_Token('_PREV_', $name);
    $step-- if ($step > 1);
    $O->Set_Token('STEP', $step);

    # ::::::: New Directive :::::::

    # Collect Data on the page but don't process (save)
    $bProcessData = 0;

    # Ignore Steps
    $bSteps = 0;

    # Ignore Required Fields
    $bCheckRequired = 0;

    # Keep on page NEW, previous page
    $page = 'el_new';

  #***************************************
  #
  # CANCEL - Cancel Transaction Page
  #
  } elsif ($action =~ /^CANCEL$/i) {
    # Unset action since we're performing it
    $O->Delete_Token('ACTION');
    $O->Set_Token('_CANCELED_', $name);

    # Clear the words tokens
    $O->Delete_Token('WORD');
    $O->Delete_Token('_WORDFOUND_');
    $O->Delete_Token('_WORDTYPE_');
    $O->Delete_Token('_BADWORD_');
    $O->Delete_Token('_WORDDIR_');

    # Start Fresh at Root Show home: EL_SHOW_<ROOT>
    $O->Set_Token('OBJECT', $root);

    # Set the page to display
    # Goes to EL_SHOW_<root>, i.e. EL_SHOW_COMMS
    $page = 'el_show';
    $O->Set_Token('PAGE', $page);
    return $page;
  }

  #***************************************
  #
  # Make sure primary data exists
  #
  # It must also be a valid word/phrase/path for storage in Akashic
  #
  if ($name eq ""
    ||!$O->SetWordTokens($name, 1)
    ) {
    $O->RegisterError('#MSG[Name not specified]#') if ($name eq "");

    # Don't Process Data on the page
    $bProcessData = 0;
    # Ignore Steps
    $bSteps = 0;
    # Ignore Required Fields
    $bCheckRequired = 0;

    # Go back to the NEW page
    $page = 'el_new';
  }

  #***************************************
  #
  # Get the context directory for Word/Phrase/Path
  # - If it exists, not a new entry - go to the SHOW page
  #
  my $WordDir = $A->GetTextDir($root, $name);
  if (-d $WordDir) {
    $O->RegisterError('#MSG[Word already exists]#');
    $O->Set_Token('WORD', $name);
    # Set the page to display
    $page = 'el_show';
    $O->Set_Token('PAGE', $page);
    return $page;
  }

  #***************************************
  # BEGIN OF OBJECTS
  #***************************************

  #######
  # NEW WORD
  #
  if      ($object eq 'WORD') {

  #######
  # NEW LANG
  #
  } elsif ($object eq 'LANG') {
    $root = 'LANGS';
    $A->SetVar('Root', $root);

  #######
  # NEW COMM
  #
  } elsif ($object eq 'COMM') {
    $root = 'COMMS';
    $A->SetVar('Root', $root);

  #######
  # NEW LOC
  #
  } elsif ($object eq 'LOC') {
    $root = 'LOCS';
    $A->SetVar('Root', $root);

  #######
  # NEW GUILD
  #
  } elsif ($object eq 'GUILD') {
    $root = 'GUILDS';
    $A->SetVar('Root', $root);

  #######
  # NEW BOOK
  #
  } elsif ($object eq 'BOOK') {
    $root = 'BOOKS';
    $A->SetVar('Root', $root);

  #######
  # NEW DOM
  #
  } elsif ($object eq 'DOM') {
    $root = 'DOMS';
    $A->SetVar('Root', $root);

  #######
  # NEW JOB
  #
  } elsif ($object eq 'JOB') {
    $root = 'JOBS';
    $A->SetVar('Root', $root);

  #######
  # NEW NAME
  #
  } elsif ($object eq 'NAME') {
    $root = 'NAMES';
    $A->SetVar('Root', $root);

  #######
  # NEW NEED
  #
  } elsif ($object eq 'NEED') {
    $root = 'NEEDS';
    $A->SetVar('Root', $root);

  #######
  # NEW ORG
  #
  } elsif ($object eq 'ORG') {
    $root = 'ORGS';
    $A->SetVar('Root', $root);

  #######
  # NEW PERSON
  #
  } elsif ($object eq 'PERSON') {
    $root = 'PERSONS';
    $A->SetVar('Root', $root);

  #######
  # NEW QUOTE
  #
  } elsif ($object eq 'QUOTE') {
    $root = 'QUOTES';
    $A->SetVar('Root', $root);

  #######
  # NEW RESOURCE
  #
  } elsif ($object eq 'RESOURCE') {
    $root = 'RESOURCES';
    $A->SetVar('Root', $root);

  #######
  # NEW DOMAIN
  #
  } elsif ($object eq 'DOMAIN') {
    $root = '_NEW_DOMAIN_';
    $A->SetVar('Root', $root);
    # Set the DOMAIN.dat
    $A->AddIndexLine($WordDir, $object.$A->{_DataExt}, $name, 'CREATE ONELINE');

  #######
  # NEW ROOT
  #
  } elsif ($object eq 'ROOT') {
    #use AkashicProcess;
    $root = $name;   # Root directory name
    $root =~ tr/[a-z]/[A-Z]/;   # uppercase by convention
    #$A->SetVar('Root', $root);
    # Create the word base
    $A->CreateWordBase($root   # Root Code
                      ,$O->Get_Token('_root_name')
                      ,$O->Get_Token('_short')
                      ,$O->Get_Token('_desc')
                      ,$O->Get_Token('_color')
                      );
    # Show the newly created Root
    $O->Set_Token('ROOT', $name);
    $O->Set_Token('OBJECT', '');
    $O->Set_Token('WORD', '');

    $bProcessData = 0;   # Record we've processed data

    # Return to the display page after processing
    $page = 'el_show';

  #######
  # NEW TREE
  #
  } elsif ($object eq 'TREE') {
    $root = 'TREES';
    $A->SetVar('Root', $root);

  #***************************************
  # END OF OBJECTS
  #***************************************
  }

  #***************************************
  #
  # Get the additional DATA fields passed in
  # Create an array of the form fields
  # ONLY ACCEPT COMMAS AS DELIMITERS IN THIS FIELD
  my $Fields = $O->Get_Token('FORMFIELDS');
  my @FIELDARR;
  @FIELDARR = split(',', $Fields) if ($Fields ne "");
  my %ARR;   # Hash array to assign datafile/value pairs

  my $datafile = "";
  my $value = "";

  #***************************************
  #
  # Check for required fields
  #
  if (@FIELDARR
    && ($bCheckRequired
      || $bProcessData)
      ) {
    # Loop through each Form field
  foreach my $ff (@FIELDARR) {
      next if ($ff eq "");   # no blank fields

      # Client-selected field names become filenames later in this routine.  Keep
      # them to a small identifier grammar so '/', '..', control characters, and
      # other path syntax can never reach Akashic::Write.
      if ($ff !~ /^_[A-Za-z][A-Za-z0-9_]{0,63}(?:_req)?$/) {
        $O->RegisterError('#MSG[Invalid form field]#');
        $bProcessData = 0;
        $page = 'el_new';
        last;
      }

      # Fix the datafile name
      $datafile = $ff;
      $datafile =~ s/_req$//i;        # take off trailing _req

      # Get the trimmed token value (without _req)
      $value = $A->StandardLineTrim( $O->Get_Token($datafile) );

      # Finish standardizing datafile name
      $datafile =~ tr/[a-z]/[A-Z]/;   # uppercase
      $datafile =~ s/^_//;            # take off leading _

      # Build the HASH array
      $ARR{$datafile} = $value;

#$O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: $datafile:$value\n");
#$O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: $ff: ".%ARR{$ff}."\n");

      #
      # Rest of logic is for Checking Required Fields
      #
      next if (!$bCheckRequired);

      next if (!($ff =~ /.*_req$/i));  # only if it contains _req

#$O->Append_Token('_DEBUG_', "$ff:($value) ");   # if ($ff eq 'desc');
      # check the input value
      next if ($value ne "");   # next if it contains content

      #
      # Show the required message
      #
      $O->RegisterError($U->initcap($datafile)." "."#MSG[is required]#");
      $page = 'el_new';    # go back to same NEW page

      $bProcessData = 0;   # Don't process the data
      $bSteps = 0;         # Don't check for next steps
      last;                # Only show the first required occurance
    } #foreach
  } #bCheckRequired

  #$O->Append_Token('_DEBUG_', "(".%ARR.")\n");
  #foreach my $ff (keys(%ARR)) {
  #  $O->Append_Token('_DEBUG_', "$name $page F:".%ARR.":: [$ff]: [".$ARR{$ff}."]\n");
  #}


  #***************************************
  #
  # Check Input Steps
  #
  if ($bSteps) {
    #
    # Increase the step
    #
    # Don't process the data until the last step
    if ($step < $steps) {
      $bProcessData = 0;
      $page = 'el_new';
      $step++;
      $O->Set_Token('STEP', $step);
    } else {
      $page = 'el_show';
      $O->Set_Token('WORD', $name);
      $O->Set_Token('_WORDFOUND_', $name);
    }
  }


  #***************************************
  #
  # DATA PROCESSING BELOW THIS LINE
  #
  #***************************************
  if ($bProcessData) {
    #
    # Add the phrase/word/path for the Root
    #
    if (!$A->AddTextFields($root, $name, %ARR)) {

      #
      # Successful
      #
      $O->RegisterSuccess('#MSG[Word Added]#');
      $self->GetUprintBuf();   # Reset print buf
      $page = 'el_show';
      # Get the Next Word if available
      my $nextWord = $O->Get_Token('NWORD');
      if ($nextWord eq "")  {
        $O->Set_Token('WORD', $name);
      } else {
        $O->Set_Token('WORD', $nextWord);
      }
      # Get the Next Root if available and set as the new root
      my $nextRoot = $O->Get_Token('NROOT');
      if ($nextRoot ne "") {
        $O->SetRoot($nextRoot);
      }
      # Set the _WordDir_ and _WordFound_ variables
      my $WordDir = $A->GetTextDir($O->GetRoot(), $O->Get_Token('WORD'));
      $O->Set_Token('_WORDFOUND_', '1');
      $O->Set_Token('_WORDDIR_', $WordDir);
      # Reset the Message if WORDNOTFOUND is set
      if ($O->Get_Token('MESSAGE_TEXT') eq "#MSG_WORDNOTFOUND#") {
        $O->RegisterMessage("");
      }
    } else {
      #
      # Error
      #
      $O->RegisterError("#MSG[Error adding word:]# ".$self->GetUprintBuf());
      # Reset the step if needed
      $step-- if ($bSteps && $step ne "" && $step > 1);
      $O->Set_Token('STEP', $step);

      # Set the page to display
      $page = 'el_show';   # Stay on NEW page

      # indicate we couldn't create the header word
      $bProcessData = 0;
    }
  } #bProcessData

  #
  # Add the Generic Object reference to the Word/Phrase/Path
  #
  if ($bAddObjectData && $bProcessData) {
    $A->AddIndexLine($WordDir, $object.$A->{_DataExt}, $name, 'CREATE ONELINE');
  }


  #***************************************
  #
  # DATA PROCESSING ABOVE THIS LINE
  #
  #***************************************

  #***************************************
  # Time to wrap it up
  #***************************************

  # Free up the field array
  undef @FIELDARR;
  undef %ARR;

  $O->Set_Token('PAGE', $page);
  return $page;
} #ProcessNewRecords


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic::New;
#******************************************************************************************
1;

#END Orbit::Akashic::New;
