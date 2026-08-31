#!/usr/bin/perl
# Version 1.0.1.0      30-June-2021
#******************************************************************************************
#*
#*  PROPOGATE_earthlove.pl [<libpath> / . / "" / cgi] [<StripPerlComments 1/0> def:0]
#*
#*  Copies the Orbit, Core, and Akashic files in the current directory to:
#*    - Apache CGI-BIN
#*    - Perl Library path (or specified on command line)
#*
#*    <libpath> - Specifies the library path for Perl packages (used in cgi-bin headers)
#*              - Also the lib destination path for the Orbit/Core/Akashic package install
#*              - Files are not copied to . or ./lib or ../lib
#*              - cgi - uses cgi-bin/lib (creates if necessary)
#*
#*    <StripPerlComments> - 1 = Remove all Perl comments from files being copied to cgi-bin and lib
#*                          0 = Keep comments in place
#*
#* Example: (use standard unix Perl Library, Strip comments from Perl files.\n";
#*   ./PROPOGATE_CTIBIN.pl /usr/lib/perl 1\n\n";
#-------------------------------------------------------------------------------
# History:
#   2021.06.29 earth.love oK Refactored
#   2021.06.09 earth.love oK Created
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
use strict;
use warnings;
use utf8;
use feature ':5.16';
use File::Copy;
use Cwd;

