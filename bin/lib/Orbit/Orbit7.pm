#!/usr/bin/perl
# Version 7.0.0.0       7-Jul-2021
#******************************************************************************************
#*
#*  Orbit::Orbit7
#*
#*  Package Name    :   Orbit for Perl (Version 7)
#*
#*  Description     :   The Orbit package is the interface to the
#*                      Orbit Web Development Suite for perl
#*
#*  Orbit uses a scripting language named OML (Orbit Markup Language)
#*  for retrieving and processing data using templates with suffix .oml
#*
#*  To include in your perl project:
#*    use Orbit;
#*
#*  NOTES:
#*  * The main procedure to display an Orbit page is ShowPage
#*  * Other procedures are used by the end user in their perl API
#*    ie. AppendError() and Set_Token() to set set internal Token variables
#*
#-------------------------------------------------------------------------------
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.25 earth.love oK Removed OML Functions & Modifiers from Header - loaded dynamically
#   2021.06.17 earth.love oK Version 7 additions - direct OML function call
#   2021.05.21 earth.love oK CGI Env variables fixed
#   2021.04.29 earth.love oK Refactored
#   2021.04.29 earth.love oK Function Args array added
#   2021.04.24 earth.love oK Converted from PL/SQL Orbit package (2015.05.30 Ver 5.0.0.0)
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
#******************************************************************************************
# Functions Supported:
#*****************************************
#
# new()
#   - Initializes the Orbit Functions package
#
# ShowPage <TEMPLATE.oml>
#   - This procedure is used for displaying the OML Template
#
# SetTemplateDir <Template Directory>
#   - Sets a Template Directory in the _TEMPLATEDIRS array
#
# SearchTemplateDirs <TemplateFile>
#   - Sets a Template Directory in the _TEMPLATEDIRS array
#
# Eval <expression>
#   - Evaluates an Orbit OML expression and returns:
#    - (1) TRUE : if the expression evaluates to TRUE, parses to 1, or contains
#           only tokens which parse out to not null (ie existence test)
#     - (0) FALSE: if the expression evaluates to FALSE or parses to 0
#     - ""       : if the expression can not be parsed or invalid expression
#
# ShowTokenTable
#   - Shows all the Token / Value combinations
#   - This is used for debugging and can be called after Show_Page
#     or with the #DEBUG[<raw_text_flag>]# token function within any section
#   - If fn_raw_format_flag = 0, the output will be in the form of an HTML table,
#     otherwise it will be in a raw format without decorations
#   - bPrint (1/0) to print or just return output as value
#
# ResetTokenTable
#   - Removes all Tokens from the Token Table
#
# print
#   - Print the HTML text specified, either to STDOUT or internal _Output buffer
#   - Set fb_no_carriage_return (1) to not print a trailing carriage return
#
# Fatal_Error
#   - Called only when the standard page can not be displayed (ie. No version info).
#   - Prints the text with very basic HTML in PRE-formatted output,
#     along with any ERROR_TEXT, MESSAGE_TEXT, and SUCCESS_TEXT.
#   - If fn_dump_environment = 1, all Token and environment variables are also displayed.
#   - The token SHOW_ENV_FLAG will override the fn_dump_environment if set to '0'
#     ie) If SHOW_ENV_FLAG = '0', the environment variables will not display
#
# initOrbit
#   - Initialize Orbit before calling Show_Page from the command line
#
# LoadEnvTokens
#   - Resets the internal cache tables and buffers
#
# Reset_Cache
#   - Resets the internal cache tables and buffers
#
#******************************************************************************************
package Orbit;

use strict;
use warnings;
use utf8;
use feature ':5.16';
use CGI qw( -utf8 );

our $VERSION = '7.0.0.0';

# Export certain functions - allow ShowPage without prefixing package   #TESTING
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(new ShowPage Set_Token SetToken Get_Token GetToken);

