#!/usr/bin/perl
# Version 7.0.0.0      01-Jul-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::User
#*
#*  Description     :   Implements Utility Functions within Orbit
#*
#*****************************************************************************************
# History:
#   2021.06.16 earth.love oK Refactored
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
# Functions Supported
#*****************************************
#
# Logon
#   - Validates the user/password and creates a User Access Log (session) record
#
# Logoff
#   - Logs a user out of their session (sets a flag on the user access log)
#   - If next page is not specified, the LOGON_PAGE will be displayed
#
# Change_Password
#   - Change a users password based on session stored in a cookie
#
# LoadAccessGroups
#   - Loads all Access Groups for a user into tokens named SEC_<access_group_code>
#
# HasAccess $Root, $Object, $Page, $Action, $Word
#   - Returns 1 if the current user has access to the data specified
#   - Returns 0 if the user is specifically denied access, but not personally
#   - Returns 2 if the user has VIEW ONLY access to the page
#
# GetUser
#   - Returns the User name - Set Externally
#
# SetUser $User, $UserDir
#   - Sets the internal User and UserDir variables (called internally)
#
# GetUserDir
#   - Returns the User directory location - Set Externally
#
# SetUserDir $UserDir
#   - Sets the internal UserDir to that specified - Set Externally
#   - Used for access to ACCESS.dat and other user settings
#
# GetLanguage
#   - Returns the User Language value
#
# SetLanguage $Lang
#   - Sets the User Language value - affects the #MSG[]# call
#
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Orbit::Token;


#******************************************************************************************
#* Logon
#*
#* - Validates the user/password and creates a User Access Log (session) record
#******************************************************************************************
sub Orbit::Logon
{
  my ( $self ) = @_;

  return "CODE Logon";
} #Logon


#******************************************************************************************
#* Logoff
#*
#* - Logs a user out of their session (sets a flag on the user access log)
#* - If next page is not specified, the LOGON_PAGE will be displayed
#******************************************************************************************
sub Orbit::Logoff
{
  my ( $self ) = @_;

  return "CODE Logoff";
} #Logoff


#******************************************************************************************
#* Change_Password
#*
#* - Change a users password based on session stored in a cookie
#******************************************************************************************
sub Orbit::Change_Password
  #          old_password                   IN     VARCHAR2
  #         ,new_password                   IN     VARCHAR2
  #         ,verify_password                IN     VARCHAR2
  #         ,username                       IN     VARCHAR2  DEFAULT NULL
{
  my ( $self ) = @_;

  return "CODE Change_Password";
} #Change_Password


#******************************************************************************************
# LoadAccessGroups
#   - Loads all Access Groups for a user into tokens named SEC_<access_group_code>
#******************************************************************************************
sub Orbit::LoadAccessGroups
{
  my ( $self ) = @_;

  return "CODE";
} #LoadAccessGroups


#******************************************************************************************
# HasAccess $Root, $Object, $Page, $Action, $Word
#   - Returns 1 if the current user has access to the data specified
#   - Returns 0 if the user is specifically denied access, but not personally
#   - Returns 2 if the user has VIEW ONLY access to the page
#******************************************************************************************
sub Orbit::HasAccess
{
  my ( $self, $Root, $Object, $Page, $Action, $Word ) = @_;
  my $U = $self->{_Utils};

  # leave if user isn't defined
  return 0 if ($self->{_User} eq "");

  my $Access = "";

  # Check for buffered Access
  if ( $Root eq $self->{_Root}
    && $Object eq $self->{_Object}
    && $Page eq $self->{_Page}
    && $Action eq $self->{_Action}
    && $Word eq $self->{_Word}
    && $self->{_Access} ne ""
    ) {
    $Access = $self->{_Access};
  }

  #
  # Get User Access File: ACCESS.dat usually
  #
  #
  if ($self->{_Access} ne $Access) {
    my $AccessFile = $self->GetUserDir().$self->{_Data}->{'_ACCESS'};
    $Access = $U->GetFile($AccessFile);
  }

  $self->{_Access} = $Access;
  
  #
  # Check input parameters against access records
  #
  #######
  #######  CODE TO WRITE   #TESTING
  #######
  
  return 1;
} #HasAccess


#******************************************************************************************
# GetUser
#   - Returns the User name - Set Externally
#******************************************************************************************
sub Orbit::GetUser
{
  my ( $self ) = @_;
  return $self->{_User};
} #GetUser


#******************************************************************************************
# SetUser $User, $UserDir
#   - Sets the internal User and UserDir variables (called internally)
#******************************************************************************************
sub Orbit::SetUser
{
  my ( $self, $User, $UserDir ) = @_;

  $User    = ""                       if (!defined($User));
  # Default User Directory to _UserDirDefault if not specified (ie ./_ORBIT/USERS/#user#/ACCESS.dat)
  $UserDir = $self->{_UserDirDefault} if (!defined($UserDir) || $UserDir eq "" || $UserDir eq '.');

  # Make sure User exists
  if ($User eq "") {
    $self->Uprint("SetUser: Error: No User. User Directory: [$UserDir]\n");
    return 1;
  }

  # Make sure User exists
  if (!-d $UserDir) {
    $self->Uprint("SetUser: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset User and UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_User} = $User;
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUser


#******************************************************************************************
# GetUserDir
#   - Returns the User directory location - Set Externally
#******************************************************************************************
sub Orbit::GetUserDir
{
  my ( $self ) = @_;
  return $self->{_UserDir};
} #GetUserDir


#******************************************************************************************
# SetUserDir $UserDir
#   - Sets the internal UserDir to that specified - Set Externally
#   - Used for access to ACCESS.dat and other user settings
#******************************************************************************************
sub Orbit::SetUserDir
{
  my ( $self, $UserDir ) = @_;
  
  # Make sure UserDir exists
  if (!-d $UserDir) {
    $self->Uprint("SetUserDir: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUserDir


#******************************************************************************************
# GetLanguage
#   - Returns the User Language value
#******************************************************************************************
sub GetLanguage {
  my ( $self ) = @_;
  return $self->{_Lang};
} #GetLanguage


#******************************************************************************************
# SetLanguage $Lang
#   - Sets the User Language value - affects the #MSG[]# call
#******************************************************************************************
sub SetLanguage {
  my ( $self, $Lang ) = @_;
  $Lang =~ tr/[a-z]/[A-Z]/;   # Uppercase Language by convention since it's a subROOT
  $self->{_Lang} = $Lang;
  $self->{_Akashic}->SetVar('Lang', $Lang);   # Set the Akashic Lang since we're connected
  $self->Set_Token('LANG', $Lang);
} #SetLanguage


#========================================================================================
# END USER FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::User;
#******************************************************************************************
1;


#END Orbit::User Package