#*****************************************
# BEGIN USER CONFIGURATION
#*****************************************
#
# Release lib Directories
#
# Make the Akashic lib directories
# Make the Core lib directories
# Make the Orbit lib directories
#
my @DIRS = qw {
    Akashic
    Akashic/Write
    Core
    Core/Math
    Core/Local
    Orbit
    Orbit/Auth
    Orbit/Akashic
    Orbit/Utils
    Orbit/OML
    Orbit/OML/Function
    Orbit/Orbit6
    Orbit/Orbit6/Akashic
    Orbit/Orbit6/Utils
    Orbit/Orbit6/OML6
};
#
# Release Programs
#
my @REL = qw {
    Akashic.pm
    Akashic/Words.pm
    Akashic/Core.pm
    Akashic/Data.pm
    Akashic/Utils.pm
    Akashic/Earth.pm
    Akashic/Write.pm
    Akashic/Write/Catalog.pm
    Akashic/Write/Data.pm
    Akashic/Stats.pm
    Akashic/Print.pm
    Akashic/Process.pm
    Akashic/Timestamp.pm
    Akashic/myConfig.pm
    Core/Utils.pm
    Core/Crypt.pm
    Core/Dates.pm
    Core/Distance.pm
    Core/Fibonacci.pm
    Core/File.pm
    Core/HTML.pm
    Core/Like.pm
    Core/Math.pm
    Core/Math/Ceil.pm
    Core/Math/Least.pm
    Core/Math/Round.pm
    Core/Numbers.pm
    Core/Replace.pm
    Core/Search.pm
    Core/Strings.pm
    Core/Timestamp.pm
    Core/Tools.pm
    Core/Local/Stats.pm
    Core/Local/Print.pm
    Orbit.pm
    Orbit/Orbit7.pm
    Orbit/Core.pm
    Orbit/Stats.pm
    Orbit/Print.pm
    Orbit/Token.pm
    Orbit/Tokens.pm
    Orbit/User.pm
    Orbit/Auth.pm
    Orbit/Profile.pm
    Orbit/Person.pm
    Orbit/Utils.pm
    Orbit/Utils/Message.pm
    Orbit/Utils/Wrap.pm
    Orbit/Config.pm
    Orbit/myConfig.pm
    Orbit/Akashic.pm
    Orbit/Akashic/New.pm
    Orbit/Akashic/Add.pm
    Orbit/Akashic/Edit.pm
    Orbit/Akashic/Del.pm
    Orbit/Akashic/Process.pm
    Orbit/OML/Parse.pm
    Orbit/OML/Function7.pm
    Orbit/OML/TokenMods.pm
    Orbit/OML/Function/Base.pm
    Orbit/OML/Function/Conditional.pm
    Orbit/OML/Function/Numeric.pm
    Orbit/OML/Function/String.pm
    Orbit/OML/Function/Wrap.pm
    Orbit/OML/Function/Math.pm
    Orbit/OML/Function/Date.pm
    Orbit/OML/Function/HTML.pm
    Orbit/OML/Function/Data.pm
    Orbit/OML/Function/DataPlus.pm
    Orbit/OML/Function/Looping.pm
    Orbit/OML/Function/Internal.pm
    Orbit/OML/Function/Distance.pm
    Orbit/OML/Function/SysAdmin.pm
    Orbit/OML/Function/Web.pm
    Orbit/OML/Function/UserMod21.pm
    Orbit/OML/Function/UserMod22.pm
    Orbit/OML/Function/UserMod23.pm
    Orbit/OML/Function/UserMod24.pm
    Orbit/OML/Function/UserMod25.pm
    Orbit/OML/Function/UserMod26.pm
    Orbit/OML/Function/UserMod27.pm
    Orbit/Orbit6/Orbit6.pm
    Orbit/Orbit6/Core.pm
    Orbit/Orbit6/Stats.pm
    Orbit/Orbit6/Print.pm
    Orbit/Orbit6/Token.pm
    Orbit/Orbit6/Utils.pm
    Orbit/Orbit6/Utils/Wrap.pm
    Orbit/Orbit6/Config.pm
    Orbit/Orbit6/myConfig.pm
    Orbit/Orbit6/Akashic.pm
    Orbit/Orbit6/Akashic/New.pm
    Orbit/Orbit6/Akashic/Add.pm
    Orbit/Orbit6/Akashic/Edit.pm
    Orbit/Orbit6/Akashic/Del.pm
    Orbit/Orbit6/Akashic/Process.pm
    Orbit/Orbit6/OML6/Parse6.pm
    Orbit/Orbit6/OML6/Function6.pm
    Orbit/Orbit6/OML6/Token6.pm
};
#
# CGI Release Programs - copy from source bin/cgi to cgi-bin
#
my @CGISOURCE = qw {
    showpage.pl
    showpage7.pl
    page.pl
    page7.pl
    o.pl
    o7.pl
    elshow.pl
    eladd.pl
    elnew.pl
    eledit.pl
    eldel.pl
    elshow7.pl
    eladd7.pl
    elnew7.pl
    eledit7.pl
    eldel7.pl
    ellogon.pl
    elsignup.pl
    ellogoff.pl
    elpasswd.pl
    elprofile.pl
    elsettings.pl
    eladmin.pl
};
#
# Retired CGI programs - remove both the .pl file and the extensionless alias
# from existing deployments. Orbit 6 has no authentication/authorization or
# untrusted-token boundary, so all of its public routes are retired.
#
my @CGIRETIRED = qw {
    showpage6.pl
    page6.pl
    o6.pl
    elshow6.pl
    eladd6.pl
    elnew6.pl
    eledit6.pl
    eldel6.pl
};
#*****************************************
# END USER CONFIGURATION
#*****************************************


#*****************************************
#
# Program starts... now()
#

#
# Defaults for Apache cgi-bin and Perl executables
# - this can be hacked in ValidatePlatform
#
my $DestPath = "";
$DestPath = "/usr/lib/cgi-bin" if (-d "/usr/lib/cgi-bin");   # cgi-bin Destination
$DestPath = "/var/www/cgi-bin" if (-d "/var/www/cgi-bin");   # cgi-bin Destination

my $perl     = "/usr/bin/perl";      # Perl executable
#my $libPath  = "/usr/lib/perl";      # Package Library path
my $libPath  = "/usr/local/share/perl5";      # Package Library path

#
# Check and Set Platform Specific Settings
# - $DestPath Destination Path (cgi-bin)
# - $perl     Executable for cgi-bin headers
# - $libPath  Destination package library
#
ValidatePlatform();

