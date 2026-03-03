#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Crypt
#*
#*  Description     :   This package contains utility functions and procedures for supporting Orbit for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Refactored package for performance
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
#----------------------------------------#
# CRYTOGRAPHY UTILITIES
#----------------------------------------#
#
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#*
#* Encrypt <string> <crypt_mask>
#*
#* - Return an encrypted string based on an input mask (defaults internally)
#*   Warning: This returns a string with potentially unprintable characters (non A-Za-z0-9)
#******************************************************************************************/
#sub CoreUtils::Encrypt
  # fv_string VARCHAR2
  #,fv_crypt_mask VARCHAR2 DEFAULT NULL)
  #RETURN VARCHAR2;
#{
#  my ( $self, $fv_string, $fv_crypt_mask ) = @_;
#
#  return "CODE";
#} #Encrypt


#******************************************************************************************
#*
#* Decrypt <string> <crypt_mask>
#*
#* - Return an decrypted string based on an input mask (defaults internally)
#******************************************************************************************/
#sub CoreUtils::Decrypt
  # fv_string VARCHAR2
  # fv_crypt_mask VARCHAR2 DEFAULT NULL)
  #RETURN VARCHAR2;
#{
#  my ( $self, $fv_string, $fv_crypt_mask ) = @_;
#
#  return "CODE";
#} #Decrypt


#******************************************************************************************
#*
#* Hash <string>
#*
#* - Return a hashed integer for a string which is most likely unique
#******************************************************************************************/
#sub CoreUtils::Hash
#{
#  my ( $self, $fv_string ) = @_;
#
#  return "CODE";
#} #Hash


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Crypt;
#******************************************************************************************
1;

#END Core::Crypt
