#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Base - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Base
#*
#*  Description     :   Implements Orbit Markup Language (OML) for BASE Functions
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Version 7
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
# OML Functions Supported
#*****************************************************************************************
# LoadBaseFunctions
#   - Load the Base OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# LOADMOD
#
# ASSIGN
# LOADTOKEN   TOKENLOAD
# LOADMSG     MSGLOAD
# PARSE       ONEPARSE
# GETTOKEN
# BACKUP
# RESTORE
# INCLUDE     FUNCTION    OML     INC
# IFINCLUDE   INCLUDEIF   OMLIF   INCIF   IFOML   IFINC
#             BEFORE      AFTER   SHOWON
# STOP
# MESSAGE     MSG    MSGLIST   MSGHELP 
# LANGUAGE    LANG   SETLANG
# IF
# EQUAL
# NOTEQUAL
# NVL
# DECODE      DECODELIKE   CASE
# EXISTS      ISNOTNULL    NOTNULL
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadBaseFunctions
#   - Load the Base OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub LoadBaseFunctions
{
  my ( $O ) = @_;
  ########################################
  #
  # Load the OML Functions into the sub ref array
  #
  ########################################
  
  $O->{_OML_FUNCTIONS}->{'LOADMOD'}    = sub { $O->omlLOADMOD(), };

  $O->{_OML_FUNCTIONS}->{'LOADTOKEN'}  = sub { $O->omlLOADTOKEN(), };
  $O->{_OML_FUNCTIONS}->{'TOKENLOAD'}  = sub { $O->omlLOADTOKEN(), };
  $O->{_OML_FUNCTIONS}->{'LOADMSG'}    = sub { $O->omlLOADTOKEN(), };
  $O->{_OML_FUNCTIONS}->{'MSGLOAD'}    = sub { $O->omlLOADTOKEN(), };

  $O->{_OML_FUNCTIONS}->{'ASSIGN'}     = sub { $O->omlASSIGN(), };
  $O->{_OML_FUNCTIONS}->{'PARSE'}      = sub { $O->omlPARSE(), };
  $O->{_OML_FUNCTIONS}->{'ONEPARSE'}   = sub { $O->omlONEPARSE(), };
  $O->{_OML_FUNCTIONS}->{'GETTOKEN'}   = sub { $O->omlGETTOKEN(), };
  $O->{_OML_FUNCTIONS}->{'BACKUP'}     = sub { $O->omlBACKUP(), };
  $O->{_OML_FUNCTIONS}->{'RESTORE'}    = sub { $O->omlRESTORE(), };
  
  # MESSAGE
  $O->{_OML_FUNCTIONS}->{'MESSAGE'}    = sub { $O->omlMSG(), };
  $O->{_OML_FUNCTIONS}->{'MSG'}        = sub { $O->omlMSG(), };
  $O->{_OML_FUNCTIONS}->{'MSGLIST'}    = sub { $O->omlMSG(), };
  $O->{_OML_FUNCTIONS}->{'MSGHELP'}    = sub { $O->omlMSG(), };
  # LANGUAGE
  $O->{_OML_FUNCTIONS}->{'LANGUAGE'}   = sub { $O->omlLANGUAGE(), };
  $O->{_OML_FUNCTIONS}->{'LANG'}       = sub { $O->omlLANGUAGE(), };
  $O->{_OML_FUNCTIONS}->{'SETLANG'}    = sub { $O->omlLANGUAGE(), };

  $O->{_OML_FUNCTIONS}->{'INCLUDE'}    = sub { $O->omlINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'FUNCTION'}   = sub { $O->omlINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'OML'}        = sub { $O->omlINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'INC'}        = sub { $O->omlINCLUDE(), };
  
  $O->{_OML_FUNCTIONS}->{'IFINCLUDE'}  = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'INCLUDEIF'}  = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'INCIF'}      = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'IFINC'}      = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'OMLIF'}      = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'IFOML'}      = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'BEFORE'}     = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'AFTER'}      = sub { $O->omlIFINCLUDE(), };
  $O->{_OML_FUNCTIONS}->{'SHOWON'}     = sub { $O->omlIFINCLUDE(), };

  $O->{_OML_FUNCTIONS}->{'STOP'}       = sub { $O->omlSTOP(), };

  $O->{_OML_FUNCTIONS}->{'IF'}         = sub { $O->omlIF(), };
  $O->{_OML_FUNCTIONS}->{'EQUAL'}      = sub { $O->omlEQUAL(), };
  $O->{_OML_FUNCTIONS}->{'NOTEQUAL'}   = sub { $O->omlNOTEQUAL(), };
  $O->{_OML_FUNCTIONS}->{'NVL'}        = sub { $O->omlNVL(), };
  
  $O->{_OML_FUNCTIONS}->{'DECODE'}     = sub { $O->omlDECODE(), };
  $O->{_OML_FUNCTIONS}->{'DECODELIKE'} = sub { $O->omlDECODE(), };
  $O->{_OML_FUNCTIONS}->{'CASE'}       = sub { $O->omlDECODE(), };
  
  $O->{_OML_FUNCTIONS}->{'EXISTS'}     = sub { $O->omlEXISTS(), };
  $O->{_OML_FUNCTIONS}->{'ISNOTNULL'}  = sub { $O->omlEXISTS(), };
  $O->{_OML_FUNCTIONS}->{'NOTNULL'}    = sub { $O->omlEXISTS(), };

  ########################################
  #
  # Load the OML Token Modifiers into the Token Mod sub ref (subroutine reference) array
  #
  ########################################

  #
  # String Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'trim'}        = sub { $O->modTRIM(), };
  $O->{_TOKEN_MODIFIERS}->{'ltrim'}       = sub { $O->modLTRIM(), };
  $O->{_TOKEN_MODIFIERS}->{'rtrim'}       = sub { $O->modRTRIM(), };
  $O->{_TOKEN_MODIFIERS}->{'space'}       = sub { $O->modSPACE(), };
  $O->{_TOKEN_MODIFIERS}->{'length'}      = sub { $O->modLENGTH(), };
  $O->{_TOKEN_MODIFIERS}->{'upper'}       = sub { $O->modUPPER(), };
  $O->{_TOKEN_MODIFIERS}->{'lower'}       = sub { $O->modLOWER(), };
  $O->{_TOKEN_MODIFIERS}->{'initcap'}     = sub { $O->modINITCAP(), };
  $O->{_TOKEN_MODIFIERS}->{'initname'}    = sub { $O->modINITNAME(), };
  $O->{_TOKEN_MODIFIERS}->{'namecap'}     = sub { $O->modINITNAME(), };
  #
  # Existence Modifiers used for Boolean Conditions
  #
  $O->{_TOKEN_MODIFIERS}->{'0'}           = sub { $O->mod0(), };
  $O->{_TOKEN_MODIFIERS}->{'1'}           = sub { $O->mod1(), };
  $O->{_TOKEN_MODIFIERS}->{'not'}         = sub { $O->modNOT(), };
  $O->{_TOKEN_MODIFIERS}->{'isnumber'}    = sub { $O->modISNUMBER(), };
  $O->{_TOKEN_MODIFIERS}->{'exists'}      = sub { $O->modEXISTS(), };
  $O->{_TOKEN_MODIFIERS}->{'isnotnull'}   = sub { $O->modEXISTS(), };
  $O->{_TOKEN_MODIFIERS}->{'notexists'}   = sub { $O->modNOTEXISTS(), };
  $O->{_TOKEN_MODIFIERS}->{'isnull'}      = sub { $O->modNOTEXISTS(), };
  $O->{_TOKEN_MODIFIERS}->{'null'}        = sub { $O->modNULL(), };
  $O->{_TOKEN_MODIFIERS}->{'eval'}        = sub { $O->modEVAL(), };
  #
  # Textarea Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'rows'}        = sub { $O->modROWS(), };
  $O->{_TOKEN_MODIFIERS}->{'cols'}        = sub { $O->modCOLS(), };
  #
  # HTML Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'html'}        = sub { $O->modHTML(), };
  $O->{_TOKEN_MODIFIERS}->{'raw'}         = sub { $O->modHTML(), };
  $O->{_TOKEN_MODIFIERS}->{'nbsp'}        = sub { $O->modNBSP(), };
  $O->{_TOKEN_MODIFIERS}->{'tr'}          = sub { $O->modTR(), };
  $O->{_TOKEN_MODIFIERS}->{'checked'}     = sub { $O->modCHECKED(), };
  $O->{_TOKEN_MODIFIERS}->{'checkbox'}    = sub { $O->modCHECKBOX(), };
  $O->{_TOKEN_MODIFIERS}->{'notags'}      = sub { $O->modNOTAGS(), };
  $O->{_TOKEN_MODIFIERS}->{'noparse'}     = sub { $O->modNOPARSE(), };
  $O->{_TOKEN_MODIFIERS}->{'noquote'}     = sub { $O->modNOQUOTE(), };
  $O->{_TOKEN_MODIFIERS}->{'untag'}       = sub { $O->modUNTAG(), };
  $O->{_TOKEN_MODIFIERS}->{'unparse'}     = sub { $O->modUNPARSE(), };
  $O->{_TOKEN_MODIFIERS}->{'unraw'}       = sub { $O->modUNRAW(), };
  $O->{_TOKEN_MODIFIERS}->{'nohtml'}      = sub { $O->modNOHTML(), };
  $O->{_TOKEN_MODIFIERS}->{'jsquote'}     = sub { $O->modJSQUOTE(), };
  $O->{_TOKEN_MODIFIERS}->{'br'}          = sub { $O->modBR(), };
  $O->{_TOKEN_MODIFIERS}->{'nowrap'}      = sub { $O->modNOWRAP(), };
  #
  # Numeric Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'sign'}        = sub { $O->modSIGN(), };
  $O->{_TOKEN_MODIFIERS}->{'round'}       = sub { $O->modROUND(), };
  $O->{_TOKEN_MODIFIERS}->{'round2'}      = sub { $O->modROUND2(), };
  $O->{_TOKEN_MODIFIERS}->{'round1'}      = sub { $O->modROUND1(), };
  $O->{_TOKEN_MODIFIERS}->{'trunc'}       = sub { $O->modTRUNC(), };
  $O->{_TOKEN_MODIFIERS}->{'abs'}         = sub { $O->modABS(), };
  $O->{_TOKEN_MODIFIERS}->{'ceil'}        = sub { $O->modCEIL(), };
  $O->{_TOKEN_MODIFIERS}->{'floor'}       = sub { $O->modFLOOR(), };
  $O->{_TOKEN_MODIFIERS}->{'percent'}     = sub { $O->modPERCENT(), };
  $O->{_TOKEN_MODIFIERS}->{'percent1'}    = sub { $O->modPERCENT1(), };
  $O->{_TOKEN_MODIFIERS}->{'percent2'}    = sub { $O->modPERCENT2(), };
  #
  # Custom Token Functions
  #
  $O->{_TOKEN_MODIFIERS}->{'oml'}         = sub { $O->modOML(), };
  #
  # Token Action functions - affects token table
  #
  $O->{_TOKEN_MODIFIERS}->{'backup'}      = sub { $O->modBACKUP(), };
  $O->{_TOKEN_MODIFIERS}->{'restore'}     = sub { $O->modRESTORE(), };
  #
  # Caching Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'cache'}       = sub { $O->modCACHE(), };
  $O->{_TOKEN_MODIFIERS}->{'uncache'}     = sub { $O->modUNCACHE(), };
  #
  # Earth.Love Modifiers
  #
  $O->{_TOKEN_MODIFIERS}->{'earthify'}    = sub { $O->modEARTHIFY(), };
  $O->{_TOKEN_MODIFIERS}->{'earth'}       = sub { $O->modEARTHIFY(), };
  $O->{_TOKEN_MODIFIERS}->{'love'}        = sub { $O->modLOVE(), };

} #LoadBaseFunctions
# Alias - Function Group Base 00
*LoadFunctionGroup00 = \&LoadBaseFunctions;