#
# Get input parameters
#
my $USERlibPath = shift;
my $bStripPerlComments = shift;
# Use user specified libPath from command line, if specified
# NOTE: This is an override from ValidatePlatform
$USERlibPath = "" if (!defined($USERlibPath));
$bStripPerlComments = 0 if (!defined($bStripPerlComments) || $bStripPerlComments ne '1');
my $COPYLIB = 1;

# Use Current Working Directory for libpath if "." or "./lib" is specified
if ($USERlibPath eq '../lib') {
  $USERlibPath = cwd().'/../lib' ;
  $COPYLIB = 0;
} elsif ($USERlibPath eq './lib') {
  $USERlibPath = cwd().'/lib';
  $COPYLIB = 0;
} elsif ($USERlibPath eq '.') {
  $USERlibPath = cwd().'/lib';
  $COPYLIB = 0;
} elsif ($USERlibPath eq 'cgi') {
  $USERlibPath = $DestPath.'/lib';
  $COPYLIB = 1;
  if (!-d $USERlibPath) {
    mkdir $USERlibPath
      or die ("Error creating User Defined Library path: $USERlibPath\n");
  }
  $libPath = $USERlibPath;
} elsif ($USERlibPath ne "") {
  # attempt a mkdir if doesn't exist
  if (!-d $USERlibPath) {
    mkdir $USERlibPath
      or die ("Error creating User Defined Library path: $USERlibPath\n");
  }
  $libPath = $USERlibPath;
}
$USERlibPath =~ s/\/$//;   # Remove trailing / if present

#
# Make sure libpath exists
#
if ($libPath ne "" && !-d $libPath) {
  print "\nError: Library Path does not exist [$libPath]\n";
  PropogateUsage();
  exit 0;
}

print "******************************************\n";
print " Propogating Akashic / Core / Orbit to:\n";
print "   cgi-bin : [$DestPath]\n";
print "   Perl    : [$perl]\n";
print "   lib     : [$libPath]\n";
print "   USER lib: [$USERlibPath]\n" if ($USERlibPath ne '');
print "******************************************\n";

# Leave if Apache CGI path or Perl don't exist
if ($DestPath eq "" || $perl eq "" || $libPath eq "") {
  print "Error: Apache cgi-bin Path not found [$DestPath]!\n"      if ($DestPath eq "");
  print "Error: Perl not found [$perl]!\n"                         if ($perl eq "");
  print "Error: Perl package library path not found [$libPath]!\n" if ($libPath eq "");
  PropogateUsage();
  exit 0;
}

#
#  Here it is...
#
CopyRelease( $DestPath, $perl, $libPath, $USERlibPath, $COPYLIB, $bStripPerlComments );

exit 0;


