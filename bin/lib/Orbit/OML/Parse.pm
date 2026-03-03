#!/usr/bin/perl
# Version 7.0.0.0       7-Jul-2021
#*****************************************************************************************
#*
#* Orbit::OML::Parse - Version 7
#*
#*  Package Name    :   Orbit::OML::Parse
#*
#*  Description     :   Implements Orbit Parsing Routines
#*
#*****************************************************************************************
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.17 earth.love oK Version 7 additions - direct OML function call
#   2021.05.07 earth.love oK Added Nested OML Functions functionality
#   2021.04.24 earth.love oK Refactored from PL/SQL Orbit package (2015.05.30)
#*****************************************************************************************
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
#*****************************************************************************************
#
# Parse <Buffer> [Print default:1]
#   - Parses Buffer, replacing out TOKENS and OML FUNCTIONS for their value
#   - If Print = 1, the contents will be printed using $self->print,
#     otherwise buffered and returned
#
# getNextSegment
#   - Gets the next token segment from the Output
#     Returns: 1 - segment found; may be more
#              0 - no Tokens or OML left in text (stop processing)
#
# StripComments
#   - Remove comments <!--- ---> from the text
#
# StripText
#   - Iteratively strips text strings out of a given string based on the
#     begin_text and end_string_text.  Ie. removing comments <!--- --->
#   - Returns the resulting string without the text in between begin and end
#   - If fv_replace_text is specified, replaces the match with this text
#   - Use fn_match_pairs = 1 to strip nested pairs, not just the first
#     occurrence of the end text
#
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Core::Utils;
#use Core::Replace;
#use Orbit::Utils;
#use Orbit::Token;
use Orbit::OML::Function7;
use Orbit::OML::TokenMods;

#========================================================================================
#
#                                 PARSING SUBROUTINES
#
#========================================================================================