# Orbit packages
use Orbit::Core;
use Orbit::Utils;
use Orbit::Token;
use Orbit::Tokens;
use Orbit::OML::Parse;
use Orbit::User;
# Load in Orbit User Configurations
use Orbit::myConfig;

#******************************************************************************************
#*                                                                                        *
#*                              PUBLIC PROCEDURE DEFINITIONS                              *
#*                                                                                        *
#******************************************************************************************


#******************************************************************************************
#*  Procedure Name  :   new
#*
#*  Description     :   Initializes the Orbit Functions package
#******************************************************************************************
sub Orbit::new
{
  my $class = shift;   # class is the name of this package: Orbit
  my ($V, $O);   # For dynamic and direct function calls

  # Define the token structure (class variables)
  my $self = {
     _cgi            => CGI->new()      # Initialize CGI
    ,_Akashic        => ""
    ,_Utils          => CoreUtils->new() # Initialize Utility Functions
    ,_VERSION        => '7.0.0.0   17-Jun-2021'
    ,_OML_VERSION    => '7.1.0.0   18-Jun-2021'
    ,_Strict         => '1'             # Run with more strict parsing rules, or loosen for performance.  Currently: 0 (Performance), 1 (Strict Parsing)
     #
     # User
     #
    ,_User            => ''               # Authenticated User
    ,_UserDir         => ''               # User Directory for './_ORBIT/USERS/#user#/'
    ,_UserRoot        => '_ORBIT/USERS'   # User Directory for Authenticating a User
    ,_UserRootDir     => '.'              # User Directory for Authenticating a User
    ,_Lang            => ''               # User Language for MSG Translation
    ,_Access          => ''               # Access pattern in multi RegEx format (RegEx1, RegEx2, ...)
     #
     # Main user referencable content through OML #Functions[]# and #Mod.ifiers#
     #
    ,_TOKENS         => { }             # Define the empty TOKENS hash (array)
     # Datafile Processing
    ,_COLUMNS        => { }             # Columns Names (Headers) retrieved from a dataset (array)
    ,_DATA           => { }             # Data retrieved from a source
    ,_DATAROOT       => ''              # Data Root under Domain. Set with DATAOPEN
    ,_DATAWORD       => ''              # Word/Phrase/Path under Root
    ,_DATAFILE       => ''              # Datfile name (ie CATS.dat)
    ,_DATAPATH       => ''              # Full or Relative Directory to the DataFile
    ,_DATASEP        => '|'             # Default data and column separator
    ,_DATAHEADER     => 0               # Flag to indicate if datafile has a header record defining columns (1/0)
    ,_DATASORT       => 0               # Flag to sort datafiles (numeric sort, then character sort) (1/0)
     #
     # External Text Buffers for scripting
     #
    ,_Output         => ""              # Output Buffer: getOutput, setOutput
     #
     # Internal Text Buffers
     #
    ,_Buffer         => ""              # Input Buffer
    ,_BackupExt      => '_BACK'         # Default Token Backup Extension ('_BACK') from the ASSIGN or BACK functions
     #
     # User parameter and configurations (mixed case is allowed, showing uppercase for readability)
     #
     # Template Definitions - simple defaults for starting out with basics
    ,_TEMPLATEDIRS   => { }             # Template searth path
    ,_Template       => 'DEFAULT'       # Default Template ('DEFAULT')
    ,_TemplateDir    => './_TEMPLATES'  # Default Template Directory if _TEMPLATEDIRS is not defined
    ,_TemplateExt    => '.oml'          # Default Template Extension ('.oml') OML - Orbit Markup Language
     #
     # Message Translation Management
     #
    ,_MessageCodeRoot => '_ORBIT/MSG/CODE'     # Message Code Root off of Domain
    ,_MessageCodeDir  => ''                    # Message Code Full Directory - set internally
    ,_MessageLangRoot => '_ORBIT/MSG/#lang#'   # Translated Message Root off of Domain
    ,_MessageLangDir  => ''                    # Message Lang Full Directory - set internally
     #
     # Advanced Processing for Data Files from the earth.love Directory (for more see: Linguistics.earth)
     # Primary use if you're hosting a local data store in a networked community (see: Community101.earth)
     #
    ,_Source         => 'LOVE'          # Source containing all Domains
    ,_SourceDir      => '/LOVE'         # Source Directory above all Domains
    ,_Domain         => 'EARTH'         # Domain Name ('EARTH')
    ,_DomainDir      => '/LOVE/earth.love/'  # Domain Directory ('/LOVE/earth.love')
    ,_Root           => 'LANGS'         # ROOT under Domain (i.e. LANGS COMMS LOCS GUILDS SELF PATHS JOB etc)
    ,_RootDir        => '.'             # ROOT Directory ('.')  i.e. /LOVE/earth.love/COMMS/   for Communities
    ,_Object         => ''              # Object under the Root - could be _Tree _Branch _Page _Word _Data (set Externally)
    ,_Action         => ''              # Action being performed - buffered here for HasAccess (set Externally)
    ,_Tree           => 'TREE'          # TREE off of the ROOT (could also be in PATH format: carpenter.classes.earth)
    ,_TreeDir        => '.'             # TREE Directory (set Externally)
    ,_Branch         => 'BRANCH'        # BRANCH off of the TREE (could also be in PATH format: tools.nearme.earth)
    ,_BranchDir      => '.'             # BRANCH Directory (set Externally)
    ,_Page           => 'index'         # Page under a TREE BRANCH from the "Tree of Knowledge" for a WPP (Word/Phrase/Path)
    ,_PageDir        => '.'             # Page Directory - set Externally in interface
    ,_Word           => ''              # Buffered Word
    ,_WordDir        => ''              # Word Directory ('.') - set Externally in Orbit::Akashic interface
    ,_DataType       => ''              # Data being processed (ie $DataType in Akashic: INDEX WORD CAT)
    ,_DataDir        => '.'             # Data Directory ('.') - set Externally in Orbit::Akashic interface
     #
     # Command options
     #
    ,_bPrintOutput   => 1               # Option to print (1) or keep _Output buffer (0) without printing
    ,_bCommandLine   => 0               # Default to running in HTTP mode. CommandLine (1) prevents Content-Type from displaying
    ,_bCacheOutput   => 0               # Default cache mode OFF (0). SetCacheOutput(1)
    ,_bShowComments  => 0               # Show 1 or Hide 0 OML comments <!--- ---> in included OML files $self->SetComments(1/0)
    ,_bBatchMode     => 0               # Set Batch mode for Refresh_Page processing; Disables showing statistics in individual pages
    ,_bMSGInsert     => 0               # Insert messages requiring translation automatically (1), or not (0), into _MessageCode directory
    ,_bMSGTranslate  => 0               # Translate messages displayed using the #MSG[]# function (1); or quick return from MSG without lookup (0)
     #
     #
     #
    ,_STATIC_PAGE    => 'EL_SHOW_STATIC'     # OML Page to show for Batch Creation - set with SetStaticPage()
    ,_STATIC_HOST    => 'http://localhost'   # Assigned to ENV_HOST in Batch Creation - set with SetStaticHost()
    ,_STATIC_CONTEXT => '/cgi-bin/'          # CGI-BIN Contect Prefix for Batch Creation - usually /o/ for Orbit - set with SetStaticContext()
#******************************************************************************************
# COPY START FOR CORE PRINT AND STATS PACKAGES
#******************************************************************************************
     # Statistics Array
    ,_StatsCnt       => 0
    ,_STATS          => { }  # Summary statistics
     # Print Buffer for Uprint
    ,_PrintBuf       => ''
    ,_bBuffer        => 0    # 1 - print to _PrintBuf, 0 - print to STDOUT
     # Optimization Settings
    ,_bShowStats     => 0    # Show Statistics data
    ,_bLogStats      => 0    # Log the statistics (usually for batch jobs, but possibly for OnLine)
    ,_bShowOutput    => 1    # Show Processing Output Messages; This would be set 0 for interactive
#******************************************************************************************
# END COPY
#******************************************************************************************
     #
     # Date/Time Management
     #
    ,_iStartTime         => 0          # Page Start Time in milliseconds
    ,_iEndTime           => 0          # Page Start Time in milliseconds
     # Recursive Limits
    ,_RecursiveCount     => 0          # Internal Parse Recursive Count
    ,_RecursiveMax       => 10000      # Maximum Parse calls for Recursion
    ,_ParseMax           => 100000     # Maximum Token Parses for a Parse call
     # dbug Level
    ,_debug              => 0          # Debug Level (0-101) - getDebug / setDebugOn/Off
#*******************************************************************************
# OML FUNCTIONS and TOKEN MODIFIERS
# OML - Orbit Markup Language
#*******************************************************************************
     #
     # FUNCTION SUPPORT
     #
    ,_Token            => ''   # Token Buffer for Dynamic Function Calls
    ,_TokVal           => ''   # Used for passing Token Value to dynamic Token Modifier
    ,_Modifier         => ''   # Token Modifier being processed
    ,_Function         => ''   # Function Buffer for Dynamic Function Calls
    ,_Arguments        => ''   # Fuction Text arguments - parsed into array inside functions
    ,_bFlush           => 0    # Flush Parameter for OML Function Calls
    ,_bCache           => 0    # Cache Parameter for OML Function Calls
     # Store the Function Groups loaded to limit unneeded subroutines for a page call
    ,_FN_GROUPS_LOADED => { }
     # Store the Subroutine Reference for the OML Functions - loaded dynamically
    ,_OML_FUNCTIONS    => { }
     # OML TOKEN MODIFIERS - Stores Subroutine Reference for Modifier Functions
    ,_TOKEN_MODIFIERS => { }
  };

  # Bless makes these variables available externally
  bless $self, $class;

  # Run the Orbit user configurations
  $self->UserConfigurations();

  $self->{_iStartTime} = time();   # number of seconds since Jan 1, 1970
  return $self;
} #new