#*****************************************
# CopyRelease
#
#   - Create the Release Directories
#   - Copy the source contents to the DestPath
#   - Change the Perl Path and Library Path
#     in the headers of the cgi-bin programs
#   - Optionally Strip Perl Comments from files
#*****************************************
sub CopyRelease
{
  my ( $DestPath, $perl, $libPath, $USERlibPath, $COPYLIB, $bStripPerlComments ) = @_;

  # Leave if Destpath is not found
  if (!-d $DestPath) {
    print "Destination Path: [$DestPath] not found!\n";
    exit 1;
  }
  
  # Leave if libPath is not found
  if (!-d $libPath) {
    print "Perl Package Library Path: [$libPath] not found!\n";
    exit 1;
  }

  # Leave if USERlibPath is not found
  if ($USERlibPath ne "" && !-d $USERlibPath) {
    print "User Specified Library Path: [$USERlibPath] not found!\n";
    exit 1;
  }

  # Remove retired CGI programs from previous deployments before publishing
  # the current release. AddHeaderAlias creates the extensionless variants.
  RemoveRetiredCGIs($DestPath);
  RemoveRetiredCGIs($USERlibPath.'/OrbitCGI')
    if ($USERlibPath ne "" && -d $USERlibPath.'/OrbitCGI');

  #
  # See if we're copying the library files or keeping them in place
  #
  if ($COPYLIB) {
  
    #
    # Loop through the Release lib Directories and CREATE
    #
    print "\n------------------------------------------\n";
    print "CREATING lib directories in:\n  ".$libPath."\n";
    print "------------------------------------------\n";
    foreach my $dream (@DIRS) {
      $dream = $libPath.'/'.$dream;
      # CREATE if dream doesn't exist
      if (!-d $dream) {
        print "  CREATE: ".$dream."\n";
        mkdir $dream
          or die ("mkdir Error: [$dream]\n");
      }
    } #@DIRS
    
    #
    # Loop through each Release filename
    #
    my $cnt = @REL + @CGISOURCE;
    print "\n------------------------------------------\n";
    print "Copying $cnt files...\n";
    print "------------------------------------------\n";
    foreach my $file (@REL) {
      print "  ".$libPath.'/'.$file."\n";
      # Copy the file to libPath (lib is under current directory with source)
      copy('lib/'.$file, $libPath.'/'.$file)
        or die ("Copy Error: $file   $libPath\n");
    } #@REL

    #
    # If user specified library path, 
    #
    if ($USERlibPath ne "") {
      # Make a USER OrbitCGI directory to hold customized programs
      mkdir $USERlibPath.'/OrbitCGI';
      foreach my $file (@CGISOURCE) {
        print "  ".$USERlibPath.'/OrbitCGI/'.$file."\n";
        # Copy the file
        copy('cgi/'.$file, $USERlibPath.'/OrbitCGI/'.$file)
          or die ("Copy Error: $file   ".$USERlibPath.'/OrbitCGI/'."\n");
      } #@CGISOURCE
    }
    
  } #if COPYLIB
  
  #
  # Copy the CGI source to cgibin.
  #
  print "\n------------------------------------------\n";
  print "Copying CGI-BIN files to:\n  ".$DestPath."\n";
  print "------------------------------------------\n";
  foreach my $file (@CGISOURCE) {
    print "  ".$DestPath.'/'.$file."\n";
    # Copy the file
    copy('cgi/'.$file, $DestPath.'/'.$file)
      or die ("Copy Error: $file   $DestPath\n");
  } #@CGISOURCE

  # strip out comments for performance
  if ($bStripPerlComments) {
    print "\n------------------------------------------\n";
    print "Removing Perl Comments:\n";
    print "------------------------------------------\n";

    #
    # Loop through each Release file and CGI file
    #
    if ($COPYLIB) {
      foreach my $file (@REL) {
        # Strip the Perl Comments
        StripPerlComments($libPath.'/'.$file);
      } #@REL
    }
    # Loop through the CGISOURCE programs
    foreach my $file (@CGISOURCE) {
      # Strip the Perl Comments
      StripPerlComments($DestPath.'/'.$file);
      # Update USERlibPath if specified
      StripPerlComments($USERlibPath.'/OrbitCGI/'.$file) if (-d $USERlibPath.'/OrbitCGI' && $COPYLIB);
    } #@CGISOURCE
    print "\n";
  }

  # Add the header to the top of showpage and el*.pl
  if ($perl ne "") {

    # Set libpath to cgilib if not defined
    $libPath = $USERlibPath if ($USERlibPath ne "");

    # Add Library Clause
    if ($libPath ne "") {
      print "\n------------------------------------------\n";
      print "Adding the following library to headers:\n";
      print "------------------------------------------\n";
      print "use lib '$libPath';\n";
      print "------------------------------------------\n";
    }

    #
    # Loop through each CGISOURCE filename
    #
    foreach my $file (@CGISOURCE) {
      # Fix the library in the header; create the alias
      AddHeaderAlias($DestPath.'/'.$file, $perl, $libPath);
      # Update USERlibPath if specified
      AddHeaderAlias($USERlibPath.'/OrbitCGI/'.$file, $perl, $libPath) if (-d $USERlibPath.'/OrbitCGI' && $COPYLIB);
    } #@CGISOURCE
  } #if $perl

  InstallAdminTool() if ($COPYLIB);
} #CopyRelease


