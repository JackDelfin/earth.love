#!/usr/bin/perl
# Version 1.0.1.0      09-Jun-2021
#*******************************************************************************
#
# Orbit::Config.pm
#
# Orbit Configuration Functions - Get / Set for internal package variables
#
#*******************************************************************************
# History:
#   2021.06.23 earth.love oK Created
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
# BUFFER SET/GET
#----------------------------------------#
#
# SetOutput <Buffer>
#   - Sets the _Output buffer
#
# GetOutput
#   - Returns the contents of the _Output buffer
#
#----------------------------------------#
# SET/GET PARAMETER FUNCTIONS
# - USUALLY GO WITH BATCH PROCESSING
#----------------------------------------#
#
# SetBatchMode <1/0>
#   - Set the _bBatchMode flag to indicate a batch process is running
#   - This disables SHOWSTATS and LOGSTATS OML Functions within pages
#   - The token _STATIC_ is set to 1 so you can use
#     the #DOTDOT# Token to get the relative path to the Domain Root.
#
# GetBatchMode
#   - Returns the _bBatchMode flag to indicate if running in batch mode
#
# SetDebugOn
#   - Set the Debug mode ON at the specified debug level (max 20 = most detailed)
#
# SetDebugOff
#   - Set the Debug mode OFF
#
# GetDebug
#   - Returns the Debug mode (1/0)
#
# SetCommandLineOn
#   - Set the Output type to Command Line for debugging - don't show HTTP header
#
# SetCommandLineOff
#   - Set the Command Line Off - show HTTP header
#
# GetCommandLine
#   - Returns the Command Line mode (1/0)
#
# SetShowCommentsOn
#   - Set the Show OML Comments control ON
#
# SetShowCommentsOff
#   - Set the Show OML Comments control OFF
#
# GetShowComments
#   - Returns the Show OML Comments mode (1/0)
#
# SetPrintOutputOn
#   - Set the Output On for normal operation
#
# SetPrintOutputOff
#   - Set the Output Off for Show_Page - Show_Page will exit without displaying anything
#   - useful for buffering output in _Output
#
# GetPrintOutput
#   - Returns the PrintOutput mode (1/0)
#
# SetCacheOutput
#   - Set the Cache Output On or Off for a page generation
#
# GetCacheOutput
#   - Returns the Cache Output mode (1/0)
#
#----------------------------------------#
# AKASHIC INTERFACE
#----------------------------------------#
#
# SetAkashic <Akashic->new() refrence>
#   - Sets the Akashic class within Orbit
#
# GetAkashic
#   - Gets the Akashic class within Orbit
#
# SetDomain <Domain> <DomainDir>
#   - Set the _Domain and _DomainDir internal variables
#
# GetDomain
#   - Get the _Domain value. Reference in OML in batchmode with ENV_DOMAIN token
#
# GetDomainDir
#   - Get the _DomainDir value. Reference in OML in batchmode with ENV_DOMAINDIR token
#
# SetRoot <Root> <RootDir>
#   - Set the _Root and _RootDir internal variables
#
# GetRoot
#   - Get the _Root value
#
# GetRootDir
#   - Get the _RootDir value
#
#*******************************************************************************
package Orbit;
use strict;
use warnings;


#******************************************************************************************/
#                                    BUFFER SET/GET
#******************************************************************************************/


#******************************************************************************************
# SetOutput <Buffer>
#   - Sets the _Output buffer
#******************************************************************************************
sub Orbit::SetOutput
{
  my ( $self, $Buf ) = @_;
  $Buf = "" if (!defined($Buf));
  $self->{_Output} = $Buf;
} #SetOutput


#******************************************************************************************
# GetOutput
#   - Returns the contents of the _Output buffer
#******************************************************************************************
sub Orbit::GetOutput
{
  my ( $self ) = @_;
  return $self->{_Output};
} #GetOutput