#******************************************************************************************
#*  Procedure Name  :   ShowPage
#*
#*  Description     :   This procedure is used for displaying the OML Template
#******************************************************************************************
sub Orbit::ShowPage
{
  my ( $self, $Template ) = @_;
  my $U = $self->{_Utils};

  #
  # Start the internal timer for page time
  #
  $self->StartTimer();

  #
  # Initialize template to PAGE token if defined
  #
  $Template = "" if (!defined($Template));
  $Template = $self->Get_Token('PAGE') if ($Template eq "");

  #
  # Initialize Orbit (CGI)
  #
  $self->initOrbit();

  #
  # Get the Template File Path
  #
  my $TemplatePath = $self->SearchTemplateDirs( $Template );

  #
  # Make sure Template exists
  #
  if (!-e $TemplatePath) {
    $self->RegisterError("Template [$Template] not found!");
    # Try DEFAULT template to show message
    $TemplatePath = $self->SearchTemplateDirs( $self->{_Template} );
  }

  #
  # Load the ENV_ environment tokens
  #
  $self->LoadEnvTokens();

  #
  # Read in the entire Template file into internal _Buffer
  #
  $self->{_Buffer} = $U->GetFile( $TemplatePath );

  # Set any user defined header messages
  $self->SetHeaderMessage();

  #
  # Strip out the developer comments <!--- --->
  #
  $self->{_Buffer} = $self->StripComments($self->{_Buffer});

  #
  # Parse the internal _Buffer for Tokens and OML Functions; Print results as defind by _bPrintOutput
  #
  $self->Parse($self->{_Buffer}, 1);

  # Return the output if we're not printing
  if (!$self->{_bPrintOutput}) {
    return $self->{_Output};
  } else {
    return "";
  }
} #ShowPage