##########################################
# RemoveRetiredCGIs <directory>
# - Remove exact, explicitly retired CGI filenames and generated aliases
##########################################
sub RemoveRetiredCGIs
{
  my ( $directory ) = @_;

  return if (!defined($directory) || $directory eq '' || !-d $directory);

  foreach my $file (@CGIRETIRED) {
    my $alias = $file;
    $alias =~ s/\.pl$//;

    foreach my $name ($file, $alias) {
      my $path = $directory.'/'.$name;
      next if (!-e $path && !-l $path);
      print "  RETIRE: $path\n";
      unlink($path) or die("Unable to retire CGI: $path\n");
    }
  }
} #RemoveRetiredCGIs


##########################################
# InstallAdminTool
# - Install the account CLI outside web/group-writable paths
##########################################
sub InstallAdminTool
{
  my $source = 'tools/eluser.pl';
  my $directory = '/usr/local/sbin';
  my $destination = $directory.'/eluser';

  die "Authentication admin tool source not found: $source\n" if (!-f $source || -l $source);
  die "Authentication admin tool destination not found: $directory\n" if (!-d $directory);
  die "Authentication admin tool installation requires root\n" if ($> != 0);

  print "  INSTALL: $destination\n";
  copy($source, $destination)
    or die "Unable to install authentication admin tool: $!\n";
  chmod(0755, $destination)
    or die "Unable to set authentication admin tool permissions: $!\n";
  chown(0, 0, $destination)
    or die "Unable to set authentication admin tool ownership: $!\n";
} #InstallAdminTool


##########################################
# StripPerlComments <filepath>
# - Strip full line comments from a file
##########################################
sub StripPerlComments {
  my ( $filepath ) = @_;

  my $file = $filepath;
  my $newfile = $filepath.'-';

  print "  $file\n";

  open(FILE, '<', $file) or die "Open failed $file";
  open(NEWFILE, '>', $newfile) or die "Write failed $newfile";

  # read all lines from file and put into newfile
  while (<FILE>) {
    if ((!($_ =~ /^[ 	]*#.*$/)   # not a full line comment
      &&!($_ =~ /^[ 	]*$/)      # Blank lines/tabs skipped
        )
      ||index($_, '#!') == 0       # don't get header line
      ) {
      $_ =~ s/; [ 	]*#.*$/;/;  # take out any trailing comments after certain characters
      $_ =~ s/\) [ 	]*#.*$/\)/;
      $_ =~ s/{ [ 	]*#.*$/{/;
      $_ =~ s/} [ 	]*#.*$/}/;
      $_ =~ s/" [ 	]*#.*$/"/;
      $_ =~ s/' [ 	]*#.*$/'/;
      $_ =~ s/, [ 	]*#.*$/,/;
      $_ =~ s/0 [ 	]*#.*$/0/;
      $_ =~ s/1 [ 	]*#.*$/1/;
      $_ =~ s/[ 	]*$//;     # take out any trailing spaces/tabs
      #$_ =~ s/^[ 	]*//;      # take out any leading spaces/tabs
      print NEWFILE $_;
    }
  }
  close(FILE);
  close(NEWFILE);
  # move newfile to oldfile
  move($newfile, $file);
} #StripPerlComments


##########################################
# AddHeaderAlias <filepath> <perl> <libpath>
# - Add a header line to executable for cgi-bin to find correct perl version
# - Also creates a shorthand name for the file without .pl
# - $libPath provides an alternate package library path
##########################################
sub AddHeaderAlias
{
  my ( $filepath, $perl, $libPath ) = @_;

  # Set the header
  my $head = "#!$perl\n";

  my $file = $filepath;
  my $newfile = $filepath;
  $newfile =~ s/\.pl$//;   # strip off .pl
  # Modify Notice
  print "Modifying header:   $file   $newfile\n";

  open(FILE, '<', $file) or die 'Open failed $file';
  open(NEWFILE, '>', $newfile) or die 'Write failed $newfile';
  # write the header to newfile
  print NEWFILE $head;
  # read all lines from file and put into newfile
  while (<FILE>) {
    # Look for "use lib" directive
    if ($libPath ne "" && $_ =~ /^[ 	]*use lib .*\.\/lib.*;.*/) {
      print NEWFILE "use lib '$libPath';\n";   # Add the new $libPath package library to the file
    } else {
      print NEWFILE $_;
    }
  }
  close(FILE);
  close(NEWFILE);
  # copy newfile to oldfile
  # newfile remains as the shorthand version
  copy($newfile, $file)
    or die "Unable to update CGI program: $file\n";
  chmod(0755, $newfile, $file) == 2
    or die "Unable to set executable CGI permissions: $file / $newfile\n";
} #AddHeaderAlias