#******************************************************************************************/
#              SET/GET PARAMETER FUNCTIONS - USUALLY GO WITH BATCH PROCESSING
#******************************************************************************************/


#******************************************************************************************/
# SetBatchMode <1/0>
#   - Set the _bBatchMode flag to indicate a batch process is running
#   - This disables SHOWSTATS and LOGSTATS OML Functions within pages
#   - The token _STATIC_ is set to 1 so you can use
#     the #DOTDOT# Token to get the relative path to the Domain Root.
#******************************************************************************************/
sub Orbit::SetBatchMode {
  my ($self, $switch) = @_;
  $switch = 0 if (!defined($switch) || length($switch)!= 1 || $switch lt '1' && $switch gt '9');
  $self->{_bBatchMode} = $switch;
} #SetBatchMode


#******************************************************************************************/
# GetBatchMode
#   - Returns the _bBatchMode flag to indicate if running in batch mode
#******************************************************************************************/
sub Orbit::GetBatchMode {
  my ($self) = @_;
  return $self->{_bBatchMode};
} #GetBatchMode


#******************************************************************************************
# SetDebugOn
#   - Set the Debug mode ON at the specified debug level (max 20 = most detailed)
#******************************************************************************************
sub Orbit::SetDebugOn
{
  my ( $self, $DebugLevel ) = @_;
  $DebugLevel = 20 if (!defined($DebugLevel));
  $self->{_debug} = $DebugLevel;
  return 0;
} #SetDebugOn


#******************************************************************************************
# SetDebugOff
#   - Set the Debug mode OFF
#******************************************************************************************
sub Orbit::SetDebugOff
{
  my ( $self ) = @_;
  $self->{_debug} = 0;
  return 0;
} #SetDebugOff

#******************************************************************************************
# GetDebug
#   - Returns the Debug mode (1/0)
#******************************************************************************************
sub Orbit::GetDebug
{
  my ( $self ) = @_;
  return $self->{_debug};
} #GetDebug


#******************************************************************************************
# SetCommandLineOn
#   - Set the Output type to Command Line for debugging - don't show HTTP header
#******************************************************************************************
sub Orbit::SetCommandLineOn
{
  my ( $self ) = @_;
  $self->{_bCommandLine} = 1;
  return $self->{_bCommandLine};
} #SetCommandLineOn


#******************************************************************************************
# SetCommandLineOff
#   - Set the Command Line Off - show HTTP header
#******************************************************************************************
sub Orbit::SetCommandLineOff
{
  my ( $self ) = @_;
  $self->{_bCommandLine} = 0;
  return $self->{_bCommandLine};
} #SetCommandLineOff


#******************************************************************************************
# GetCommandLine
#   - Returns the Command Line mode (1/0)
#******************************************************************************************
sub Orbit::GetCommandLine
{
  my ( $self ) = @_;
  return $self->{_bCommandLine};
} #GetCommandLine


#******************************************************************************************
# SetShowCommentsOn
#   - Set the Show OML Comments control ON
#******************************************************************************************
sub Orbit::SetShowCommentsOn
{
  my ( $self ) = @_;
  $self->{_bShowComments} = 1;
  return $self->{_bShowComments};
} #SetShowCommentsOn


#******************************************************************************************
# SetShowCommentsOff
#   - Set the Show OML Comments control OFF
#******************************************************************************************
sub Orbit::SetShowCommentsOff
{
  my ( $self ) = @_;
  $self->{_bShowComments} = 0;
  return $self->{_bShowComments};
} #SetShowCommentsOff


#******************************************************************************************
# GetShowComments
#   - Returns the Show OML Comments mode (1/0)
#******************************************************************************************
sub Orbit::GetShowComments
{
  my ( $self ) = @_;
  return $self->{_bShowComments};
} #GetShowComments


#******************************************************************************************
# SetPrintOutputOn
#   - Set the Output On for normal operation
#******************************************************************************************
sub Orbit::SetPrintOutputOn
{
  my ( $self ) = @_;
  $self->{_bPrintOutput} = 1;
  return 0;
} #SetPrintOutputOn