#******************************************************************************************
#* SetTemplateDir <Template Directory>
#* - Sets a Template Directory in the _TEMPLATEDIRS array
#******************************************************************************************
sub Orbit::SetTemplateDir
{
  my ( $self, $Dir ) = @_;

  return 1 if (!defined($Dir) || $Dir eq "");

  # Add trailing / if needed - internal default
  $Dir .= "/" if (substr($Dir, length($Dir)-1, 1) ne "/");

  # Get the size of array
  my $index = keys %{$self->{_TEMPLATEDIRS}};   # initial will return 0

  # Add the new Template Directory to end
  $self->{_TEMPLATEDIRS}->{$index} = $Dir;

  return 0;
} #SetTemplateDir


#******************************************************************************************
#* SearchTemplateDirs <TemplateFile>
#* - Search Template Directory in the _TEMPLATEDIRS array for a TemplateFile
#******************************************************************************************
sub Orbit::SearchTemplateDirs
{
  my ( $self, $Template ) = @_;

  return "" if (!defined($Template) || $Template eq "");

  # Uppercase Template per standard
  $Template =~ tr/[a-z]/[A-Z]/;

  my $TemplFile = "";
  my $rep = "";

  #
  # Search through all TEMPLATE PATHS to find OML Template
  #
  if (keys %{$self->{_TEMPLATEDIRS}} > 0) {
    # Loop through the template paths
    my $TemplateDir = "";
    foreach my $i (sort {$a <=> $b}(keys %{$self->{_TEMPLATEDIRS}}))
    {
      #
      # Check for special directives #_WORDDIR_# #_ROOTDIR_# #_DOMAINDIR_# #_WORD_# #_ROOT_#
      #
      $TemplateDir = $self->{_TEMPLATEDIRS}->{$i};
      #
      if (index($TemplateDir, '#') != -1) {
        if ($TemplateDir =~ /.*#_DOMAINDIR_#\/.*/i) {
          $rep = $self->{_DomainDir};
          $TemplateDir =~ s/#_DOMAINDIR_#\//$rep/i;
          # Reset in-memory TemplateDir so we don't have to parse again
          $self->{_TEMPLATEDIRS}->{$i} = $TemplateDir;
          #
        } elsif ($TemplateDir =~ /.*#_ROOTDIR_#\/.*/i) {
          $rep = $self->{_RootDir};
          $TemplateDir =~ s/#_ROOTDIR_#\//$rep/i;
          # Reset in-memory TemplateDir so we don't have to parse again
          $self->{_TEMPLATEDIRS}->{$i} = $TemplateDir;
          #
        } elsif ($TemplateDir =~ /.*#_WORDDIR_#\/.*/i) {
          $rep = $self->Get_Token('_WORDDIR_');
          $TemplateDir =~ s/#_WORDDIR_#\//$rep/i;
          # Reset in-memory TemplateDir so we don't have to parse again
          $self->{_TEMPLATEDIRS}->{$i} = $TemplateDir;
          #
        }

        #
        # Check for _ROOT_ and _WORD_ separately since they are not full directory paths
        #
        if ($TemplateDir =~ /.*#_ROOT_#.*/i) {
          $rep = $self->{_Root};
          $TemplateDir =~ s/#_ROOT_#/$rep/gi;
          # Reset in-memory TemplateDir so we don't have to parse again
          $self->{_TEMPLATEDIRS}->{$i} = $TemplateDir;
        }
        if ($TemplateDir =~ /.*#_WORD_#.*/i) {
          $rep = $self->Get_Token('_WORD_');
          $TemplateDir =~ s/#_WORD_#/$rep/gi;
        }
      }
      #
      # Build the Template Filename
      #
      $TemplFile = $TemplateDir.$Template.$self->{_TemplateExt};

      # See if the template exists there
      last if (-e $TemplFile);

      # not found - reset
      $TemplFile = "";
    } #foreach
  } else {
    # Template Paths array was not declared, use internal template dir
    $TemplFile = $self->{_TemplateDir}.$Template.$self->{_TemplateExt};
    if (!-e $TemplFile) {
      $TemplFile = "";
    }
  }
  return $TemplFile;
} #SearchTemplateDirs