#******************************************************************************************
#* Parse <Buffer> [Print default:1]
#*
#* - Parses Buffer, replacing out TOKENS and OML FUNCTIONS for their value
#* - If Print = 1, the contents will be printed using $self->print,
#*   otherwise buffered and returned
#******************************************************************************************
sub Orbit::Parse
{
  my ( $self, $Buffer, $bPrint ) = @_;
  my $U = $self->{_Utils};

  # Print the text as it's parsed (1-default), or (0) just return buffer
  $bPrint = 0 if (!defined($bPrint));

  #
  # Internally used for Parsing Routines
  #
  my $ps            = 0;               # Input Buffer PREVious Start position for a Segment
  my $s             = 0;               # Input Buffer Start position for a Segment
  my $e             = 0;               # Input Buffer End position for a Segment
  my $ParseCount    = 0;               # Keep track of parses to avoid recursive loop
  my $OutBuf        = "";              # Output Buffer for return
  my $Buf           = "";              # Mini Work Buffer
  my $gb_stop       = 0;               # Stop Function request
  #
  # Tokens
  #
  my $Token         = "";              # Token being processed
  my $TokenName     = "";              # Token Name without modifiers
  my $TokenValue    = "";              # Token Value of Token being processed
  #
  # Functions
  #
  my $Function      = "";              # Function being processed
  my $Params        = "";              # Function Parameters delimited by ][
  my $FunctionValue = "";              # Return Function Value Buffer
  my $bProcessed    = 0;               # Return code from ProcessFunction
  my $bFlush        = 0;               # Used on certain functions (#INCLUDE![]#) to flush the output for performance

  # Make sure we have text to process
  return "" if (!defined($Buffer) || $Buffer eq "");

  $self->AddStat("_Parse Calls") if ($self->GetLogStat());
  # Only log Parse Level on LogStat > 1
  $self->AddStat("Parse Level: ".$self->{_RecursiveCount}) if ($self->GetLogStat() > 1);

  #
  # Quick return when there's no token hashses or functions - nothing to parse
  #
  if (!($Buffer =~ /.*#.*#.*/) # Look for rough token
    &&!($Buffer =~ /.*\]#.*/)  # Look for rough token end function
    ) {
    # Print or go to Output Buffer
    if ($bPrint) {
      $self->print($Buffer, 1);
    }
    return $Buffer;
  }

  #
  # Check for recursive loop
  #
  $self->{_RecursiveCount}++;
  if ($self->{_RecursiveCount} >= $self->{_RecursiveMax}) {
    #
    $Buf = "Parse: Max Recursive Limit reached [".$self->{_RecursiveMax}."] while parsing [".$Buffer."]";
    #
    # Print or go to Output Buffer
    if ($bPrint) {
      $self->print($Buf, 1);
    } else {
      $OutBuf .= $Buf;
    }
    return $OutBuf;
  }

  #
  # Get the next token segment from the Input Buffer
  #
  while ($s != -1 && $e != -1 && $gb_stop == 0) {
    # Check for recursive limit
    $ParseCount++;
    if ($ParseCount >= $self->{_ParseMax}) {
      #
      $Buf = "Parse: Max Parses within Parse reached [".$self->{_ParseMax}."]";
      #
      # Print or go to Output Buffer
      if ($bPrint) {
        $self->print($Buf, 1);
      } else {
        $OutBuf .= $Buf;
      }
      last;
    }

    #
    # Call getNextSegment to get the start/end/token/function/parameters
    #
    ($s, $e, $Token, $Function, $Params, $bFlush) = $self->getNextSegment($Buffer, $s, $e);
    last if ($s == -1);

    #
    # Dump the buffer before the segment since it contains no tokens
    #
    if ( $ps < $s) {
      #
      $Buf = substr($Buffer, $ps, $s-$ps);
      #
      # Print or go to Output Buffer
      if ($bPrint) {
        $self->print($Buf, 1);
      } else {
        $OutBuf .= $Buf;
      }
    }

    #
    # See if the segment is a FUNCTION - process first
    #
    if ($Function ne "") {
      #
      # FUNCTION BUFFER SUPPORT
      #
      $self->{_Token}     = $Token;
      $self->{_Function}  = $Function;
      $self->{_Arguments} = $Params;
      $self->{_bFlush}    = $bFlush;
      #$self->{_bCache}    = 0    # Cache Parameter for OML Function Calls

      #
      # Process the Function, passing in Function, Token, and arguments array.
      # Some functions use token name: ASSIGN/BACK
      #
      ($FunctionValue, $bProcessed) = $self->ProcessFunction();

      # Reset Function Parameter Buffer
      $self->{_Token}     = '';
      $self->{_Function}  = '';
      $self->{_Arguments} = '';
      $self->{_bFlush}    = 0;
      #$self->{_bCache}    = 0    # Cache Parameter for OML Function Calls

      #
      # Handle the OML Function return Value if processed
      #
      if ($bProcessed) {
        # Stop Scenario
        if ($FunctionValue =~ /^!!HALT_EXECUTION!!.*/) {
          $gb_stop = 1;
          # Leave immediately for STOP
          last if ($Function eq 'STOP');
          # Remove HALT_EXECUTION for BEFORE AFTER SHOWON
          $FunctionValue =~ s/!!HALT_EXECUTION!!//;
          # Continue last loop to show function value if set
          last if ($FunctionValue eq "");
        }

        #
        # See if we need to parse again if value contains at least 2 #'s
        #
        if ( $FunctionValue =~ /.*#.*#.*/
          # Don't recurse for token assignment if Function returned OML tags
          && $Token eq ""
          ) {
          #
          # RECURSIVE PARSE CALL
          #
          $FunctionValue = $self->Parse($FunctionValue, $bPrint);

        }
        #
        # Check for Token Assignment
        #
        if ($Token ne "") {
          # Set temporary function to strip off modifiers
          $TokenName = $Token;

          # Set token hash
          if ($TokenName =~ /.*\..*/) {    #tok.mod# found
            $TokenName =~ s/\..*//g;       # Remove modifier(s) for adding to hash
          }

          # Check for token backup
          if ($Token =~ /^.*\.backup.*$/i) {
            # Set the TOKEN_BACK before function value assignment
            $self->Set_Token($TokenName.$self->{_BackupExt}, $self->Get_Token($TokenName));
            # Remove .backup from Token modifiers
            $Token =~ s/.backup//gi;
          }

          # STORE FunctionValue in TokenValue (TOKEN ASSIGNMENT)
          $TokenValue = $FunctionValue;

          #
          # Set the TOKEN ASSIGNMENT Value
          #
          $self->Set_Token($TokenName, $TokenValue);

        } else {
          # PRINT FunctionValue
          #
          $Buf = $FunctionValue;
          #
          # Print or go to Output Buffer
          if ($bPrint) {
            $self->print($Buf, 1);
          } else {
            $OutBuf .= $Buf;
          }
        }
        #
        # Reset the previous start and start for next iteration
        #
        # Suppress Function/Assignment CR (\n) if it is the only thing on the line and returns no value
        if (  ($Token ne ""    # Token assignment doesn't show output, so remove needless CR
             ||$FunctionValue eq ""
             )   # no return value from the function
            && ($s == 0 || substr($Buffer, $s-1, 1) eq "\n")   # Start is a new line or beginning of buffer
            && $e+1 < length($Buffer)
            && substr($Buffer, $e+1, 1) eq "\n"   # End is end of buffer or end of line
          ) {
          $e++;
        } else {
          # Suppress \n after Function if "-" is immediately after #fn[]#-
          if (substr($Buffer, $e+1, 2) eq "-\n") {
            $e += 2;
          }
          # end of buffer scenario
          if (substr($Buffer, $e+1, 1) eq "-"
              && length($Buffer) == $e+2) {
            $e += 1;
          }
        }

        $ps = $e+1;
        $s  = $e+1;

      } else {
        #
        # Function NOT processed, so show what we tried to process
        #
        $Buf = substr($Buffer, $s, $e-$s);
        #
        # Print or go to Output Buffer
        if ($bPrint) {
          $self->print($Buf, 1);
        } else {
          $OutBuf .= $Buf;
        }
        #
        # Reset the previous start and start for next iteration
        #
        # Suppress \n after Function if "-" is immediately after #fn[]#-
        if (substr($Buffer, $e+1, 2) eq "-\n") {
          $e += 2;
        }
        # end of buffer scenario
        if (substr($Buffer, $e+1, 1) eq "-"
            && length($Buffer) == $e+2) {
          $e += 1;
        }
        $ps = $e+1;
        $s  = $e+1;
      }
      #
      # Reset the Function Buffers (only if we're not doing Token assignment)
      #
      if ($Token eq "") {
        $Function = "";
        $Params = "";
        $FunctionValue = "";
      }
    }

    #
    # See if the segment is a TOKEN - process the .modifiers
    #
    if ($Token ne "") {
      #-- Get the Token Name
      $TokenName = $Token;
      $TokenName =~ s/\..*//g;   # Get just the Token Name without modifiers
      #
      # Make sure the Token exists
      # Add the token if it doesn't exist so Modifiers on NULL tokens will work
      #
      if (!$self->TokenExists($TokenName)) {
        # Doesn't exist, so create it to show it was referenced
        $self->SetToken($TokenName, "");
      }
      #
      # Process Token Modifiers
      #
      $TokenValue = $self->ProcessTokenModifiers($Token);

      #
      # See if token contains more tokens and call Parse recursively
      #
      if ($TokenValue =~ /.*#.*#.*/
        # Don't recurse for token assignment if Function returned OML tags
        && $Function eq ""
        ) {
        #
        # RECURSIVE PARSE CALL
        #
        $TokenValue = $self->Parse($TokenValue, $bPrint);
      }
      #
      # Only print the Token if we have don't have assignment
      #
      if ($Function eq '') {
        #
        # Print the Token Value after recursive parsing
        #
        $Buf = $TokenValue;
        #
        # Print or go to Output Buffer
        if ($bPrint) {
          $self->print($Buf, 1);
        } else {
          $OutBuf .= $Buf;
        }
      } else {
        #
        # Assign the modifiers value to the token if in ASSIGNMENT mode.  Allows:  $token.lower=FUNCTION[contents]#
        #
        $self->Set_Token($TokenName, $TokenValue);
      }
      #
      # Reset the previous start and start for next iteration
      #
      # Suppress \n after Tone if "-" is immediately after #token#-
      if (substr($Buffer, $e+1, 2) eq "-\n") {
        $e += 2;
      }
      # end of buffer scenario
      if (substr($Buffer, $e+1, 1) eq "-"
          && length($Buffer) == $e+2) {
        $e += 1;
      }

      #
      # Reset the previous start and start for next iteration
      $ps = $e+1;
      $s  = $e+1;

      #
      # Reset the Token, Function, and Value buffers
      #
      $Token = "";
      $TokenName = "";
      $TokenValue = "";
      $Function = "";
      $Params = "";
      $FunctionValue = "";
    }

    #
    # Reset the previous start if segment didn't contain Function or Token
    #
    # Start and End targeted a segment, but not a Token or Function, to move S to E
    if ($s < $e) {
      $ps = $e;
      $s = $e;
    }

  } #while

  #
  # Print out the rest of the buffer after end
  #
  if ($ps != -1 && !$gb_stop) {
    #
    $Buf = substr($Buffer, $ps);
    #
    # Print or go to Output Buffer
    if ($bPrint) {
      $self->print($Buf, 1);
    } else {
      $OutBuf .= $Buf;
    }
  }
  #
  # Decrease Recursive Iteration
  #
  $self->{_RecursiveCount}--;

  #
  # Finally, return the Output Buffer
  #
  return $OutBuf;
} #Parse


#******************************************************************************************
#* getNextSegment
#*
#* - Gets the next token segment from the Output
#*   Returns: 1 - segment found; may be more
#*            0 - no Tokens or OML left in text (stop processing)
#******************************************************************************************
#* OML (Orbit Markup Language) Patterns:
#*   #Token#
#*   #Token.modifier#
#*   #FUNCTION[param][#tok_param.modifier#][]#
#*   #FUNCTION[param]
#*            [#tok_param.modifier#]
#*            []#
#*   #TokenAssign=[#value.mod1.mod2#]#
#*   #TokenFnAssign.mod=FUNCTION[#tok_param#][#bad_tok][137]#
#******************************************************************************************
#*   $Buffer - input Buffer only
#*   $s      - index search Start
#*   $e      - index search End (important for Nested OML Functions)
#*   $NestedFunctionCount - levels deep in nested function parsing
#******************************************************************************************
sub Orbit::getNextSegment
{
  my ( $self, $Buffer, $s, $e, $NestedFunctionCount ) = @_;
  my $U = $self->{_Utils};

  # Position (index) pointers
  # $s (param)             # Start Token           : #
  # $e (param)             # End Token             : #

  # See if we're searching for nested OML functions
  $NestedFunctionCount = 0 if (!defined($NestedFunctionCount) || $NestedFunctionCount eq '');

  my $fas = -1;            # Function/Assign Start : [
  my $fae = -1;            # Function/Assign End   : ]#
  # Assignment
  my $a   = -1;            # Assignment            : =

  my $FoundSegment = 0;
  my $FoundNestedFunction = 0;

  my $lToken = "";
  my $lFunction = "";
  my $lParams = "";
  my $bFlush = 0;   # Function with ! after name ( #INCLUDE![...]# ) indicates to flush buffer and print as we go

  my $RecursiveCount = 0;
  my $RecursiveMax = $self->{_RecursiveMax};

  # Length of Buffer
  my $BufLen = length($Buffer);

  # Set Max End for the segment being searched, default to Buffer end
  my $maxE   = $BufLen-1;
  if ($e > $s) {
    $maxE = $e;
  }

  #**************************************************************************************
  # DEV NOTE: index(str, 'search', offset) returns -1 if not found; 0 for start of string
  #
  # HELPER FUNCTIONS:
  #   isOMLFunction isTokenModifier  isTokenSyntax isTokenModSyntax
  #**************************************************************************************

  while ($s != -1)
  {
    $RecursiveCount++;
    if ( $RecursiveCount      >= $RecursiveMax
      || $NestedFunctionCount >= $RecursiveMax
       ) {
      $self->print("getNextSegment: Max Recursive Limit reached [".$RecursiveMax."]");
      last;
    }

    #
    # Get the OML Token/Function positions based on patterns
    #   #   Start token this round
    #
    $s   = index($Buffer, '#', $s);
    #
    # Leave if we didn't find anything
    if ( $s == -1
       || $s >= $maxE-1   # Don't let search exceed then max End (## is not a token)
       ) {
      $s = -1;
      $e = -1;
      last;  # No more substitutions
     }
    #
    #   #   End token after start
    #
    $e   = index($Buffer, '#', $s+1);
    #
    # Leave if we didn't find anything
    if ( $e == -1
       || $e > $maxE   # Don't let search exceed the max End
       ) {
      $s = -1;
      $e = -1;
      last;
    }
    #
    #   =   Assignment
    $a   = index($Buffer, '=', $s+1);
    #
    # Check for bad assignment position #  #  =
    if ($a > $e) {
      # No assignment
      $a = -1;
    }

    #
    # QUICK TOKEN CHECK - most common
    # Get the token name up to end # - no spaces or tabs before end # in this case
    # Get Straight token with potential modifiers (.mods)
    #
    # Make sure this is NOT a token assignment
    if ($a == -1) {
      #
      # Get the token name - don't trim end space
      #
      $lToken = substr($Buffer, $s+1, $e-$s-1);
      #
      # See if we have a valid token
      #
      if ($self->isTokenModSyntax($lToken)) {
        #
        # Have a valid token
        #
        if ($NestedFunctionCount == 0) {
          # Leave and process Token
          $FoundSegment = 1;
          last;
        } else {
          #
          # This section is for supporting Nested OML Function calls
          # to skip past all tokens within function arguments to find nested functions only
          #
          # See if we're at the end of the string - just return
          if ($e >= $maxE) {
            # No Function Found
            $s = -1;
            $e = -1;
            last;
          }
          # If we are searching for recursive functions, skip simple tokens since we're in a recursive loop Leonardo
          # Reset start to after this token
          $s = index($Buffer, '#', $e+1);
          # Leave if no more tokens
          if ( $s == -1
            || $s >= $maxE-1) {
            $s = -1;
            $e = -1;
            last;
          } else {
            # $s = new token found
            $e = $s;
            next;
          }
        } #end if - nested function
      } else {
        # Not a valid token - Could be a function
        # Check for function next
        $lToken = "";
      }
    } else {
      #
      # TOKEN ASSIGNMENT
      # - Test the token first to eliminate non-tokens and simplify parsing
      #
      # Get the token name up to = (including preceeding space \t \n)
      #
      $lToken = substr($Buffer, $s+1, $a-$s-1);
      #
      # strip end space \t \n
      $lToken =~ s/[ \t\n]*$//g;
      #
      # See if we have a valid token - next if NOT
      #
      if (!$self->isTokenModSyntax($lToken)) {
        # Not a valid token
        $lToken = "";
        # Not a token assignment
        $a = -1;
      } else {
        #
        # Get the fas "[" and fae "]#" since we found an "="
        #
        $fas  = index($Buffer, '[',  $a+1);   # Function/Assign start
        $fae  = index($Buffer, ']#', $a+1);   # No whitespace allowed for Function End ]#
        #
        # Both fas and fae need to be found or ignore assignment - missing syntax
        if ($fas == -1 || $fae == -1 || $fae < $fas) {
          $fas = -1;
          $fae = -1;
          $a = -1;
          $lToken = "";
          # next iteration - bad $s start
          $s = $e;
          next;
        }
      }

    }  #END: Check for TOKEN ASSIGNMENT

    #
    # Get Function Start/End for NO TOKEN ASSIGNMENT (relative to start $s)
    #
    # Get: fas: [   Function/Assign     Start
    #      fae: ]#  Function/Assignment End
    #
    if ($a == -1) {
      # No Token assignment
      $fas = index($Buffer, '[',  $s+1);
      $fae = index($Buffer, ']#', $s+1);   # No whitespace allowed for Function End ]#
      # Ignore function start/end if out of sync ]# < [
      if ($fae < $fas) {
        $fas = -1;
        $fae = -1;
      }
    #} else {  # Set above for assignment
    #  # Token Assignment (=) - search after (=)
    #  $fas = index($Buffer, '[',  $a+1);
    #  $fae = index($Buffer, ']#', $a+1);   # No whitespace allowed for Function End ]#
    }

    #
    #  FUNCTION CHECK: Check for format: #fn[no token]#
    #
    if ( $fas >= 0      # ]# fn Start and fn End exist
      && $fae >= 0      # [
      && $fas < $fae    # fn Start less than fn End: [ ]#
      && $fas < $e      # fn Start less than End: [ #
      && $e <= $fae+1   # end hash is part of function end ]#
      ) {
      #
      # Get the function name
      #
      if ($a == -1) {
        #
        # Regular Function call:   #FUNCTION[]#
        #
        # Get Function name after start (#)
        $lFunction = substr($Buffer, $s+1, $fas-$s-1);
        # strip end space \t \n
        $lFunction =~ s/[ \t\n]*$//g;

        # Flush only applies with NO Token Assignment
        # Check for "Flush" command "!" after function name
        if ($lFunction ne ""
          && index($lFunction, '!') == length($lFunction)-1
          ) {
          # Record the Flush and remove ! from Function name
          $lFunction =~ s/\!//g;
          $bFlush = 1;
        }
      } else {
        #
        # Token assignment: #token=FUNCTION[]#
        #
        # Get Function name after (=)
        $lFunction = substr($Buffer, $a+1, $fas-$a-1);
        # strip end space \t \n
        $lFunction =~ s/[ \t\n]*$//g;
        # strip beginning space \t \n   #token = FUNCTION [] []#
        $lFunction =~ s/^[ \t\n]*//g;

        #
        # TOKEN ASSIGNMENT: Use Function ASSIGN (default without function name)
        #
        if ($lFunction eq '') {
          $lFunction = 'ASSIGN';
        }
      }

      #
      # Make sure the function is an OML Function - else it won't be parsed and user can dbug
      #
      if ($lFunction ne "" && $self->isOMLFunction($lFunction)) {
        #
        # Check for TOKEN DIRECT ASSIGNMENT:   #token=[value]#
        #
        # Uppercase function name for searching
        $lFunction =~ tr/[a-z]/[A-Z]/;
        #
        # Get the function parameters
        #
        $lParams = substr($Buffer, $fas+1, $fae-$fas-1);

        #
        # Cleanup the space and tabs between arg parameters makes ][ consistent without spaces, tabs, \n
        #
        $lParams = $self->FixArguments($lParams);

        #***********************************************************************
        # NESTED OML FUNCTIONS LOGIC
        #***********************************************************************
        # Make sure there's at least one Function open [
        if ($lParams =~ /#[A-Za-z][A-Za-z0-9_=.]*[ \t\n]*\[.*/) {
          #
          #
          # Check for nexted functions in lParams - look for next end- very useful
          #
          my $ParseCount = 0;
          my $ns = $fas;   # nested start at Function Assignment Start
          my $ne = $fae+1;   # nested end - don't search past function end ]# (+1)
          my $pfae=0; # Previous Function End fae
          my $nfae=0; # Next Function/Assignment End fae ]#
          my $nToken = '';
          my $nFunction = '';
          my $nParams = '';
          my $nbFlush = 0;
          my $Buf = '';
          my $BufESC = '';

          # See if the parameters contain additional nested functions
          #
          # Continue to call GetNextSegment to see if a function is present
          #
          while ($ns != -1 && $ne != -1) {
            # Check for recursive limit
            $ParseCount++;
            if ( $ParseCount >= $self->{_ParseMax}
              || $NestedFunctionCount >= $self->{_ParseMax}
              ) {
              $self->print("getNextSegment: Parse: Max Parses within Parse reached [".$self->{_ParseMax}."]");
              last;
            }
            #
            # Get the next segment from the Buffer (starting after the Function Assignment Start (fas)
            # to see if it contains a "nested" Function before Function Assignment End (fae)
            #
            #
            ($ns, $ne, $nToken, $nFunction, $nParams, $nbFlush) = $self->getNextSegment($Buffer, $ns, $ne, $NestedFunctionCount+1);
            #

            # Add Statistic for Nested Function
            $self->AddStat("_Function Nested") if ($self->GetLogStat());

            # Leave if we picked up another function past the current Function End
            if ($ns > $fae
              || $ns >= $maxE-1
              ) {
              if (!$FoundNestedFunction) {
                $ns = -1;
                $ne = -1;
              }
              last;
            }

            #
            # See if we have a nested OML Function
            #
            if ($nFunction ne "") {
              # We found a nested function
              $FoundNestedFunction = 1;

              #
              # Get next Function End position if the nested function moved the end pos
              #
              if ($ne >= $fae+1) {
                #
                # Get next Function End after this segment's end
                #
                #$nfae = index($Buffer, ']#', $fae+2);
                $nfae = index($Buffer, ']#', $ne+1);

                # leave if we don't have any additional Function Ends
                if ($nfae == -1) {
                  last;
                }

                #
                # Set the Previous and New Function End
                #
                $pfae = $fae;
                $fae  = $nfae;

                #***********************************************************
                # Escape the function and replace in NEW params
                #
                # Get the FULL FUNCTION TEXT from the Buffer
                #
                $Buf = substr($Buffer, $ns, $ne-$ns+1);

                # UnEscape Buf for multiple layers deep on the way up
                #
                $Buf = $self->UnEscapeOMLFunction($Buf);

                # Cleanup the space and tabs between arg parameters makes ][ consistent without spaces, tabs, \n
                #
                $Buf = $self->FixArguments($Buf);

                # Escape any nested OML Function arguments ][ and end ]#
                #
                $BufESC = $self->EscapeOMLFunction($Buf);

                # Add New parameters to $lParams (past the prior ones)
                #
                $lParams = $lParams.substr($Buffer, $pfae, $fae-$pfae);

                # Cleanup the space and tabs between arg parameters makes ][ consistent without spaces, tabs, \n
                #
                $lParams = $self->FixArguments($lParams);

                # Now replace the Nested Function Buf with BufESC in the Parameters
                #
                # OML Functions don't replace well witn REGEX Regular Expressions because [ and ] are special characters
                # So use our own replace with index / substr for absolute replacement
                #
                $lParams = $U->Replace($lParams, $Buf, $BufESC);

                # Set the new end max
                $maxE = $nfae+1;

              } #end if ne >= fae+1

              # Reset the "search start" (ns) past the nested function end
              $ns = $ne+1;
              $ne = $ne+1;

              #
              # end if ($nFunction ne "")
            } else {
              # must be a token found
              last if ($ne == -1 || $nToken eq "");

              # Reset the previous start and start for next iteration
              #
              $ns  = $ne+1;
            }

          } #while
        } # end preemptive if for no Function patterns

        #***********************************************************************
        # END NESTED OML FUNCTIONS LOGIC
        #***********************************************************************

      } else {
        # Not a valid OML Function - no segment found
        # use end and retry for another token

        $lFunction = "";
        $lToken = "";
        $fas = -1;
        $fae = -1;
        $a = -1;
        $s = $e;
        next;
      }
      #
      # Leave and process function
      #
      # NOW set the end segment marker to the end of the Function
      $e = $fae+1;
      $FoundSegment = 1;
      last;
    } else {
      # Not a valid function - Reset token if it was part of Assignment
      $fas = -1;
      $fae = -1;
      $a = -1;
      $lToken = "";
      # next iteration
      $s = $e;
      next;
    }

  } # END WHILE LOOP

  #
  # Reset the package Start and End
  #
  # Set nothing else to search for condition
  $s = -1 if ($e == -1);

  return ($s, $e, $lToken, $lFunction, $lParams, $bFlush);
} #getNextSegment


#******************************************************************************************
#* StripComments
#*
#* - Remove comments <!--- ---> from the text
#******************************************************************************************
sub Orbit::StripComments
{
  my ( $self, $Text, $bShowComments ) = @_;
  $bShowComments = $self->{_bShowComments} if (!defined($bShowComments));

  # Replace with empty string and use matching pairs to next comments
  $Text = $self->StripText($Text, '<!---', '--->', '', 1, $bShowComments);

  return $Text;
} #StripComments


#******************************************************************************************
#* StripText
#*
#* - Iteratively strips text strings out of a given string based on the
#*   begin_text and end_string_text.  Ie. removing comments <!--- --->
#* - Returns the resulting string without the text in between begin and end
#* - If fv_replace_text is specified, replaces the match with this text
#* - Use fn_match_pairs = 1 to strip nested pairs, not just the first
#*   occurrence of the end text
#******************************************************************************************
sub Orbit::StripText
{
  my ( $self, $fv_text, $fv_begin_text, $fv_end_text, $fv_replace_text, $fn_match_pairs, $bKeepRawText ) = @_;
  my $U = $self->{_Utils};

  $fv_begin_text   = '<!---' if (!defined($fv_begin_text) || $fv_begin_text eq "");
  $fv_end_text     = '--->'  if (!defined($fv_end_text) || $fv_end_text eq "");
  $fv_replace_text = ''      if (!defined($fv_replace_text) || $fv_replace_text eq "");
  $fn_match_pairs  = 0       if (!defined($fn_match_pairs) || $fn_match_pairs ne "1");
  my $fv_textOUT = "";
  my $lb_match_pairs = 0;     #  BOOLEAN;
  my $li_start = 1;           #  BINARY_INTEGER = 1;
  my $li_end   = 1;           #  BINARY_INTEGER = 1;
  my $li_false_start = 0;     #  BINARY_INTEGER;
  my $li_end_length = 0;      #  BINARY_INTEGER;
  my $li_num = 0;             #  BINARY_INTEGER;

  if ($fv_text eq "" || $fv_begin_text eq "" || $fv_end_text eq "") {
    return "";
  }
  $li_end_length = length($fv_end_text);
  #-- match pairs only works if the begin and end text are different
  if ($fn_match_pairs == 0
     || $fv_begin_text eq $fv_end_text) {
    $lb_match_pairs = 0;
  } else {
    $lb_match_pairs = 1;
  }
  while (1)
  {
    if (!$lb_match_pairs) {
      #-- Look for first begin text and first end text
      $li_start = index($fv_text, $fv_begin_text);
      if ($li_start >= 0) {
        $li_end = index($fv_text, $fv_end_text, $li_start+1);
      }
    } else {
      #-- Match Pairs:
      #-- Look for first end text and) { BACK for first begin text from the end text
      $li_start = index($fv_text, $fv_begin_text);
      if ($li_start >= 0) {
        $li_false_start = index($fv_text, $fv_begin_text, $li_start+1);
        $li_end = index($fv_text, $fv_end_text, $li_start+1);
        if ($li_false_start >= 0
           && $li_end >= 0
           && $li_false_start < $li_end
          ) {
          while (1)
          {
            #-- Skip this fake start and end since they match
            $li_false_start = index($fv_text, $fv_begin_text, $li_false_start+1);
            $li_num = index($fv_text, $fv_end_text, $li_end+1);
            last if ($li_num == -1); #-- this was the last end, so match it to the first
            $li_end = $li_num;
            last if ($li_false_start == -1); #-- this was the last pair, so match it to the first
            last if ($li_false_start > $li_end);
          }
        }
      }
    }
    last if ( $li_start == -1
            || $li_end == -1);
    #-- Remove the trailing carriage return if the comment is the only thing on that line
    #-- Don't check for leading / trailing spaces (change 4 to $li_end_length, mj Dec22/2003)
    if (   (substr($fv_text, $li_start - 1, 1) eq "\n"
            || $li_start == 0
            )
       && substr($fv_text, $li_end + $li_end_length, 1) eq "\n"
       ) {
      $li_end = $li_end+1;
    }
    #-- Only take strings before and after comment
    if ($bKeepRawText && $fv_replace_text eq "") {
      # Get the text to be removed - replace #
      $fv_replace_text = substr($fv_text
                               ,$li_start + length($fv_begin_text)
                               ,$li_end-1 - $li_start - length($fv_begin_text));
      # Just Replace # with % so tokens aren't parsed in commented text
      $fv_replace_text =~ s/#/%/g;
      $fv_replace_text = $fv_begin_text.$fv_replace_text.$fv_end_text;
    } else {
      $fv_replace_text = "";
    }
    # Assign the checked text to OUT buf
    $fv_textOUT .= substr($fv_text, 0, $li_start).$fv_replace_text;
    # Assign the rest of text to fv_text for next loop
    $fv_text = substr($fv_text, $li_end + $li_end_length);
  }
  # Append any last segment
  $fv_textOUT .= $fv_text;
  # Return the stripped text
  return $fv_textOUT;
} #StripText


#========================================================================================
# END PARSING SUBROUTINES
#========================================================================================

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Parse;
#******************************************************************************************
1;


#END Orbit::OML::Parse Package
