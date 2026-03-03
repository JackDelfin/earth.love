#!/usr/bin/perl
# Version 7.0.2.0      23-Jan-2025
#*****************************************************************************************
#*
#* Orbit::OML::Function7 - Version 7
#*
#*  Package Name    :   Orbit::OML:Function7
#*
#*  Description     :   Coordinates Orbit Markup Language (OML) for Functions
#*
#*****************************************************************************************
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.17 earth.love oK Version 7 additions - direct OML function call; Function Groups
#   2021.06.02 earth.love oK Added OPTIONS function
#   2021.04.29 earth.love oK Refactored
#   2021.04.24 earth.love oK Converted from PL/SQL Orbit package (2015.05.30 Ver 5.0.0.0)
#   2025.01.22 earth.love oK Added RAND, RANDOM function
#   2025.01.23 earth.love oK Added Web, SysAdmin FunctionGroups
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
# ProcessFunction
#   - Processes a Function call for an orbit token and returns result
#     Second return parameter: TRUE if the function was processed, FALSE if not found
#
# LoadFunctionGroups <Function Group NUMBER or NAME or ALL>
#   - Loads the _OML_FUNCTIONS array with subroutine references
#   - ALL specifies load all groups
#
# GetFunctionGroup <Function>
#   - Returns the numeric Function Group for the standard Orbit OML Functions
#   - If using Mods, or want to pre-load groups the page needs,
#     use the LOADMOD OML function call.  ie #LOADMOD[CONDITIONAL]#
#
# GetFunctionError <function>
#   - Returns Function error text - called from Process Function
#
# IsArg <arg_index> <@FunArgs>
#   - Accepts an argument list separated by ][ (not beginning or ending with any separators)
#   - Returns TRUE if the argument exists, FALSE if it doesn't
#
# GetArgNoParse <arg_index> <@FunArgs>
#   - call to get_arguments w/o parsing
#   - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#
# GetArgParse <arg_index> <@FunArgs>
#   - local call to get_arguments - parse result field
#   - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#
# GetArguments
#   - Return the OML UnEscaped Function _Arguments text
#   - Useful for functions which take only one parameter
#
# FixArguments
#   - Removes any whitespace between function parameters - space, tab, "\n", chr(13)
#     between ] and [
#     ie. #FUNCTION [x]  [y]  [z]#
#   - Returns the cleaned argument String
#
# GetFunctionArgsArray [FunctionArgumentsText]
#   - Accepts a delimited list of parameters to an OML Function ][
#   - Removes any whitespace between function parameters - space, tab, chr(10), chr(13)
#     between ] and [
#     ie. #FUNCTION [x]  [y]  [z]#
#   - Unescapes any escaped OML Functions within the parameters (either by user or getNextSegment)
#   - Returns Array of arguments from the Function Arguments text specified
#
# EscapeOMLFunction
#   - Escape the function argument separator '][' and function/assignment end ']#'
#     ][  =>  \]\[       ]#  =>  \]\#
#
# UnEscapeOMLFunction
#   - UnEscape the function argument separator '][' and function/assignment end ']#'
#
# isOMLFunction
#   - Returns (1) if text is a valid OML Function Name (Orbit Markup Language)
#   - Will also load function groups if needed
#
#*******************************************************************************

package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Orbit::Utils;
#use Orbit::Token;
use Orbit::Utils::Message;

#========================================================================================
#
#                      FUNCTION OML (ORBIT MARKUP LANGUAGE) SUBROUTINES
#
#========================================================================================