#******************************************************************************************
#* Eval <expression>
#*
#* - Evaluates an Orbit OML expression and returns:
#*   - (1) TRUE : if the expression evaluates to TRUE, parses to 1, or contains
#*         only tokens which parse out to not null (ie existence test)
#*   - (0) FALSE: if the expression evaluates to FALSE or parses to 0
#*   - ""       : if the expression can not be parsed or invalid expression
#******************************************************************************************
sub Orbit::Eval
{
  my ( $self, $Expression ) = @_;

  # Leave if no data - Evals to 0
  return '0' if ($Expression eq '');

  # Parse the expression since it may have OML logic
  my $Value = $self->Parse($Expression, 0);  # Return parse results, noprint
  $Value =~ tr/[a-z]/[A-Z]/;
  # Leave if no data -Eval 0
  return '0' if ($Value eq '');

  if ($Value =~ /^1$/
    ||$Value =~ /^TRUE$/
    ||$Value =~ /^T$/
    ||$Value =~ /^YES$/
    ||$Value =~ /^Y$/
    # allow positive numbers to Eval to true
    ||(  $Value =~ /^[0-9,.]*$/
      && !($Value =~ /^0.*$/)
      )
    ) {
    return '1';
  } elsif ($Value =~ /^0$/
    ||$Value =~ /^FALSE$/
    ||$Value =~ /^F$/
    ||$Value =~ /^NO$/
    ||$Value =~ /^N$/
    ) {
    return '0';
  }

  return '';
} #Eval