#******************************************************************************************
# SetPrintOutputOff
#   - Set the Output Off for Show_Page - Show_Page will exit without displaying anything
#   - useful for buffering output in _Output
#******************************************************************************************
sub Orbit::SetPrintOutputOff
{
  my ( $self ) = @_;
  $self->{_bPrintOutput} = 0;
  return 0;
} #SetPrintOutputOff


#******************************************************************************************
# GetPrintOutput
#   - Returns the PrintOutput mode (1/0)
#******************************************************************************************
sub Orbit::GetPrintOutput
{
  my ( $self ) = @_;
  return $self->{_bPrintOutput};
} #GetPrintOutput


#******************************************************************************************
# SetCacheOutput
#   - Set the Cache Output On or Off for a page generation
#******************************************************************************************
sub Orbit::SetCacheOutput
{
  my ( $self, $bCacheMode ) = @_;
  $bCacheMode = 0 if (!defined($bCacheMode) || $bCacheMode ne '1');
  $self->{_bCacheOutput} = $bCacheMode;
  return 0;
} #SetCacheOutput


#******************************************************************************************
# GetCacheOutput
#   - Returns the Cache Output mode (1/0)
#******************************************************************************************
sub Orbit::GetCacheOutput
{
  my ( $self ) = @_;
  return $self->{_bCacheOutput};
} #GetCacheOutput


#******************************************************************************************/
#                                     AKASHIC INTERFACE
#******************************************************************************************/


#******************************************************************************************
# SetAkashic <Akashic->new() refrence>
#   - Sets the Akashic class within Orbit
#******************************************************************************************
sub Orbit::SetAkashic
{
  my ( $self, $A ) = @_;
  $self->{_Akashic} = $A;
} #SetAkashic


#******************************************************************************************
# GetAkashic
#   - Gets the Akashic class within Orbit
#******************************************************************************************
sub Orbit::GetAkashic
{
  my ( $self ) = @_;
  return $self->{_Akashic};
} #GetAkashic


#******************************************************************************************/
# SetDomain <Domain> <DomainDir>
#   - Set the _Domain and _DomainDir internal variables
#******************************************************************************************/
sub Orbit::SetDomain {
  my ($self, $Domain, $DomainDir) = @_;
  $self->{_Domain}    = $Domain;
  $self->{_DomainDir} = $DomainDir;
  
} #SetDomain


#******************************************************************************************/
# GetDomain
#   - Get the _Domain value. Reference in OML in batchmode with ENV_DOMAIN token
#******************************************************************************************/
sub Orbit::GetDomain {
  my ($self) = @_;
  return $self->{_Domain};
} #GetDomain


#******************************************************************************************/
# GetDomainDir
#   - Get the _DomainDir value. Reference in OML in batchmode with ENV_DOMAINDIR token
#******************************************************************************************/
sub Orbit::GetDomainDir {
  my ($self) = @_;
  return $self->{_DomainDir};
} #GetDomainDir


#******************************************************************************************/
# SetRoot <Root> <RootDir>
#   - Set the _Root and _RootDir internal variables
#******************************************************************************************/
sub Orbit::SetRoot {
  my ($self, $Root, $RootDir) = @_;
  $self->{_Root}    = $Root;
  $self->{_RootDir} = $RootDir;
} #SetRoot


#******************************************************************************************/
# GetRoot
#   - Get the _Root value
#******************************************************************************************/
sub Orbit::GetRoot {
  my ($self) = @_;
  return $self->{_Root};
} #GetRoot


#******************************************************************************************/
# GetRootDir
#   - Get the _RootDir value
#******************************************************************************************/
sub Orbit::GetRootDir {
  my ($self) = @_;
  return $self->{_RootDir};
} #GetRootDir


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Config;
#******************************************************************************************
1;

#END Orbit::Config;