#******************************************************************************************
#* ProcessFunction
#*
#* - Processes a Function call for an orbit token and returns result
#*   Second return parameter: TRUE if the function was processed, FALSE if not found
#******************************************************************************************
sub Orbit::ProcessFunction
{
  my ( $self ) = @_;
  my $U = $self->{_Utils};
  my $Function = $self->{_Function};

  # Add a summary statistic
  $self->AddStat("_Function Calls Total") if ($self->GetLogStat());
  # Only add specific function if LogStat > 1
  $self->AddStat("Function: ".$U->rpad($Function,12)) if ($self->GetLogStat() > 1);

  #
  # See if OML Function has a Subroutine Reference defined
  #
  if (!defined($self->{_OML_FUNCTIONS}->{$Function})) {
    #
    # Function Sub Ref NOT defined, so try to get the Function Group
    #
    my $FunGroup = $self->GetFunctionGroup($Function);

    #
    # Return if Function Group not found
    #
    if ($FunGroup == -1) {
      return ("ProcessFunction: Error: Function Group not found or loaded "
             ."for OML Function [$Function]. "
             ."Use &#035;LOADMOD[mod]&#035; for custom OML Mods.", 0);
    }
    
    #
    # Load a new Function Group for this OML Function
    #
    my $resp = $self->LoadFunctionGroups($FunGroup);

    # Leave if we don't have a valid Function Group loaded
    if ($resp ne "") {
      # Leave if not loaded - 101 always good advice
      return ($resp, 0);
    }
  }

  #
  # See if Subroutine Reference is defined for the OML Function
  #
  if (defined($self->{_OML_FUNCTIONS}->{$Function})) {
    #
    # Get the OML Function Subroutine Reference and Execute
    #
    my $FunSub = $self->{_OML_FUNCTIONS}->{$Function};
    # Dynamically run the subroutine and return results to $V
    my $V = '';
    { $V = $FunSub->(), 0 };
    return ($V,1);   # Return the Processed Value
  }

  # NOT Processed
  return ("ProcessFunction: Error: Function not processed [$Function]", 0);

} #ProcessFunction