#******************************************************************************************
#* ShowTokenTable
#*
#* - Shows all the Token / Value combinations
#* - This is used for debugging and can be called after Show_Page
#*   or with the #DEBUG[<raw_text_flag>]# token function within any section
#* - If fn_raw_format_flag = 0, the output will be in the form of an HTML table,
#*   otherwise it will be in a raw format without decorations
#* - bPrint (1/0) to print or just return output as value
#******************************************************************************************
sub Orbit::ShowTokenTable
{
  my ( $self, $bRaw, $SearchTerm, $bPrint ) = @_;
  $bRaw = 1 if (!defined($bRaw) || $bRaw ne '0');
  $bPrint = 1 if (!defined($bPrint) || $bPrint ne '0');
  $SearchTerm = "" if (!defined($SearchTerm));
  my $tokref;
  my $buf = '';

  if (!$bRaw) {
    $buf .= "<table>\n";
  }
  # Loop through each Token and print
  foreach my $tok (sort(keys %{$self->{_TOKENS}}))
  {
    $tokref = $self->{_TOKENS}->{$tok};
    # Check for search term
    if ($SearchTerm eq ""
      ||$tokref->getName =~ /$SearchTerm/i
      ||$tokref->getValue =~ /$SearchTerm/i
      ) {
      if ($bRaw) {
        # Use Orbit print to determine output
        $buf .= $tokref->print(0);
      } else {
        $buf .= "<tr><td>".$tokref->getName."</td><td>".$tokref->getRawValue."</td></tr>\n";
      }
    } #SearchTerm
  } #foreach
  if (!$bRaw) {
    $buf .= "</table>\n";
  }
  print $buf if ($bPrint);
  return $buf;
} #ShowTokenTable


