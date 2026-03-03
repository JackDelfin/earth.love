#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Akashic::Stats
#*
#*  Description     :   This package contains utility functions and procedures for supporting Akashic for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Created in Akashic scope
#*****************************************************************************************
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
#*****************************************************************************************
#----------------------------------------#
# STATISTICS UTILITIES
#----------------------------------------#
#
# AddStat <Stat> [<Value>]
#   - Add the Statistic count to Stats Array, forcing value if specified
#
# AddStatUnique <Stat> <Value>
#   - Add the Unique Statistic / Value pair to Stats Array
#
# GetStat <Stat>
#   - Returns the statistic count for the Stat specified
#
# GetStatTotal
#   - Returns the total number of statistics added
#
# ShowStats
#   - Show the stored statistics
#
# SetShowStats <1/0>
#   - Turns on/off showing Log Statistics
#
# GetShowStats <1/0>
#   - Returns the ShowStats indicator (1/0)
#
# SetLogStats <1/0>
#   - Turns Log Statistics on/off
#
# GetLogStat
#   - Returns 1/0 if Statistics are being logged
#
#*****************************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';

#use Akashic::Print;

#******************************************************************************************/
# AddStat <Stat> <Value>
#
# - Add the Statistic count to Stats Array
# - Value forces the Value specified (no hacking counts now!)
#******************************************************************************************/
sub Akashic::AddStat {
  my ($self, $Stat, $Value) = @_;
  # Check for the LOG stats directive
  return if (!$self->{_bLogStats});
  return if (!defined($Stat) || $Stat eq "");
  $Value = "" if (!defined($Value));
  
  # Update the AddStat Stats Count - shows overhead
  $self->{_StatsCnt}++;

  #
  # Set the stat to the value if specified
  #
  if ($Value ne "") {
    $self->{_STATS}->{$Stat} = $Value;
    return 1;
  }
  
  #
  # Update the summary by stats in the HASH table
  if (!defined($self->{_STATS}->{$Stat})) {
    $self->{_STATS}->{$Stat} = 0;
  }
  $self->{_STATS}->{$Stat}++;
} #AddStat


#******************************************************************************************/
# AddStatUnique <Stat> <Value>
#
# - Add the Unique Statistic / Value pair to Stats Array
#******************************************************************************************/
sub Akashic::AddStatUnique {
  my ($self, $Stat, $Value) = @_;
  # Check for the LOG stats directive
  return if (!$self->{_bLogStats});
  return if (!defined($Stat) || $Stat eq "");
  $Value = "" if (!defined($Value));
  
  # Update the Stats Count
  $self->{_StatsCnt}++;

  #
  # Set the stat to the value if specified
  #
  if ($Value ne "") {
    $self->{_STATS}->{$Stat.$Value} = ' ';
    return 1;
  }
  
  #
  # Update the summary by statsin the HASH table
  #
  if (!defined($self->{_STATS}->{$Stat})) {
    $self->{_STATS}->{$Stat} = 0;
  }
  $self->{_STATS}->{$Stat}++;
} #AddStatUnique


#******************************************************************************************/
# GetStat <Stat>
#
# - Returns the statistic count for the Stat specified
#******************************************************************************************/
sub Akashic::GetStat
{
  my ($self, $Stat) = @_;
  # Check for the SHOW stats directive
  return "" if (!defined($Stat) || $Stat eq "");
  return "" if (!defined($self->{_STATS}->{$Stat}));
  return $self->{_STATS}->{$Stat};
} #GetStat


#******************************************************************************************/
# GetStatTotal
#
# - Returns the total number of statistics added
#******************************************************************************************/
sub Akashic::GetStatTotal
{
  my ($self) = @_;
  # Check for the SHOW stats directive
  return $self->{_StatsCnt};
} #GetStatTotal


#******************************************************************************************/
# ShowStats <header> <ShowHeaderCount> <bHTML>
#
# - Show the stored statistics
#******************************************************************************************/
sub Akashic::ShowStats
{
  my ($self, $header, $bShowHeaderCount, $bHTML) = @_;
  # Check for the SHOW stats directive
  return if (!$self->{_bShowStats});

  $header = "Statistics" if (!defined($header) || $header eq "");
  $bShowHeaderCount = 0 if (!defined($bShowHeaderCount) || $bShowHeaderCount ne '1');
  $bHTML = 0 if (!defined($bHTML) || $bHTML ne '1');

  # Only show if data present
  if ($self->{_StatsCnt} > 0) {
    if (!$bHTML) {
      $self->Uprint("\n-----------------------\n");
    } else {
      $self->Uprint("<table>\n");
    }
    if ($bShowHeaderCount) {
      if (!$bHTML) {
        $self->Uprint($header.": ".$self->{_StatsCnt}."\n");
      } else {
        $self->Uprint("<tr><th>$header</th><th>".$self->{_StatsCnt}."</th></tr>\n");
      }
    } else {
      if (!$bHTML) {
        $self->Uprint($header.":\n");
      } else {
        $self->Uprint("<tr><th colspan=2>$header</th></tr>\n");
      }
    }
    $self->Uprint("-----------------------\n") if (!$bHTML);
    # Print out and delete the Catalog/Category summary
    foreach my $stat (sort(keys %{$self->{_STATS}}))
    {
      if (!$bHTML) {
        if ($self->{_STATS}->{$stat} eq ' ') {
          $self->Uprint($stat."\n");
        } else {
          $self->Uprint($stat.": ".$self->{_STATS}->{$stat}."\n");
        }
      } else {
        $self->Uprint("<tr><td align=left>$stat</td><td align=right>".$self->{_STATS}->{$stat}."</td></tr>\n");
      }
      # Take away from stats count as we're printing
      if ($self->IsNumber($self->{_STATS}->{$stat})) {
        $self->{_StatsCnt} = $self->{_StatsCnt} - $self->{_STATS}->{$stat};
      } else {
        # Else just take away 1 for the existence
        $self->{_StatsCnt}--;
      }
      delete($self->{_STATS}->{$stat});
    }
    $self->Uprint("</table>\n") if ($bHTML);
  }
} #ShowStats


#******************************************************************************************/
# SetShowStats <1/0>
#
# - Turns on/off showing Log Statistics
#******************************************************************************************/
sub Akashic::SetShowStats {
  my ($self, $switch) = @_;
  $switch = 0 if (!defined($switch) || $switch ne '1');
  $self->{_bShowStats} = $switch;
} #SetShowStats


#******************************************************************************************/
# GetShowStats <1/0>
#
# - Returns the ShowStats indicator (1/0)
#******************************************************************************************/
sub Akashic::GetShowStats {
  my ($self) = @_;
  return $self->{_bShowStats};
} #GetShowStats


#******************************************************************************************/
# SetLogStats <1/0>
#
# - Turns Log Statistics on/off
#******************************************************************************************/
sub Akashic::SetLogStats {
  my ($self, $switch) = @_;
  $switch = 0 if (!defined($switch) || length($switch)!= 1 || $switch lt '1' && $switch gt '9');
  $self->{_bLogStats} = $switch;
} #SetLogStats


#******************************************************************************************/
# GetLogStat
#
# - Returns 1/0 if Statistics are being logged
#******************************************************************************************/
sub Akashic::GetLogStat {
  my ($self) = @_;
  return $self->{_bLogStats};
} #GetLogStat


#******************************************************************************************
# Return true to show package was loaded with
# use Akashic::Stats;
#******************************************************************************************
1;

#END Akashic::Stats