#******************************************************************************************
#* LoadFunctionGroups <Function Group NUMBER or NAME or ALL>
#*
#* - Loads the _OML_FUNCTIONS array with subroutine references
#* - ALL specifies load all groups
#******************************************************************************************
sub Orbit::LoadFunctionGroups
{
  my ($O, $FunGroup ) = @_;

  #
  # Leave if the Function Group is already loaded
  #
  return "" if ($FunGroup eq "" || defined($O->{_FN_GROUPS_LOADED}->{$FunGroup}));

  #
  # Check for ALL entered
  #
  my $bAll = 0;
  if ($FunGroup =~ /^ALL$/i) {
    $bAll = 1;
    $FunGroup = -1;
  }

  #
  # Check for number (ie 21 = USERMOD21)
  #
  if (!$O->IsNumber($FunGroup)) {
    #
    # Try to get the Function Group by text
    # if an OML Function or Function Group name is specified
    #
    my $FunGroupSearch = $O->GetFunctionGroup($FunGroup);

    #
    # Make sure we got a Mod number
    #
    if ($FunGroupSearch eq '-1') {
      return "Function Group not found for [$FunGroup]";
    }
    $FunGroup = $FunGroupSearch;   # Found a Function Group
  }

  #
  # BASE Functions:
  # - Token Manipulation
  # - Include
  # - High Frequency Functions
  if ($bAll || $FunGroup == 0) {
    # BASE Functions:
    use Orbit::OML::Function::Base;
    $O->LoadBaseFunctions();   # Load the subroutine references into the _OML_FUNCTIONS array
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '00-BASE';
    return "" if (!$bAll);
  }
  #
  # CONDITIONAL Functions:
  if ($bAll || $FunGroup == 1) {
    use Orbit::OML::Function::Conditional;
    $O->LoadConditionalFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '01-CONDITIONAL';
    return "" if (!$bAll);
  }
  #
  # NUMERIC CONDITIONAL Functions:
  if ($bAll || $FunGroup == 2) {
    use Orbit::OML::Function::Numeric;
    $O->LoadNumericFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '02-NUMERIC';
    return "" if (!$bAll);
  }
  #
  # STRING Functions:
  if ($bAll || $FunGroup == 3) {
    use Orbit::OML::Function::String;
    $O->LoadStringFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '03-STRING';
    return "" if (!$bAll);
  }
  #
  # MATH Functions:
  if ($bAll || $FunGroup == 4) {
    use Orbit::OML::Function::Math;
    $O->LoadMathFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '04-MATH';
    return "" if (!$bAll);
  }
  #
  # DATE Functions:
  if ($bAll || $FunGroup == 5) {
    use Orbit::OML::Function::Date;
    $O->LoadDateFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '05-DATE';
    return "" if (!$bAll);
  }
  #
  # HTML Functions:
  if ($bAll || $FunGroup == 6) {
    use Orbit::OML::Function::HTML;
    $O->LoadHTMLFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '06-HTML';
    return "" if (!$bAll);
  }
  #
  # DATA Functions:
  if ($bAll || $FunGroup == 70) {
    use Orbit::OML::Function::Data;
    $O->LoadDataFunctions();
    $O->{_FN_GROUPS_LOADED}->{70} = '70-DATA';
    return "" if (!$bAll);
  }
  #
  # DATAPLUS Functions:
  if ($bAll || $FunGroup == 71) {
    use Orbit::OML::Function::DataPlus;
    $O->LoadDataPlusFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '71-DATAPLUS';
    return "" if (!$bAll);
  }
  #
  # LOOPING Functions:
  if ($bAll || $FunGroup == 8) {
    use Orbit::OML::Function::Looping;
    $O->LoadLoopingFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '08-LOOPING';
    return "" if (!$bAll);
  }
  #
  # INTERNAL Functions:
  if ($bAll || $FunGroup == 9) {
    use Orbit::OML::Function::Internal;
    $O->LoadInternalFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '09-INTERNAL';
    return "" if (!$bAll);
  }
  #
  # DISTANCE Functions:
  if ($bAll || $FunGroup == 10) {
    use Orbit::OML::Function::Distance;
    $O->LoadDistanceFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '10-DISTANCE';
    return "" if (!$bAll);
  }
  #
  # WRAP Functions:
  if ($bAll || $FunGroup == 11) {
    use Orbit::OML::Function::Wrap;
    $O->LoadWrapFunctions();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '11-WRAP';
    return "" if (!$bAll);
  }
  #
  # SysAdmin Functions:
  #  if ($bAll || $FunGroup == 12) {
  #  use Orbit::OML::Function::SysAdmin;
  #  $O->LoadWrapFunctions();
  #  $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '12-SYSADMIN';
  #  return "" if (!$bAll);
  #}
  #
  # Web Functions:
  #if ($bAll || $FunGroup == 13) {
  #  use Orbit::OML::Function::Web;
  #  $O->LoadWrapFunctions();
  #  $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '13-WEB';
  #  return "" if (!$bAll);
  #}
  #
  # 21 MOD Functions:
  if ($bAll || $FunGroup == 21) {
    use Orbit::OML::Function::UserMod21;
    $O->LoadFunctionGroup21();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '21-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 22 MOD Functions:
  if ($bAll || $FunGroup == 22) {
    use Orbit::OML::Function::UserMod22;
    $O->LoadFunctionGroup22();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '22-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 23 MOD Functions:
  if ($bAll || $FunGroup == 23) {
    use Orbit::OML::Function::UserMod23;
    $O->LoadFunctionGroup23();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '23-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 24 MOD Functions:
  if ($bAll || $FunGroup == 24) {
    use Orbit::OML::Function::UserMod24;
    $O->LoadFunctionGroup24();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '24-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 25 MOD Functions:
  if ($bAll || $FunGroup == 25) {
    use Orbit::OML::Function::UserMod25;
    $O->LoadFunctionGroup25();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '25-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 26 MOD Functions:
  if ($bAll || $FunGroup == 26) {
    use Orbit::OML::Function::UserMod26;
    $O->LoadFunctionGroup26();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '26-USERMOD';
    return "" if (!$bAll);
  }
  #
  # 27 MOD Functions:
  if ($bAll || $FunGroup == 27) {
    use Orbit::OML::Function::UserMod27;
    $O->LoadFunctionGroup27();
    $O->{_FN_GROUPS_LOADED}->{$FunGroup} = '27-USERMOD';
    return "" if (!$bAll);
  }
  #
  # Bad Function Group if !ALL and we made it here
  if (!$bAll) {
    return "LoadFunctionGroups: Bad Function Group: [$FunGroup]";
  }
  # Successful
  return "";
} #LoadFunctionGroups


#******************************************************************************************
#* GetFunctionGroup <Function>
#*
#* - Returns the numeric Function Group for the standard Orbit OML Functions
#* - If using Mods, or want to pre-load groups the page needs,
#*   use the LOADMOD OML function call.  ie #LOADMOD[CONDITIONAL]#
#******************************************************************************************
sub Orbit::GetFunctionGroup
{
  my ( $self, $Function ) = @_;
  $Function =~ tr/[a-z]/[A-Z]/;   # Uppercase Function
  my $FunGrp = '';
  #
  # Check for Function Group name passed in
  #
  return 0  if ($Function eq 'BASE');
  return 1  if ($Function eq 'CONDITIONAL');
  return 2  if ($Function eq 'NUMERIC');
  return 3  if ($Function eq 'STRING');
  return 4  if ($Function eq 'MATH');
  return 5  if ($Function eq 'DATE');
  return 6  if ($Function eq 'HTML');
  return 70 if ($Function eq 'DATA');
  return 71 if ($Function eq 'DATAPLUS');
  return 8  if ($Function eq 'LOOPING');
  return 9  if ($Function eq 'INTERNAL');
  return 10 if ($Function eq 'DISTANCE');
  return 11 if ($Function eq 'WRAP');
  #
  # Look for User Mods - <anything>MOD2x - so you can name your mod - JackMod21
  #
  return 21 if ($Function =~ /.*MOD21$/i);   # USERMOD21 MOD21
  return 22 if ($Function =~ /.*MOD22$/i);
  return 23 if ($Function =~ /.*MOD23$/i);
  return 24 if ($Function =~ /.*MOD24$/i);
  return 25 if ($Function =~ /.*MOD25$/i);
  return 26 if ($Function =~ /.*MOD26$/i);
  return 27 if ($Function =~ /.*MOD27$/i);
  
  #
  # 01 - Conditional Functions
  #
  $FunGrp = ' EVAL AND OR '
           .' NOTEXISTS ISNULL NULL '
           .' LIKE ILIKE IN INLIKE NOTIN NOTINLIKE ';
  return 1 if ($FunGrp =~ /.* $Function .*/);
  #
  # 02 - Numeric Conditional Functions
  #
  $FunGrp = ' GT GREATERTHAN LT LESSTHAN GE GREATEREQUAL LE LESSEQUAL BETWEEN ';
  return 2 if ($FunGrp =~ /.* $Function .*/);
  #
  # 03 - String Functions
  #
  $FunGrp = ' REPLACE REPLACEALL IREPLACE IREPLACEALL FORMAT '
           .' SUBSTR SUBSTR0 INSTR INDEX TRANSLATE '
           .' RPAD LPAD RTRIM LTRIM TRIM APPEND ';
  return 3 if ($FunGrp =~ /.* $Function .*/);
  #
  # 04 - Math Functions
  #
  $FunGrp = ' ROUND TRUNC SIGN ABS MOD '
           .' ADD SUB SUBTRACT MULT MULTIPLY DIV DIVIDE '
           .' MIN MAX AVG RAND RANDOM FIBONACCI';
  return 4 if ($FunGrp =~ /.* $Function .*/);
  #
  # 05 Date Functions
  #
  $FunGrp = ' TIMER STOPTIMER DATE TIME SYSDATE GMTSYSDATE '
           .' TIMESTAMP TRANSACTIONID ';
  return 5 if ($FunGrp =~ /.* $Function .*/);
  #
  # 06 - HTML Helper Functions
  #
  $FunGrp = ' SELECTED OPTIONS JSQUOTE HELP HELPOVER MSGHELP ';
  return 6 if ($FunGrp =~ /.* $Function .*/);
  #
  # 71 - Akashic Data PLUS Processing Functions
  #
  $FunGrp = ' DATAOPEN DATAPATH DOTDOT DATACLOSE DATASEP DATASORT DATAHEADER '
           .' DATASEARCH DATAREAD DATAFORMAT '
           .' DATAREC RECORD REC ';
  return 71 if ($FunGrp =~ /.* $Function .*/);
  #
  # 08 - Looping Functions
  #
  $FunGrp = ' REPEAT WHILE COMMALIST PIPELIST ';
  return 8 if ($FunGrp =~ /.* $Function .*/);
  #
  # 09 - Orbit Internal Functions
  #
  $FunGrp = ' DELETE BACKUPEXT NUMFORMAT CACHE UNCACHE DEBUG '
           .' SHOWCOMMENTS LOGSTATS SHOWSTATS LICENSE VERSION '
           .' MSGTRANSLATE MSGINSERT ';
  return 9 if ($FunGrp =~ /.* $Function .*/);
  #
  # 10 - Distance Functions
  #
  $FunGrp = ' DISTANCE BEARING ';
  return 10 if ($FunGrp =~ /.* $Function .*/);
  #
  # 11 - Wrap and Text Formatting
  #
  $FunGrp = ' ROWS WRAP WRAPTOKEN STRIPTEXT ';
  return 11 if ($FunGrp =~ /.* $Function .*/);
  #
  # BASE AND DATA SHOULD BE LOADED BY DEFAULT
  # - But... Just in case, we'll check again
  #
  # Base Functions - Token Assign, Include, Common Conditional
  #
  $FunGrp = ' LOADMOD ASSIGN PARSE LOADTOKEN TOKENLOAD LOADMSG MSGLOAD BACKUP RESTORE '
           .' INCLUDE INC OML FUNCTION '
           .' IFINCLUDE INCLUDEIF INCIF IFINC OMLIF IFOML '
           .' BEFORE AFTER SHOWON STOP '
           .' MESSAGE MSG MSGLIST IF EQUAL NOTEQUAL NVL '
           .' LANGUAGE LANG SETLANG '
           .' DECODE DECODELIKE CASE '
           .' EXISTS ISNOTNULL NOTNULL ';
  return 0 if ($FunGrp =~ /.* $Function .*/);
  #
  # Akashic Data Processing Functions
  #
  $FunGrp = ' DATA DATAFILE FILE GETFILE DATAFIELD FIELD FIELDMSG GETFIELD ';
  return 70 if ($FunGrp =~ /.* $Function .*/);
  # No group - return -1
  return -1;
} #GetFunctionGroup


################################################################################
# END ProcessFunction
################################################################################


#******************************************************************************************
#* GetFunctionError <function>
#*
#* - Returns Function error text - called from Process Function
#******************************************************************************************/
sub Orbit::GetFunctionError
{
  my ( $self, $Function ) = @_;
  return 'ORB-101: Not enough arguments for function: ['.$Function.']';
} #GetFunctionError;


#******************************************************************************************
#* IsArg <arg_index> <@FunArgs>
#*
#* - Accepts an argument list separated by ][ (not beginning or ending with any separators)
#* - Returns TRUE if the argument exists, FALSE if it doesn't
#******************************************************************************************
sub Orbit::IsArg
{
  my ( $self, $ArgIndex, @FunArgs ) = @_;
  $ArgIndex--;   # Use as a number (Offset read by 1)
  return 1 if (defined($FunArgs[$ArgIndex]));
  return 0;
} #IsArg


#--------------------------------------------------
#-- GetArgNoParse <arg_index> <@FunArgs>
#-- - call to get_arguments w/o parsing
#-- - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#--------------------------------------------------
sub Orbit::GetArgNoParse
{
  my ( $self, $ArgIndex, @FunArgs ) = @_;
  my $ArgValue = "";

  $ArgIndex--;   # Use as a number (Offset read by 1)

  # Make sure argument exists
  if (defined($FunArgs[$ArgIndex])) {
    $ArgValue = $FunArgs[$ArgIndex];
  }

  return $ArgValue;
} #GetArgNoParse;


#--------------------------------------------------
#-- GetArgParse <arg_index> <@FunArgs>
#-- - local call to get_arguments - parse result field
#-- - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#--------------------------------------------------
sub Orbit::GetArgParse
{
  my ( $self, $ArgIndex, @FunArgs ) = @_;
  my $ArgValue = "";

  $ArgIndex--;   # Use as a number (Offset read by 1)

  # Make sure argument exists
  if (defined($FunArgs[$ArgIndex])) {
    $ArgValue = $FunArgs[$ArgIndex];
  }

  #
  # Parse the argument for additional OML
  #
  $ArgValue = $self->Parse($ArgValue, 0);   # Parse, no print, return buffer

  # Parse again for tokens within tokens if pattern present
  if ($ArgValue =~ /^.*#[A-Z_\.]*#.*$/i) {
    $ArgValue = $self->Parse($ArgValue, 0);
  }

  return $ArgValue;
} #GetArgParse


#--------------------------------------------------
# GetArguments
#   - Return the OML UnEscaped Function _Arguments text
#   - Useful for functions which take only one parameter
#--------------------------------------------------
sub GetArguments
{
  my ($self) = @_;
  return $self->UnEscapeOMLFunction($self->{_Arguments});
} #GetArguments


#******************************************************************************************
#* FixArguments
#*
#* - Removes any whitespace between function parameters - space, tab, "\n", chr(13)
#*   between ] and [
#*   ie. #FUNCTION [x]  [y]  [z]#
#* - Returns the cleaned argument String
#******************************************************************************************/
sub Orbit::FixArguments
{
  my ( $self, $fv_list ) = @_;

  return "" if (!defined($fv_list) || $fv_list eq "");

  my $ln_begin = 0;        # PLS_INTEGER = 1;
  my $ln_end = 0;          # PLS_INTEGER;
  my $lv_whitespace = '';  # LONG;

  # This works great
  $fv_list =~ s/\][ \n\t]*\[/\]\[/g;

  # Return the cleaned parameters
  return $fv_list;
} #FixArguments;


#******************************************************************************************
#* GetFunctionArgsArray [FunctionArgumentsText]
#*
#* - Accepts a delimited list of parameters to an OML Function ][
#* - Removes any whitespace between function parameters - space, tab, chr(10), chr(13)
#*   between ] and [
#*   ie. #FUNCTION [x]  [y]  [z]#
#* - Unescapes any escaped OML Functions within the parameters (either by user or getNextSegment)
#* - Returns Array of arguments from the Function Arguments text specified, typically to @FunArgs
#******************************************************************************************
sub Orbit::GetFunctionArgsArray
{
  my ( $self, $Args ) = @_;

  my @FUNARGS;

  # Boolean for existence of nested functions
  my $bNested = 1;

  # Get the Function Arguments from global variable if not entered
  $Args = $self->{_Arguments} if (!defined($Args));

  # Check for just 1 Function Arg - ][ not found in string
  if ( $Args eq ""
    || !($Args =~ /.*\]\[.*/)   # ][ not found
    ) {
    #
    # UnEscape any nested OML Function arguments ][ and end ]#
    #
    $Args = $self->UnEscapeOMLFunction($Args);

    $FUNARGS[0] = $Args;
    return @FUNARGS;
  }

  #
  # Create the array from the string, indexing so we can sort or reference in order
  #
  my $s = index($Args, "][", 0);
  my $i=-1;
  my $last=0;
  my $arg='';
  while ($s >= 0)
  {
    $i++;   # increase the index counter
    #
    # Get the string up to the first ][
    $arg = substr($Args, $last, $s-$last);   # up to first ][

    #
    # UnEscape any nested OML Function arguments ][ and end ]#
    #
    $arg = $self->UnEscapeOMLFunction($arg);

    # Assign the arg to the Function array
    $FUNARGS[$i] = $arg;
    #
    # Get the next index
    $last = $s+2;
    $s = index($Args, "][", $s+2);
    #
    # LAST ARG
    # If we're done, dump the rest of string to last Arg++
    if ($s == -1) {
      $i++;   # increase index in array
      # Get arg to the end of the string
      $arg = substr($Args, $last);
      #
      # UnEscape any nested OML Function arguments ][ and end ]#
      #
      $arg = $self->UnEscapeOMLFunction($arg);

      $FUNARGS[$i] = $arg;  # after ][
      last;
    }
  }

  # Return Function Argument Array
  return @FUNARGS;
} #GetFunctionArgsArray


#******************************************************************************************
#* EscapeOMLFunction
#*
#* - Escape the function argument separator '][' and function/assignment end ']#'
#*   ][  =>  \]\[       ]#  =>  \]\#
#******************************************************************************************
sub Orbit::EscapeOMLFunction
{
  my ( $self, $Buf ) = @_;

  $Buf =~ s/\]\[/\\\]\\\[/g;   # Changes ][ to \]\[
  $Buf =~ s/\]#/\\\]\\#/g;     # Changes ]# to \]\#

  return $Buf;
} #EscapeOMLFunction


#******************************************************************************************
#* UnEscapeOMLFunction
#*
#* - UnEscape the function argument separator '][' and function/assignment end ']#'
#******************************************************************************************
sub Orbit::UnEscapeOMLFunction
{
  my ( $self, $Buf ) = @_;

  $Buf =~ s/\\\]\\\[/\]\[/g;   # Changes \]\[ to ][
  $Buf =~ s/\\\]\\#/\]#/g;     # Changes \]\# to ]#

  return $Buf;
} #UnEscapeOMLFunction


#******************************************************************************************
#* isOMLFunction
#*
#* - Returns (1) if text is a valid OML Function Name (Orbit Markup Language)
#* - Will also load function groups if needed
#******************************************************************************************
sub Orbit::isOMLFunction
{
  my ( $self, $lText ) = @_;

  # Token Assignment uses function ASSIGN (without parsing) - #token=ASSIGN[]# #token=[]#
  return 0 if (!defined($lText) || $lText eq "");

  # Uppercase function name for searching
  $lText =~ tr/[a-z]/[A-Z]/;

  # Check for valid syntax first
  return 0 if (!$self->isTokenSyntax($lText));

  # Valid name for a function, now see if it exists in _FUNCTIONS hash
  # Check Function Hash - fast
  return 1 if (defined($self->{_OML_FUNCTIONS}->{$lText}));

  # Function NOT found - try loading Function Groups
  #
  # Function Sub Ref NOT defined, so try to get the Function Group
  #
  my $FunGroup = $self->GetFunctionGroup($lText);
  # Return if Function Group not found
  return 0 if ($FunGroup == -1);
    
  #
  # Load a new Function Group for this OML Function
  #
  $self->LoadFunctionGroups($FunGroup);

  # Check One more time after Functions are loaded
  return 1 if (defined($self->{_OML_FUNCTIONS}->{$lText}));

  # NOT a Valid Function
  return 0;
} #isOMLFunction


#========================================================================================
# END FUNCTION OML SUBROUTINES
#========================================================================================

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function7;
#******************************************************************************************
1;


#END Orbit::OML::Function7 Package