#******************************************************************************************
#* ResetTokenTable
#*
#* - Removes all Tokens from the Token Table
#******************************************************************************************
sub Orbit::ResetTokenTable
{
  my ( $self ) = @_;

  # Loop through each Token and delete
  foreach my $tok (sort(keys %{$self->{_TOKENS}}))
  {
    $self->Delete_Token($tok);
  } #foreach

} #ResetTokenTable


#******************************************************************************************
#* print
#*
#* - Print the HTML text specified, either to STDOUT or internal _Output buffer
#* - Set fb_no_carriage_return (1) to not print a trailing carriage return
#******************************************************************************************
sub Orbit::print
{
  my ( $self, $Text, $fb_no_carriage_return ) = @_;

  $fb_no_carriage_return = 0 if (!defined($fb_no_carriage_return));

  # See if we print directly to STDOUT or keep in _Output buffer
  if ($self->{_bPrintOutput} == 1) {
    if ($fb_no_carriage_return == 0) {
      print $Text."\n";
    } else {
      print $Text;
    }
  } else {
    if ($fb_no_carriage_return == 0) {
      $self->{_Output} .= $Text."\n";
    } else {
      $self->{_Output} .= $Text;
    }
  }

  return 0;
} #print


#******************************************************************************************
#* Fatal_Error
#*
#* - Called only when the standard page can not be displayed (ie. No version info).
#* - Prints the text with very basic HTML in PRE-formatted output,
#*   along with any ERROR_TEXT, MESSAGE_TEXT, and SUCCESS_TEXT.
#* - If fn_dump_environment = 1, all Token and environment variables are also displayed.
#* - The token SHOW_ENV_FLAG will override the fn_dump_environment if set to '0'
#*   ie) If SHOW_ENV_FLAG = '0', the environment variables will not display
#******************************************************************************************
sub Orbit::Fatal_Error
{
  my ( $self, $Text, $Dump ) = @_;
  my $U = $self->{_Utils};
  use Core::HTML;

  $Text = "" if (!defined($Text));
  $Dump = 0 if (!defined($Dump));

  #-- Make sure we're not buffering
  $self->print('<HTML><HEAD><TITLE>A Fatal Error has occurred</TITLE></HEAD><BODY><PRE>'."\n");
  $self->print($U->Get_Raw_Text($Text));
  $self->print('</PRE>');
  #-- Set the header message based on ERROR_TEXT, MESSAGE_TEXT, SUCCESS_TEXT
  $self->SetHeaderMessage;
  $self->print("\n<p>MESSAGES:<BR>".$self->Get_Token('HEADER_MESSAGE'));
  $self->print("\n<p>\n");
  #-- Show the environment if specified
  if ($Dump == 1
     && $self->Get_Token('SHOW_ENV_FLAG') eq '1') {
    $self->ShowTokenTable;
    $self->print("\n<p>\n");
  }
  # Dump the output buffer
  $self->print($self->{_Output});

  return 0;
} #Fatal_Error


#******************************************************************************************
#* initOrbit
#*
#* - Initialize Orbit before calling Show_Page from the command line
#******************************************************************************************
sub Orbit::initOrbit
{
  my ( $self ) = @_;

  #
  # Print the HTML content header, only if not running in command line or script
  #
  if ($self->{_bCommandLine} == 0) {
    $self->print(
        $self->{_cgi}->header(
            -type    => 'text/html',
            -charset => 'utf-8',
            ));
  }

  # Make sure TemplateDir has a trailing /
  $self->{_TemplateDir} .= "/" if (substr($self->{_TemplateDir}, length($self->{_TemplateDir})-1, 1) ne "/");

  # Reset Output buffer
  $self->{_Output} = "";
  
  # Load the default Function Groups: BASE & DATA
  $self->LoadFunctionGroups(0);
  $self->LoadFunctionGroups(70);
  #$self->LoadFunctionGroups('ALL');   #TESTING

} #initOrbit