#-----------------------------------------------------------------------------
#-- omlLOADMOD function - #LOADMOD[OML_Function_Module]#
#--
sub Orbit::omlLOADMOD
{
  my ($self) = @_;
  #
  # Get the Mod NUMBER or NAME
  #
  my $Mod = $self->GetArguments();
  
  #
  # Load a new Function Group for this OML Function
  #
  return $self->LoadFunctionGroups($Mod) if ($Mod ne "");
} #omlLOADMOD


#-----------------------------------------------------------------------------
#-- omlLOADTOKEN function - TOKEN Bulk Load #LOADTOKEN=[tok=value\n tok = value tok= [ value ]\n ...]#
#-- Load a list of tokens, carriage return separated, and token specified as:
#--   token = [ value ]
#--   token = value
#--   token=value
#-- - No parsing is done
#-- Overloaded for LOADMSG - translates each value as if calling MSG
#--
sub Orbit::omlLOADTOKEN
{
  my ($self) = @_;
  my $U = $self->{_Utils};
  #
  # Load the arguments dynamically if not defined
  #
  # Get Function name (certain functions, usually for aliases or overloads)
  my $Function = $self->{_Function};
  my $bFlush   = $self->{_bFlush};
  #
  # Get the CR separated list of Tokens
  # Just get the ONE argument
  #
  my $Tokens = $self->GetArguments();
  
  my $bMSG = 0;   # Translate messages
  $bMSG = 1 if ($Function =~ /.*MSG.*/);
  #
  # Loop through list and Set token/value pairs
  #
  if ($Tokens ne "") {
    my $tok;
    my $val;
    my $fn;   # Quick mini function
    my $split;
    my @TOKENS = split(/\n/, $Tokens);
    foreach my $tokval (@TOKENS) {
      next if ($tokval eq '');
      $split = index($tokval, '=');
      next if ($split == -1);   # Skip if bad format
      $tok = substr($tokval, 0, $split);
      $val = substr($tokval, $split+1);
      $tok = $U->trim($tok);
      next if ($tok eq '');
      $val = $U->trim($val);
      # Look for Function in Token Load
      if ($val =~ /^[a-z][a-z]*\[.*\][#]*$/i) {   # fn[.*]#
        $fn  = substr($val, 0, index($val, '['));
        $val = substr($val, index($val, '[')+1);   # Get arguments
        $val =~ s/\][#]*$//;   # remove ] suffix with or without #

        #
        # FUNCTION BUFFER SUPPORT
        #
        $self->{_Token}     = $tok;
        $self->{_Function}  = $fn;
        $self->{_Arguments} = $val;
        $self->{_bFlush}    = $bFlush;
        #$self->{_bCache}    = 0    # Cache Parameter for OML Function Calls

        #
        # Process the Function, passing in Function, Token, and arguments array.
        # Some functions use token name: ASSIGN/BACK
        #
        my $bProcessed;
        ($val, $bProcessed) = $self->ProcessFunction();
        $self->print('LoadToken: Function not processed: [$fn]') if (!$bProcessed);

        # Reset Function Parameter Buffer
        $self->{_Token}     = '';
        $self->{_Function}  = '';
        $self->{_Arguments} = '';
        $self->{_bFlush}    = 0;
        #$self->{_bCache}    = 0    # Cache Parameter for OML Function Calls
        #
        # END Function within LOADTOKEN
        #
      } else {
        $val =~ s/^\[//;       # remove [ prefix
        $val =~ s/\][#]*$//;   # remove ] suffix with or without #
      }
      # Get the Message translation text if this is LOADMSG
      $val = $self->GetMessageText($val) if ($bMSG);
      # Store the token
      $self->Set_Token($tok, $val);
    }
    if ($self->GetLogStat()) {
      $tok = @TOKENS;
      $val = $self->GetStat('_LOADTOKEN Tokens');
      $val = 0 if (!defined($val) || $val eq '');
      $self->AddStat('_LOADTOKEN Tokens', $tok+$val);
    }

    undef @TOKENS;
  }

  return "";
} #omlLOADTOKEN


#-----------------------------------------------------------------------------
#-- omlASSIGN function - TOKEN ASSIGNMENT   #token=[#text#]#  #ASSIGN[value][backup(1/0) or BackupExt]#
#-- Token Assignment without parsing (also #token=[value]# without function name);
#-- Backup (1) will set existing value of TOKEN to TOKEN_BACK as default, or
#-- BackupExt could be set instead (ie _BACKUP).
#-- - No parsing is done on the 1st argument
#--
sub Orbit::omlASSIGN
{
  my ($self) = @_;
  my $Token   = $self->{_Token};   # Get Token Name (certain functions)
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get the backup extension first
  my $a2 = $self->GetArgNoParse(2, @FunArgs);
  # Check for backup
  if ($a2 ne "0" && $a2 ne "") {
    #
    # Backup the token first
    #
    if ($a2 eq '1') {
      # Default backup
      $self->Set_Token($Token.$self->{_BackupExt}, $self->Get_Token($Token));
    } else {
      # Use user defined backup extension
      $self->Set_Token($Token.$a2, $self->Get_Token($Token));
    }
  }
  #
  # TOKEN ASSIGNMENT - Set return to first argument
  #
  my $V = $self->GetArgNoParse(1, @FunArgs);

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlASSIGN


#-----------------------------------------------------------------------------
#-- omlPARSE function #<token>=PARSE[<expression>]#
#--
sub Orbit::omlPARSE
{
  my ($self) = @_;
  #-- Parse the first argument and return (MJ 2002/12/27)
  my $V = $self->Parse($self->GetArguments(), 0);   # Parse, no print, return buffer
  
  # Parse again for tokens within tokens if pattern present
  if ($V =~ /^.*#[A-Z_\.]*#.*$/i) {
    $V = $self->Parse($V, 0);
  }
  return $V;
} #omlPARSE


#-----------------------------------------------------------------------------
#-- omlONEPARSE function #<token>=ONEPARSE[<expression>]#
#-- -  Parse the text only once
#--
sub Orbit::omlONEPARSE
{
  my ($self) = @_;
  #-- Parse the first argument and return (MJ 2002/12/27)
  my $V = $self->Parse($self->GetArguments(), 0);   # Parse, no print, return buffer
  return $V;
} #omlONEPARSE


#-----------------------------------------------------------------------------
#-- omlGETTOKEN function #<token>=GETTOKEN[<expression>]#
#-- -  Get's the token value without parsing
#--
sub Orbit::omlGETTOKEN
{
  my ($self) = @_;
  my $V = $self->GetArguments();
  # Check for Token Reference
  if ($V =~ /^#.*#$/) {
    # Remove the # to get the token name
    $V =~ s/#//g;
    # Get the Token Reference value - should be a Token Name
    $V = $self->GetToken($V);
  }
  # Get the Token value without parsing
  $V = $self->GetToken($V);
  return $V;
} #omlGETTOKEN


#-----------------------------------------------------------------------------
#-- omlBACKUP function - #BACKUP[token]...[token]#
#-- Backup all of the TOKENs, setting existing value to TOKEN_BACK (default).
#-- #BackupExt[_BAK]# provides an alternate Extension.
sub Orbit::omlBACKUP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";   # Action function - no return value
  my $Tokens = "";
  # Loop through all arguments to restore
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $Tokens = $U->trim($self->GetArgNoParse($I, @FunArgs));

    # Check for multiple tokens space separated
    if (index($Tokens, ' ') == -1) {
      # Single token
      $self->Set_Token($Tokens.$self->{_BackupExt}, $self->Get_Token($Tokens)) if ($Tokens ne "");
    } else {
      # Multiple tokens specified
      my @TOKENS = split(' ', $Tokens);
      foreach my $tok (@TOKENS) {
        $self->Set_Token($tok.$self->{_BackupExt}, $self->Get_Token($tok)) if ($tok ne '');
      }
      undef @TOKENS;
    }
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlBACKUP


#-----------------------------------------------------------------------------
#-- omlRESTORE function - #RESTORE[token]...[token]#
#-- Restore all of the token values to TOKEN_BACK. Only uses default Backup Extension
sub Orbit::omlRESTORE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";   # Action function - no return value
  my $Tokens="";
  # Loop through all arguments to restore
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $Tokens = $self->GetArgNoParse($I, @FunArgs);
    if ($Tokens ne "") {
    }

    # Check for multiple tokens space separated
    if (index($Tokens, ' ') == -1) {
      # Single token
      $self->Set_Token($Tokens, $self->Get_Token($Tokens.$self->{_BackupExt})) if ($Tokens ne "");
    } else {
      # Multiple tokens specified
      my @TOKENS = split(' ', $Tokens);
      foreach my $tok (@TOKENS) {
        $self->Set_Token($tok, $self->Get_Token($tok.$self->{_BackupExt})) if ($tok ne "");
      }
      undef @TOKENS;
    }
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlRESTORE


#-----------------------------------------------------------------------------
#-- omlINCLUDE function - #INCLUDE[<template>].[_1_].[_2_].[_3_]...[_n_]#
#-- Defines function parameters as tokens (#_1_# #_2_# ...) based on user parameters
#-- It is wise to assign these params at the beginning of the OML template if there are other nested calls
#-- NOTE: These tokens are NOT unassigned after the function call, in order to support nested INC / OML calls
#-- Aliases: INC OML FUNCTION
sub Orbit::omlINCLUDE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $U = $self->{_Utils};
  my $V = "";
  # Parse the arg if it contains #*# hash tie fighter similarity
  my $Template = $self->GetArgParse(1, @FunArgs);

  # Make sure template arg exists
  if ($Template ne "") {
    # Get the template filename
    my $TempleFile = $self->SearchTemplateDirs( $Template );

    # See if we have arguments to the include: set as #_1_# #_2_# ...
    if ($self->IsArg(2, @FunArgs)) {
      # search through each Arg and set it as a parameter to INCLUDE
      for (my $I=2; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Set_Token('_'.($I-1).'_', $self->GetArgNoParse($I, @FunArgs));
      }
    }

    # Get the template if it exists
    if (-e $TempleFile) {
      # Get the file contents and done
      $V = $U->GetFile($TempleFile, 1);
      # Strip out the developer comments <!--- ---> before returning
      # Only show comments if we're flushing and ShowComments are on,
      # otherwise it could be a return value in token assign
      my $bRawComments = ($self->{_bShowComments} && $bFlush)?1:0;
      $V = $self->StripComments($V, $bRawComments);
      # Parse the results
      $V = $self->Parse($V, $bFlush);
    } else {
      $V = "INCLUDE: Template not found [$Template]";
    }
    # Unset the #_x_# parameter tokens after call is done
    if ($self->IsArg(2, @FunArgs)) {
      for (my $I=2; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Delete_Token('_'.($I-1).'_');
      }
    }

    # Add Token Statistic for INCLUDE
    $self->AddStat("_Function Call: INCLUDE") if ($self->GetLogStat());

  }   # Ignore null INCLUDE: i.e. #INCLUDE[#notfound#]# - feature to pass in optional token

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlINCLUDE

#-----------------------------------------------------------------------------
#-- omlIFINCLUDE function - #IFINCLUDE[<expression>][then<template>].[else<template>].[_1_].[_2_].[_3_]...[_n_]#
#-- Aliases: INCLUDEIF INCIF IFINC OMLIF IFOML
#-- OVERLOADED:
#-- omlBEFORE / AFTER / SHOWON function - #AFTER[YYYYMMDDHHMISS].[then<template>].[else<template>].[_1_].[_2_].[_3_]...[_n_]#
#-- - Expression is a TIMESTAMP date/time mask - wildcards are the YYYY MM DD HH MI SS, or if not specified, as in YYYY1001 - Welcome to October every year
#-- Aliases: BEFORE AFTER SHOWON
sub Orbit::omlIFINCLUDE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get Function name (certain functions, usually for aliases or overloads)
  my $Function = $self->{_Function};
  my $bFlush   = $self->{_bFlush};
  my $U = $self->{_Utils};
  my $V = "";
  #-- Get the expression argument
  my $Expression = $self->GetArgNoParse(1, @FunArgs);
  my $Template = "";
  my $Eval = 0;
  my $Stop = 0;
  # Check for function type
  if ($Function =~ /.*IF.*/) {
    $Eval = $self->Eval($Expression);
  } else {
    # BEFORE / AFTER / SHOWON
    $Eval = $U->CompareDates($Expression, $U->Timestamp());
    $Stop = 1;
    $Stop = 0 if ($Eval == -1 && $Function eq 'BEFORE');
    $Stop = 0 if ($Eval == 1  && $Function eq 'AFTER');
    $Stop = 0 if ($Eval == 0  && $Function eq 'SHOWON');
  }
  #
  if ($Eval) {
    #-- Expression was true, so value is the <then> part of the expression
    $Template = $self->GetArgParse(2, @FunArgs);
    #-- have to have at least a <then> for IF, else is optional
    if (!$self->IsArg(2, @FunArgs)) {
      $Template = $self->GetFunctionError($Function);
    }
  } else {
    #-- Expression was false, so value is the <else> part of the expression
    $Template = $self->GetArgParse(3, @FunArgs);
  }
  # Make sure template exists
  if ($Template ne "") {
    # Get the template filename
    my $TempleFile = $self->SearchTemplateDirs( $Template );

    # See if we have arguments to the include: set as #_1_# #_2_# ...
    if ($self->IsArg(4, @FunArgs)) {
      # search through each Arg and set it as a parameter to INCLUDE
      for (my $I=4; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Set_Token('_'.($I-3).'_', $self->GetArgNoParse($I, @FunArgs));
      }
    }

    # Get the template if it exists
    if (-e $TempleFile) {
      # Get the file contents and done
      $V = $U->GetFile($TempleFile, 1);
      # Strip out the developer comments <!--- ---> before returning
      # Only show comments if we're flushing and ShowComments are on,
      # otherwise it could be a return value in token assign
      my $bRawComments = ($self->{_bShowComments} && $bFlush)?1:0;
      $V = $self->StripComments($V, $bRawComments);
      # Parse the results
      $V = $self->Parse($V, $bFlush);
    } else {
      $V = "IFINCLUDE: Template not found [$Template]";
    }
    # Unset the #_x_# parameter tokens after call is done
    if ($self->IsArg(2, @FunArgs)) {
      for (my $I=2; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Delete_Token('_'.($I-1).'_');
      }
    }
    # Add Token Statistic for INCLUDE
    $self->AddStat("_Function Call: INCLUDE") if ($self->GetLogStat());
  }

  # See if the BEFORE AFTER SHOWON needs to stop
  if ($Stop) {
    #-- Expression was true, so Halt execution of the current page
    $V = '!!HALT_EXECUTION!!'.$V;
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlIFINCLUDE


#-----------------------------------------------------------------------------
#-- omlSTOP function - Halt execution of the current page - #STOP[<expression>]#
#--
sub Orbit::omlSTOP
{
  my ($self) = @_;

  #-- Get the expression argument
  my $expr = $self->GetArguments();

  # See if expression is TRUE
  if ($self->Eval($expr)) {
    #-- Expression was true, so Halt execution of the current page
    return '!!HALT_EXECUTION!!';
  }

  return "";
} #omlSTOP


#-----------------------------------------------------------------------------
#-- omlMSG function - #MSG[<code>][<message_text>][<message_help>][<comment_text>]#
#-- Alias:   MSGLIST   MSGHELP   MESSAGE
#--
#MSG           [MessageCode].[MessageText].[HelpText].[CommentText]# - Returns the translated message text for the MessageCode specified, optionally setting the MessageText, Help, and Comment Text.
#MSGLIST       [MessageCode].[MessageList].[HelpText].[CommentText]# - MessageList is a separated list (\n|;:) of items, (i.e. a list of weekdays for a Select list).  Returns the translated message text for the MessageCode specified in the default Language.  Optionally set the Help and Comment Text.
#MSGHELP       [MessageCode].[HelpText]# - Returns the help text for a message code
#--
sub Orbit::omlMSG
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = $self->GetArgParse(1, @FunArgs);  #-- Message Code
  if ($a1 ne "") {
    $V     = $self->GetArgNoParse(2, @FunArgs);  #-- Message Text
    my $a2 = $self->GetArgNoParse(3, @FunArgs);  #-- Help Text
    my $a3 = $self->GetArgNoParse(4, @FunArgs);  #-- Comment Text
    #-- Get the message text for the code specified
    #-- and the user or country default language
    $V = $self->GetMessageText( $a1, $V, $a2, $a3 );
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlMSG


#-----------------------------------------------------------------------------
#-- omlLANGUAGE function - #LANGUAGE[<LangCode>].[MessageCode]...[MessageCode]#
#-- - Change the Language to the LangCode specified and set Tokens for the optional MessageCode(s), translated, with MSG_ prefix (i.e. #MSG_SEARCH#).
#-- Alias: LANG SETLANG
#--
sub Orbit::omlLANGUAGE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get the language code
  my $LangCode = $self->GetArgParse(1, @FunArgs);
  # Set the Language (sets in Orbit and Akashic
  if ($LangCode ne "") {
    $self->SetLanguage($LangCode);
    
    # Loop through each of the MessageCodes (FunArg 2+), and register as MSG_<MessageCode>
    my $MSGCodeOrig = "";
    my $MSGCode = "";
    for (my $i=2; $i<=@FunArgs; $i++) {
      $MSGCodeOrig = $self->GetArgParse($i, @FunArgs);      # MessageCode
      $MSGCode = $self->StandardizeMSGCode($MSGCodeOrig);   # Standardize MSGCode
      $MSGCode =~ s/ /_/g;   # Change space to _ to make a valid token
      # Get the MessageText for the code specified
      # and set to MSG_<MSGCode> Token
      $self->Set_Token('MSG_'.$MSGCode, $self->GetMessageText( $MSGCodeOrig ));
    } #for
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return "";   # Returns nothing
} #omlLANGUAGE


#-----------------------------------------------------------------------------
#-- omlIF function - #IF[<expression>][<then>][<else>]#
#--
sub Orbit::omlIF
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  #-- Get the expression argument
  my $a1 = $self->GetArgNoParse(1, @FunArgs);
  #
  if ($self->Eval($a1)) {
    #-- Expression was true, so value is the <then> part of the expression
    $V = $self->GetArgParse(2, @FunArgs);
    #-- have to have at least a <then> for IF, else is optional
    if (!$self->IsArg(2, @FunArgs)) {
      $V = $self->GetFunctionError('IF');
    }
  } else {
    #-- Expression was false, so value is the <else> part of the expression
    $V = $self->GetArgParse(3, @FunArgs);
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlIF


#-----------------------------------------------------------------------------
#-- omlEQUAL function - #EQUAL[val1][val2][then][else]#
#--
sub Orbit::omlEQUAL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    if ($self->IsArg(3, @FunArgs)) { #--then
      #-- See if the <val1> equals <val2>
      if ($V eq $a1
         || ($V eq "" && $a1 eq "")) {
        #-- Expression was true, so value is the <then> part of the expression
        $V = $self->GetArgParse(3, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $V = $self->GetArgParse(4, @FunArgs);
      }
    } else {   #-- no) {/else specified - use standard functionality
      if ($V eq $a1
         || ($V eq "" && $a1 eq "")) {
        $V = '1';
      } else {
        $V = '0';
      }
    }
  } else {
    $V = $self->GetFunctionError('EQUAL');
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlEQUAL


#-----------------------------------------------------------------------------
#-- omlNOTEQUAL function - #NOTEQUAL[val1][val2][then][else]#
#--
sub Orbit::omlNOTEQUAL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    if ($self->IsArg(3, @FunArgs)) {   #--then
      #-- See if the <val1> NOT equals <val2>
      if ($V eq $a1
         || ($V eq "" && $a1 eq "")) {
        #-- Expression was true, so value is the <else> part of the expression
        $V = $self->GetArgParse(4, @FunArgs);
      } else {
        #-- Expression was false, so value is the <then> part of the expression
        $V = $self->GetArgParse(3, @FunArgs); #--then
      }
    } else {   #-- no) {/else specified - use standard functionality
      if ($V eq $a1
         || ($V eq "" && $a1 eq "")) {
        $V = '0';
      } else {
        $V = '1';
      }
    }
  } else {
    $V = $self->GetFunctionError('NOTEQUAL');
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlNOTEQUAL


#-----------------------------------------------------------------------------
#-- omlNVL function - #NVL[val1][val2]...[valn]#
#-- Returns the first non null (blank) argument
#--
sub Orbit::omlNVL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";

  # search through each Arg and if any is false, return 0
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $V = $self->GetArgParse($I, @FunArgs);

    # Check for empty argument (default: FALSE in AND function)
    last if ($V ne "");
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlNVL


#-----------------------------------------------------------------------------
#-- omlDECODE function
#-- - #DECODE[<text>][<if>][<then>][<if>][<then>]...[<else>]#
#-- - #DECODELIKE[<text>][<if>][<then>][<if>][<then>]...[<else>]#
#-- - #CASE[]#
#-- Aliases: CASE DECODELIKE
sub Orbit::omlDECODE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get Function name (certain functions, usually for aliases or overloads)
  my $Function = $self->{_Function};
  my $V = "";
  my $U = $self->{_Utils};
  use Core::Like;
  my $lb_like = 0;
  if ($Function eq 'DECODELIKE'
    ||$Function eq 'CASE'
    ) {
    $lb_like = 1;
  } else {
    $lb_like = 0;
  }
  #-- Get the base text ($V)
  my $a1 = $self->GetArgParse(1, @FunArgs);   #text
  my $a2 = $self->GetArgParse(2, @FunArgs);   #if
  my $argFound = $self->IsArg(2, @FunArgs);
  if ($argFound) {
    my $I = 4;
    while (1) {
      #-- leave if we have a not null or there are no more arguments or the argument count exceeds 500
      last if (!$argFound || $I > 5000);
      #-- See if the <text> equals the <if>
      if ($lb_like) {
        if (  $U->like($a1, $a2)
           || $U->like($a2, $a1)
           || ($a1 eq "" && $a2 eq "")
           ) {
          $V = $self->GetArgParse($I-1, @FunArgs);   #then
          last;
        }
      } else {
        if (  $a1 eq $a2
           || ($a1 eq "" and $a2 eq "")
           ) {
          $V = $self->GetArgParse($I-1, @FunArgs);   #then
          last;
        }
      }
      #-- Get the next argument - either an <if> or an <else>
      $a2 = $self->GetArgParse($I, @FunArgs);
      $argFound = $self->IsArg($I, @FunArgs);
      #-- leave if this was not found (no <else> specified
      last if (!$argFound);
      #-- Check for <else> clause
      if (!$self->IsArg($I+1, @FunArgs)) {
        #-- The prior get was the else, so just return it
        $V = $a2;
        last;
      }
      #-- increment the index
      $I = $I + 2;
    }
  } else {
    $V = $self->GetFunctionError($Function);
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDECODE


#-----------------------------------------------------------------------------
#-- omlEXISTS or ISNOTNULL or NOTNULL function - #EXISTS[<text>][then][else]#
#-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
#-- Aliases: ISNOTNULL NOTNULL
sub Orbit::omlEXISTS
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  #-- Get the next argument
  my $a1 = $self->GetArgParse(1, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) {
    if ($a1 ne "") {
      #-- Expression was true, so value is the <then> part of the expression
      $V = $self->GetArgParse(2, @FunArgs); #--then
    } else {
      #-- Expression was false, so value is the <else> part of the expression
      $V = $self->GetArgParse(3, @FunArgs);
    }
  } else {  #-- use standard functionality
    if ($a1 ne "") {
      $V = '1';
    } else {
      $V = '0';
    }
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlEXISTS


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Base;
#******************************************************************************************
1;


#END Orbit::OML:Function::Base Package