##########################################
# PropogateUsage()
# - Show usage information
##########################################
sub PropogateUsage {
  print "\n$0 [<libpath> / . / \"\"] [<StripPerlComments 1/0> def:0]\n\n";

  print "Copies the Orbit, Core, and Akashic files in the current directory to:\n";
  print "  - Apache CGI-BIN\n";
  print "  - Perl Library path (or specified on command line)\n\n";

  print "  <libpath> - Specifies the library path for Perl packages (used in cgi-bin headers)\n";
  print "            - Also the lib destination path for the Orbit/Core/Akashic package install\n";
  print "            - Files are not copied to . or ./lib or ../lib\n\n";

  print "  <StripPerlComments> - 1 = Remove all Perl comments from files being copied to cgi-bin and lib\n";
  print "                        0 = Keep comments in place\n\n";

  print "Example: (use standard unix Perl Library, Strip comments from Perl files.\n";
  print "  $0 /usr/lib/perl 1\n\n";

  exit 0;
} #PropogateUsage


#*****************************************
# ValidatePlatform
#
#   :::   FOR THE SPECIFIC PLATFORM    :::
#
#   - Set the Destination cgi-bin path ($DestPath)
#   - Set the perl executable for use in cgi-bin headers ($perl)
#   - Set the Perl package library path ($libPath)
#
#*****************************************
sub ValidatePlatform
{
  #
  # NOTES
  #
  # Perl 5.16.3
  #!c:/xampp/perl/bin/perl.exe

  # Perl 5.28.1
  #!c:/Perl64/bin/perl.exe
  # Cygwin
  #!/usr/bin/perl

  # Perl 5.32.1
  # StrawberryPerl
  #!c:/StrawberryPerl/perl/bin/perl.exe
  #!c:/Strawberry/perl/bin/perl.exe

  # Reset defaults if they don't exist - find below
  $DestPath = "" if (!-d $DestPath);
  $perl = "" if (!-e $perl);

  #
  # Apache Windows Config
  #
  if ($DestPath eq "") {
    $DestPath = "c:/Apache24/cgi-bin";
    $DestPath = "" if (!-d $DestPath);
  }

  #
  # XAMPP Windows Config
  # 5.16.3
  #
  if ($DestPath eq "") {
    $DestPath = "c:/xampp/cgi-bin";
    $DestPath = "" if (!-d $DestPath);
    $perl     = "c:/xampp/perl/bin/perl.exe" if ($DestPath ne "");
    $libPath  = "c:/xampp/perl/site/lib"     if ($DestPath ne "");
  }

  #
  # StrawberryPerl Windows Config
  # 5.32.1
  #
  if ($perl eq "") {
    $perl    = "c:/StrawberryPerl/perl/bin/perl.exe";
    $perl    = "" if (!-e $perl);
    $libPath = "c:/StrawberryPerl/perl/site/lib" if ($perl ne "");
  }

  #
  # StrawberryPerl Windows Config
  # 5.32.1
  #
  if ($perl eq "") {
    $perl    = "c:/Strawberry/perl/bin/perl.exe";
    $perl    = "" if (!-e $perl);
    $libPath = "c:/Strawberry/perl/site/lib" if ($perl ne "");
  }

  #
  # Perl64 Config
  # 5.28.1
  #
  if ($perl eq "") {
    $perl    = "c:/Perl64/bin/perl.exe";
    $perl    = "" if (!-e $perl);
    $libPath = "c:/Perl64/site/lib" if ($perl ne "");
  }
} #ValidatePlatform


1;