#******************************************************************************************
#* LoadEnvTokens
#*
#* - Resets the internal cache tables and buffers
#******************************************************************************************
sub Orbit::LoadEnvTokens
{
  my ( $self ) = @_;
  my $U = $self->{_Utils};

  $self->Set_Token('ENV_SYSDATE',             $U->sysdate(0));
  $self->Set_Token('ENV_GMT_SYSDATE',         $U->gmt_sysdate(1));
  $self->Set_Token('ENV_DATABASE',            $self->GetDatabaseName());   # DomainName from Akashic

  #
  # Read some of the Apache Environment variables and set a Token for each with ENV_ prefix
  #
  my $value;
  foreach my $var (sort(keys(%ENV))) {
    if ($var eq 'HTTP_HOST'
      ||$var eq 'HTTP_USER_AGENT'
      ||$var eq 'HTTP_COOKIE'
      #||$var eq 'HTTP_ACCEPT'
      ||$var eq 'CONTEXT_PREFIX'
      ||$var eq 'CONTEXT_DOCUMENT_ROOT'
      ||$var eq 'DOCUMENT_ROOT'
      ||$var eq 'SCRIPT_NAME'
      ||$var eq 'REQUEST_METHOD'
      ||$var eq 'REQUEST_URI'
      ||$var eq 'REQUEST_SCHEME'
      ||$var eq 'SERVER_ADDR'
      ||$var eq 'SERVER_NAME'
      ||$var eq 'SERVER_PORT'
      ||$var eq 'SERVER_PROTOCOL'
      ||$var eq 'SERVER_SOFTWARE'
      ||$var eq 'SERVER_SIGNATURE'
      ||$var eq 'SERVER_ADMIN'
      ||$var eq 'REMOTE_HOST'
      ||$var eq 'REMOTE_ADDR'
      ||$var eq 'REMOTE_USER'
      ||$var eq 'GATEWAY_INTERFACE'
      ||$var eq 'AUTH_TYPE'
      ||$var eq 'BOT'  # ENV_BOT is set in /etc/apache2/elRewrite.conf indicating a robot request
      #||1   # Hack: Uncomment to show all if needed
      ) {
      $value = $ENV{$var};
      $value =~ s/\n/\\n/g;
      $value =~ s/"/\\"/g;
      $self->Set_Token('ENV_'.$var, $value);
    }
  }

  # Set the DomainDir based on ENV_DOCUMENT_ROOT
  $value = $ENV{'DOCUMENT_ROOT'};
  if (defined($value) && $value =~ /_WEB$/) {
    $value =~ s/_WEB$//g;
    $self->Set_Token('ENV_DOMAINDIR', $value);
    $self->{_DomainDir} = $value;
  }

  # Set the special ENV_HOST token based on pieces
  if ($self->Get_Token('ENV_REQUEST_SCHEME') ne "") {
    if ($self->Get_Token('ENV_SERVER_PORT') eq '80'
      #-- only include port if not already on host
      || index($self->Get_Token('ENV_HTTP_HOST'), ':'.$self->Get_Token('ENV_SERVER_PORT')) != -1
      ) {
      $self->Set_Token('ENV_HOST', $self->Get_Token('ENV_REQUEST_SCHEME').'://'.$self->Get_Token('ENV_HTTP_HOST'));
    } else {
      $self->Set_Token('ENV_HOST', $self->Get_Token('ENV_REQUEST_SCHEME').'://'.$self->Get_Token('ENV_HTTP_HOST').':'.$self->Get_Token('ENV_SERVER_PORT'));
    }
  }
  return 0;
} #LoadEnvTokens


#******************************************************************************************
#* Reset_Cache
#*
#* - Resets the internal cache tables and buffers
#******************************************************************************************
sub Orbit::Reset_Cache
{
  my ( $self ) = @_;

  return "CODE";
} #Reset_Cache


#========================================================================================
# END ORBIT SUBROUTINES
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Orbit7;
#******************************************************************************************
1;


#END Orbit::Orbit7;
