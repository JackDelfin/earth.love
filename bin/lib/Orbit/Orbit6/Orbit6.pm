#!/usr/bin/perl
# Version 6.1.6.0      2-Jun-2021
#******************************************************************************************
#*
#*  Orbit::Orbit6
#*
#*  Package Name    :   Orbit for Perl (Version 6)
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
#*****************************************************************************************
package Orbit;

use strict;
use warnings;
use utf8;
use feature ':5.16';
use CGI qw( -utf8 );

# Orbit packages
use Orbit::Orbit6::Core;
use Orbit::Orbit6::Utils;
use Orbit::Orbit6::Token;
use Orbit::Orbit6::OML6::Parse6;
# Load in Orbit User Configurations
use Orbit::Orbit6::myConfig;

#******************************************************************************************
#*                                                                                        *
#*                              PUBLIC PROCEDURE DEFINITIONS                              *
#*                                                                                        *
#******************************************************************************************


#******************************************************************************************
#*  Procedure Name  :   new
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Initializes the Orbit Functions package
#******************************************************************************************
sub Orbit::new
{
  my $class = shift;   # class is the name of this package: Orbit

  # Define the token structure (class variables)
  my $self = {
     _cgi           => CGI->new()      # Initialize CGI
    ,_Akashic       => ""
    ,_Utils         => CoreUtils->new()
    ,_VERSION       => '6.0.6.0   21-May-2021'
    ,_OML_VERSION   => '7.0.1.0   21-May-2021'
    ,_Strict        => '1'             # Run with more strict parsing rules, or loosen for performance.  Currently: 0 (Performance), 1 (Strict Parsing)
     #
     # User
     #
    ,_User           => ''                   # Authenticated User
    ,_UserDir        => '.'                  # User Directory for Authenticating a User
    ,_UserDirDefault => './_ORBIT/USERS/#user#/'   # Default User Directory for './_ORBIT/USERS/#user#/'
    ,_Access         => ''                   # Access pattern in multi RegEx format (RegEx1, RegEx2, ...)
     #
     # Main user referencable content through OML #Functions[]# and #Mod.ifiers#
     #
    ,_TOKENS        => { }             # Define the empty TOKENS hash (array)
     # Datafile Processing
    ,_COLUMNS       => { }             # Columns Names (Headers) retrieved from a dataset (array)
    ,_DATA          => { }             # Data retrieved from a source
    ,_DATAROOT      => ''              # Data Root under Domain. Set with DATAOPEN
    ,_DATAWORD      => ''              # Word/Phrase/Path under Root
    ,_DATAFILE      => ''              # Datfile name (ie CATS.dat)
    ,_DATASEP       => '|'             # Default data and column separator
    ,_DATAHEADER    => 0               # Flag to indicate if datafile has a header record defining columns (1/0)
    ,_DATASORT      => 0               # Flag to sort datafiles (numeric sort, then character sort) (1/0)
     #
     # External Text Buffers for scripting
     #
    ,_Output        => ""              # Output Buffer: getOutput, setOutput
     #
     # Internal Text Buffers
     #
    ,_Buffer        => ""              # Input Buffer
    ,_BackupExt     => '_BACK'         # Default Token Backup Extension ('_BACK') from the ASSIGN or BACK functions
     #
     # User parameter and configurations (mixed case is allowed, showing uppercase for readability)
     #
     # Template Definitions - simple defaults for starting out with basics
    ,_TEMPLATEDIRS  => { }             # Template searth path
    ,_Template      => 'DEFAULT'       # Default Template ('DEFAULT')
    ,_TemplateDir   => './_TEMPLATES'  # Default Template Directory if _TEMPLATEDIRS is not defined
    ,_TemplateExt   => '.oml'          # Default Template Extension ('.oml') OML - Orbit Markup Language
     #
     # Advanced Processing for Data Files from the earth.love Directory (for more see: Linguistics.earth)
     # Primary use if you're hosting a local data store in a networked community (see: Community101.earth)
     #
    ,_Domain        => 'EARTH'         # Domain Name ('EARTH')
    ,_DomainDir     => '/LOVE/earth.love'   # Domain Directory ('/LOVE/earth.love')
    ,_Root          => 'LANGS'         # ROOT under Domain (i.e. LANGS COMMS LOCS GUILDS SELF PATHS JOB etc)
    ,_RootDir       => '.'             # ROOT Directory ('.')  i.e. /LOVE/earth.love/COMMS/   for Communities
    ,_Object        => ''              # Object under the Root - could be _Tree _Branch _Page _Word _Data - set Externally
    ,_Action        => ''              # Action being performed - buffered here for HasAccess - set Externally
    ,_Tree          => 'TREE'          # TREE off of the ROOT (could also be in PATH format: carpenter.classes.earth)
    ,_TreeDir       => '.'             # TREE Directory (set Externally)
    ,_Branch        => 'BRANCH'        # BRANCH off of the TREE (could also be in PATH format: tools.nearme.earth)
    ,_BranchDir     => '.'             # BRANCH Directory (set Externally)
    ,_Page          => 'index'         # Page under a TREE BRANCH from the "Tree of Knowledge" for a WPP (Word/Phrase/Path)
    ,_PageDir       => '.'             # Page Directory - set Externally in interface
    ,_Word          => ''              # Buffered Word
    ,_WordDir       => ''              # Word Directory ('.') - set Externally in Orbit::Akashic interface
    ,_DataType      => ''              # Data being processed (ie $DataType in Akashic: INDEX WORD CAT)
    ,_DataDir       => '.'             # Data Directory ('.') - set Externally in Orbit::Akashic interface
     #
     # Command options
     #
    ,_bPrintOutput  => 1               # Option to print (1) or keep _Output buffer (0) without printing
    ,_bCommandLine  => 0               # Default to running in HTTP mode. CommandLine (1) prevents Content-Type from displaying
    ,_bCacheOutput  => 0               # Default cache mode OFF (0). SetCacheOutput(1)
    ,_bShowComments => 0               # Show 1 or Hide 0 OML comments <!--- ---> in included OML files $self->SetComments(1/0)
    ,_bBatchMode    => 0               # Set Batch mode for Refresh_Page processing; Disables showing statistics in individual pages
#******************************************************************************************
# COPY START FOR CORE PRINT AND STATS PACKAGES
#******************************************************************************************
     # Statistics Array
    ,_StatsCnt      => 0
    ,_STATS         => { }  # Summary statistics
     # Print Buffer for Uprint
    ,_PrintBuf      => ''
    ,_bBuffer       => 0    # 1 - print to _PrintBuf, 0 - print to STDOUT
     # Optimization Settings
    ,_bShowStats    => 0    # Show Statistics data
    ,_bLogStats     => 0    # Log the statistics (usually for batch jobs, but possibly for OnLine)
    ,_bShowOutput   => 1    # Show Processing Output Messages; This would be set 0 for interactive
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
    ,_RecursiveMax       => 50         # Maximum Parse calls for Recursion
    ,_ParseMax           => 10000      # Maximum Token Parses for a Parse call
     # dbug Level
    ,_debug              => 0          # Debug Level (0-101) - getDebug / setDebugOn/Off
     #
     # OML FUNCTIONS - Orbit Markup Language Functions
     #
     # Note: Commenting out functions raises "Odd number of elemens in anonymous hash" error
    ,_OML_FUNCTIONS => {
         #
         # Token Manipulation Functions
         #
         'ASSIGN',0      # [value][backup(1/0) or BackupExt] - Token Assignment without parsing (also #token=[value]# without function name); Backup (1) will set existing value of TOKEN to TOKEN_BACK as default, or BackupExt could be set instead (ie _BACKUP).
        ,'EVAL',0        # [condition].[then].[else]   - evaluates the boolean expression and returns boolean 1 or 0; null evaluates to 0
        ,'PARSE',0       # [text]            - Parses the text, replacing tokens and functions, including modifiers
        ,'DELETE',0      # [token]...[token] - Delete all of the TOKENs to free up memory.  Useful for large buffers in certain tokens.
        ,'LOADTOKEN',0   # [tok=value\n ...] - Load a list of tokens, carriage return separated, and token specified as: token = [ value ] token = value token=value - No parsing is done; one token per line
        ,'TOKENLOAD',0
        ,'LOADMSG',0     # [tok=value\n ...] - Same as LOADTOKEN, but also performs a MSG translation for each value
        ,'MSGLOAD',0
        ,'MSG',0         # [code].[message_text].[message_help].[comment_text] - Get the message text for the code specified, and the user or country default language
        ,'MESSAGE',0     # [code].[message_text].[message_help].[comment_text] - Get the message text for the code specified, and the user or country default language
        ,'MSGHELP',0     # [code].[message_text].[message_help].[comment_text] - Returns the help text for a message code
        ,'MSGTRANSLATE',0
        ,'MSGINSERT',0
        ,'LANGUAGE',0
        ,'LANG',0
        ,'SETLANG',0
        ,'BACKUP',0      # [token]...[token] - Backup all of the TOKENs, setting existing value to TOKEN_BACK (default).  #BackupExt[_BAK]# provides an alternate Extension.
        ,'RESTORE',0     # [token]...[token] - Restore all of the TOKENs values to TOKEN_BACK (default).
        ,'BACKUPEXT',0   # [BackupExt]       - Set the default Token Backup Extension for all future calls of BACKUP and RESTORE
         #
         # OML Template Include Functions
         #
        ,'INCLUDE',0     # [TEMPLATE].[_1_].[_2_].[_3_]...[_n_] - Include an OML Template file, and optionally set token parameters #_1_# #_2_# ...
        ,'INC',0         # Same as INCLUDE
        ,'OML',0         # Same as INC - Create your own OML function
        ,'FUNCTION',0    # Same as OML
        ,'IFINCLUDE',0   # [condition][then template].[else template].[_1_].[_2_].[_3_]...[_n_]   - if the expression is true, include "then template", or else include "else template"; optionally set token parameters #_1_# #_2_# ...
        ,'INCLUDEIF',0   # Same as IFINCLUDE
        ,'INCIF',0
        ,'IFINC',0       # Same as IFINCLUDE
        ,'OMLIF',0
        ,'IFOML',0       # Same as IFINCLUDE
         #
         # Akashic Data Processing Functions
         #
         # All in one data call - using this method, multiple data files can be open and nested
        ,'DATA',0        # [Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows].[header][repeat_body].[footer].[Sort].[silent] - read and show data file, using #1# #2# #3# etc for variables, separated by "sep", default "|"; Sort (1) sorts the data numerically, then by text
         #
        ,'DATAFILE',0    # [Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows] - Get the full text from the datafile without parsing - can be used to assign to token and show raw text with token.HTML.
        ,'FILE',0        # Same as DATAFILE
        ,'GETFILE',0     # Same as DATAFILE
         # Akashic FIELD / FILE / RECORD Functions
        ,'DATAFIELD',0   # [Root][Word/Phrase/Path][DataFile(s) space separated].[pre].[post]# - Get the first record from the datafiles specified, setting tokens for each datafile like #preDATAFILEpost#
        ,'FIELD',0       # Same as DATAFIELD
        ,'FIELDMSG',0    # Same as DATAFIELD, but performs a MSG translation
        ,'GETFIELD',0    # Same as DATAFIELD
         #
        ,'DATAREC',0     # [Root][Word/Phrase/Path][DataFile] - Get the data record from the datafile and assign tokens to the values based on header record (if present):  !HEADER:a|b|c
        ,'RECORD',0      # Same as DATAREC
        ,'REC',0         # Same as REC
         # Invididual datafile functions
        ,'DATAOPEN',0    # [Root][Word/Phrase/Path][DataFile].[Sep].[Sort] - Sets the datafile location based on Root (off of Domain), Word/Phrase/Path index, and datafile (ie CATS.dat); Separator and Sort flag can also be set in this call.
        ,'DATACLOSE',0   # [Root][Word/Phrase/Path][DataFile] - Closes the datafile
        ,'DATASEP',0     # [Separator] - Defines the data separator for columns and data in the datafile
        ,'DATASORT',0    # [SortFlag] - Set option to sort data when reading (1/0)
        ,'DATAHEADER',0  # [HeaderFlag] - Set Header Flag (1/0) indicating data has a header record
         #
        ,'DATAREAD',0    # [StartRow][MaxRows].[header][repeat_body].[footer].[silent] - Read rows of the datafile into the internal buffer - use #DATAFORMAT[]# to print or specify header/body/footer
        ,'DATASEARCH',0  # [SearchText][MaxRows].[header][repeat_body].[footer].[silent] - Searches rows of the datafile and stores in the internal buffer - use #DATAFORMAT[]# to print or specify header/body/footer
        ,'DATAFORMAT',0  # [header][repeat_body].[footer].[silent] - Format the internal data buffer, showing header, body, footer; silent (1) shows no header/footer if no data found
         #
         # Conditional Functions
         #
        ,'IF',0          # [condition][then].[else]   - traditional if statement, shows then or else
        ,'AND',0         # [eval].[eval]...[eval]      - returns 1 if ALL evals are true, 0 otherwise
        ,'OR',0          # [eval].[eval]...[eval]      - returns 1 if ANY of evals are true, 0 otherwise
        ,'EQUAL',0       # [val1][val2].[then].[else] - tests for equality, returning 1/0 or then/else.  2 calling modes
        ,'NOTEQUAL',0    # Opposite of EQUAL
        ,'NVL',0         # [val1][val2]...[valn] - Returns the first non null (blank) argument
        ,'DECODE',0      # [condition][if][then]...[if][then]...[else] - Like a case statement
        ,'DECODELIKE',0  # DECODE with wildcard expressions in the "if", using *% or _.?
        ,'CASE',0        # Same as DECODELIKE, with built-in pattern matching
        ,'EXISTS',0      # [text][then][else] - conditionally show then/else if text is null
        ,'ISNOTNULL',0   # Same as EXISTS
        ,'NOTNULL',0     # Same as EXISTS
        ,'NOTEXISTS',0   # [text][then][else] - conditionally show then/else if text is NOT null
        ,'ISNULL',0      # Same as NOTEXISTS
        ,'NULL',0        # Same as NOTEXISTS
        ,'LIKE',0        # [val1][val2].[then].[else] - Text wildcard expression (*% _.?) for equality, returning 1/0 or then/else.  2 calling modes
        ,'ILIKE',0       # Same as LIKE, but case insensitive
        ,'IN',0          # [text][in1][in2]...[inx] - Checks for text in the specified arguments
        ,'INLIKE',0      # Same as IN, but with wildcard expression (*% _.?)
        ,'NOTIN',0       # Same as IN, but inverse
        ,'NOTINLIKE',0   # Same as INLIKE, but inverse
         #
         # Numeric Conditional Functions (like a quick IF statement)
         #
        ,'GT',0          # [val1][val2].[then].[else] - Returns 1/0 if val1 is GREATER THANval2 (text and numbers) or returns then/else if specified.  2 calling modes
        ,'GREATERTHAN',0 # Same as GT
        ,'LT',0          # [val1][val2].[then].[else] - Returns 1/0 if val1 is LESS THAN val2 (text and numbers) or returns then/else if specified.  2 calling modes
        ,'LESSTHAN',0    # Same as LT
        ,'GE',0          # Same as GT, but greater than or equal
        ,'GREATEREQUAL',0# Same as GE
        ,'LE',0          # Same as LT, but less than or equal
        ,'LESSEQUAL',0   # Same as LE
        ,'BETWEEN',0     # [text/num][low][high].[then].[else] - Returns 0/1 if text/num is between low and high.  Returns then/else if specified.  2 calling modes
         #
         # Looping Functions
         #
        ,'REPEAT',0      # [times][text]   - Repeatedly displays the <text> <times> number of times.
        ,'WHILE',0       # [expression][text][maxtimes] - Repeatedly displays the <text> while <expression> is TRUE, but not more than <maxtimes> number of times.
         #
         # HTML Helper Functions
         #
        ,'SELECTED',0    # [select/optionHTML][option_value][option_text][select_class][no_add_flag]
                        # For SELECT/OPTION lists in HTML, marks an option as SELECTED, adding the option value/text if not present, and specifying the class style tag
        ,'OPTIONS',0     # [list].[separators].[option_line] - Return an <option> list from the separated input list, for use in HTML SELECT. Separators can be specified or auto-default: pipe(|), comma(,), semi-colon(;) if found in list.   Second separator provides "value|display" pair. 1|apple,2|pear,3|orange,7|kevin; option_line specifies a custom option specification, or any other content, referencing #_OPTION_VALUE_# and #_OPTION_DISPLAY_#
        ,'COMMALIST',0   # [val1].[val2]...[valN] - Return a comma-separated list of all non-NULL arguments in the list
        ,'PIPELIST',0    # [val1].[val2]...[valN] - Return a pipe-separated (|), also vertical bar, list of all non-NULL arguments in the list
        ,'JSQUOTE',0     # [text]                 - Escapes JavaScript code, such as double quote
        ,'HELP',0        # [text].[popup_text].[required_flag] - Returns the full JavaScript syntax to show the text hyperlinked with the popup_text as help.  required_flag adds _req to the class option.
        ,'HELPOVER',0    # [popup_text]          - Returns the JavaScript code for showing popup_text when mouse hovers over text
         #
         # String Functions
         #
        ,'REPLACE',0     # [text][find].[replace] - Replace [find] in [text] with [replace].  Replace First occurance only.
        ,'REPLACEALL',0  # [text][find].[replace] - Replace [find] in [text] with [replace].  Replace ALL occurances with Regular Expressions
        ,'IREPLACE',0    # Case insensitive REPLACE with Regular Expressions
        ,'IREPLACEALL',0 # Case insensitive REPLACEALL with Regular Expressions
        ,'FORMAT',0      # 2 Formats: [date].[in_format].[out_format]   [number].[format]   - Formats the date/number to the specification given, or system default
        ,'NUMFORMAT',0   # [Thousands_Sep][Decimal_Sep][Currency_Symbol] - Set the Thousands, Decimal, Currency formats for use in FORMAT
        ,'SUBSTR',0      # [text][start].[length]  - Gets a substring from [text] beginning at [start] and getting [length] chars.  1-based substr (Oracle) - returns 0 if not found
        ,'SUBSTR0',0     # Same as SUBSTR, but 0-based (Perl) - returns -1 if not found, 0 for beginning of string
        ,'INSTR',0       # [text][find].[begin]   - Position of [find] in [text], starting at [begin]. 1-based offset, returns 0 if string not found, similar to Oracle "instr"
        ,'INDEX',0       # [text][find].[begin]   - Position of [find] in [text], starting at [begin]. 0-based offset, returns -1 if string not found, similar to Perl "index"
        ,'TRANSLATE',0   # [text][from][to]       - Translates the characters in [from] to the characters in [to].
        ,'RPAD',0        # [text][length].[char]  - Right pad text with char up to length
        ,'LPAD',0        # [text][length].[char]  - Left pad text with char up to length
        ,'RTRIM',0       # [text][char]           - Right Trim char from text
        ,'LTRIM',0       # [text][char]           - Left Trim char from text
        ,'TRIM',0        # [text][char]           - Right AND Left Trim char from text
        ,'ROWS',0        # [text].[max_linelength].[min_rows][max_rows]                     - Returns number of rows or lines of text based on the max linesize, limiting by min_rows and max_rows
        ,'WRAP',0        # [text].[max_linelength].[wordbreak_chars].[linebreak_chars]      - Wrap the text based on max linelength, and optionally wordbreak or linebreak characters
        ,'WRAPTOKEN',0   # [tokenName].[max_linelength].[wordbreak_chars].[linebreak_chars] - Same as WRAP, but directed to the specified tokenName
        ,'STRIPTEXT',0   # [text][begin_text][end_text].[replace_text].[match_pairs]        - Replace Text based on begin/end tags (<!--- --->), replacing with replace_text if specified, and matching pairs 0/1
        ,'APPEND',0      # [text1].[text2].[linebreak]   - Appends text2 to text1, with optional likebreak; returns appended string
         #
         # Numeric and Math Related Functions
         #
        ,'ROUND',0       # [num].[decimals:0-4]  - Rounds a number to decimals specified
        ,'TRUNC',0       # [num].[decimals:0-4]  - Truncates a number to decimals specified
        ,'SIGN',0        # [num]                 - Returns -1/0/1/null if num is negative, zero, positive, or null if not a number
        ,'ABS',0         # [num]                 - Returns absolute value of a number (positive)
        ,'MOD',0         # [num][divisor]        - Returns the modulus (remainder) after a division
        ,'ADD',0         # [num].[num]...[num]   - Adds all the numbers in the list
        ,'SUB',0         # [num].[num]...[num]   - Subtracts all the numbers in the list from the first num
        ,'SUBTRACT',0    # Same as SUB
        ,'MULT',0        # [num].[num]...[num]   - Multiplies all the numbers in the list
        ,'MULTIPLY',0    # Same as MULT
        ,'DIV',0         # [num].[num]...[num]   - Divides all the numbers in the list from the first num
        ,'DIVIDE',0      # Same as DIV
        ,'MIN',0         # [a].[b]...[n]         - Returns the minimum (String/Numeric) from the list
        ,'MAX',0         # [a].[b]...[n]         - Returns the maximum (String/Numeric) from the list
        ,'AVG',0         # [a].[b]...[n]         - Returns the average of all numbers in the list
        ,'DISTANCE',0    # [lat,long][lat,long][km]  - Returns Distance in miles between 2 Geo coordinates; km=1 for kilometers
        ,'BEARING',0     # [lat,long][lat,long][dir] - Returns Bearing from first Geo coordinate to second (360 degrees North heading); dir=1 for directional N S E W
        ,'FIBONACCI',0   # [start_iteration][end_iteration][delim] - Returns the Fibonacci sequence starting and ending at specified iterations, delimited by delim (def ,)
         #
         # Date Functions
         #
        ,'SYSDATE',0       # [datetime_format] - Returns the current System Date and Time
        ,'GMTSYSDATE',0    # [datetime_format] - Returns the GMT System Date and Time
        ,'DATE',0          # [format][timezone][bGMT(0/1)] - Returns the current DATE ONLY with decorations based on timezone, in GMT (1) or server time (0); Date format masks: YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
        ,'TIME',0          # [format][timezone][bGMT(0/1)] - Returns the current TIME ONLY with decorations based on timezone, in GMT (1) or server time (0); Time format masks: HH24 H24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
        ,'TIMESTAMP',0     # [DateTimeSep] - Returns the current date and time (GMT) with no decorations, optional DateTimeSep (like _.)
        ,'TRANSACTIONID',0 # [bShort] - Returns a unique Transaction ID when processing data; bShort = 1 for shorter transaction IDs
         #
         # Orbit Internal Functions for Developers
         #
        ,'CACHE',0         # [Token1].[Token2]...[TokenX]  - Set the token cache flag (1) for specified Tokens in the list
        ,'UNCACHE',0       # [Token1].[Token2]...[TokenX]  - Unsets the token cache flag (0) for specified Tokens in the list
        ,'STOP',0          # [condition] - Stops processing of the current template parse if condition is TRUE (1)
        ,'BEFORE',0      # [YYYYMMDDHHMISS].[then template].[else template].[_1_].[_2_].[_3_]...[_n_] - Continues processing and optionally loads additional templates if current date is BEFORE the partial date specified (date could be a token). False is the same as STOP.
        ,'AFTER',0       # [YYYYMMDDHHMISS].[then template].[else template].[_1_].[_2_].[_3_]...[_n_] - Continues processing and optionally loads additional templates if current date is AFTER the partial date specified (date could be a token). False is the same as STOP.
        ,'SHOWON',0      # [YYYYMMDDHHMISS].[then template].[else template].[_1_].[_2_].[_3_]...[_n_] - Continues processing and optionally loads additional templates if current date is the partial date specified (date could be a token). False is the same as STOP.
        ,'DEBUG',0         # [RawFlag(1/0)][SearchTerm] - If RawFlag=0, show the contents of the token table in HTML table format, otherwise show without decoration - one per line.  SearchTerm restricts output
        ,'SHOWCOMMENTS',0  # [1/0] - Show the OML comments in the included pages, in escaped format; page flushing must be engaged with ! after the function name #OML![FUNCTION]#, otherwise comments could be assigned to tokens mistakenly
        ,'LOGSTATS',0      # [0-9] - Turn on/off Statistics - Level 0-9
        ,'SHOWSTATS',0     # [bHTML] - Show the summary statistics for Orbit
        ,'TIMER',0         # [] - Set and return the PAGE_TIME token for elapsed milliseconds (ms)
        ,'STOPTIMER',0     # [] - Return the elapsed milliseconds (ms) since the last STOPTIMER or TIMER
        ,'LICENSE',0       # [] - Shows the GNU GPLv3+ License statement
        ,'VERSION',0        # [short_flag] - Shows the running version of Orbit and OML (Orbit Markup Language). If short_flag = 1, show a compressed ver info
         #
        }
     #
     # OML TOKEN MODIFIERS - only affect display, not contents of hash
     #
    ,_TOKEN_MODIFIERS => {
         #
         # String Modifiers
         #
         '.trim'        # Trims the left and right \t \n <space>
        ,'.ltrim'       # Left Trim \t \n <space>
        ,'.rtrim'       # Right Trim \t \n <space>
        ,'.space'       # Replace multiple spaces with single space
        ,'.length'      # Returns length of Token value
        ,'.upper'       # Uppercase the Token value
        ,'.lower'       # Lowercase the Token value
        ,'.initcap'     # Initial Capitalize
        ,'.initname'    # Initial Capitalize with proper Name rules
        ,'.namecap'     # Same as .initname
         #
         # Existence Modifiers used for Boolean Conditions
         #
        ,'.0'           # Returns '0' if Token is null or blank
        ,'.1'           # Returns '1' if Token is null
        ,'.not'         # Returns the inverse of the Boolean value 0/1
        ,'.isnumber'    # Returns '1' if the  Token value is a Number
        ,'.exists'      # Returns '1' if the Token value exists (IS NOT NULL), '0' otherwise
        ,'.isnotnull'   # Same as .exists
        ,'.notexists'   # Returns '1' if the Token value does NOT exist (IS NULL), '0' otherwise
        ,'.isnull'      # Same as .notexists
        ,'.null'        # Returns 'NULL' if Token is null or blank
        ,'.eval'        # Evaluates and parses the Token value contents, returning boolean 0/1
         #
         # Modifiers
         #
        ,'.rows'        # Returns the number of rows (carriage returns, \n) in the data
        ,'.cols'        # Returns the max column length of all the lines
         #
         # HTML Modifiers
         #
        ,'.html'        # escape any HTML text for display
        ,'.raw'         # same as .html (older convention in Oracle)
        ,'.nbsp'        # Returns '&nbsp;' if the Token value is null
        ,'.tr'          # Translate special HTML characters for Form Gets
        ,'.checked'     # Returns 'CHECKED' if the boolean is 1 (true)
        ,'.checkbox'    # Returns the Token value of CHECK_ON or CHECK_OFF based on boolean evaluation
        ,'.notags'      # Replaces < with &lt; and > with &gt; and & with &amp;
        ,'.noparse'     # Replace # with &#035;, essentially showing Orbit Tokens unparsed
        ,'.noquote'     # Replace " with &quot;
        ,'.untag'       # Replace (&amp; &lt; &gt;) with (& < >)
        ,'.unparse'     # Replace &#035; with #
        ,'.unraw'       # Replace (&amp; &lt; &gt; &#035; &quot;) with (& < > # ")
        ,'.nohtml'      # Removes all HTML tags from the text
        ,'.jsquote'     # Escapes JavaScript code, such as double quote
        ,'.br'          # Changes all \n Carriage Returns to html <br>
        ,'.nowrap'      # Changes all spaces to &nbsp;
         #
         # Numeric Modifiers
         #
        ,'.sign'        # Returns -1 for negative numbers, 1 for positive, 0, or null
        ,'.round'       # Rounds the number to closest integer
        ,'.round2'      # Rounds to 2 decimal places (useful for currency), pads with 0
        ,'.round1'      # Rounds to 1 decimal place, pads with 0
        ,'.trunc'       # Truncates the number, returning integer
        ,'.abs'         # Absolute Value (converts negative to positive)
        ,'.ceil'        # Ceiling of the number
        ,'.floor'       # Floor of the number
        ,'.percent'     # Shows the number in percentage format, multiplying by 100 and adding %
        ,'.percent1'    # Shows percent with 1 decimal places, padding with 0
        ,'.percent2'    # Shows percent with 2 decimal places, padding with 0
         #
         # Custom Token Functions
         #
        ,'.oml<token>'  # OML User Defined Modifier, prefixed with OML. Shows the token named #OML<token># (defined prior to use). Reference token value internally as #OML#
         #
         # Token Action functions - affects token table
         #
        ,'.backup'      # Backup the TOKEN, setting existing value to TOKEN_BACK as default.  This is processed before other modifiers
        ,'.restore'     # # Restore the Backup value TOKEN_BACK to the TOKEN name, keeping the backup token.  This is processed after .backup before any other modifiers.

         # Caching Modifiers
        ,'.cache'       # Sets the Token cache flag so it will not be parsed further - returns Token value
        ,'.uncache'     # Unsets the Token cache flag - returns Token value
         #
         # Earth.Love Modifiers
         #
        ,'.earthify'    # Returns the text with HTML link tags (<a>) around words in the earth.love database
        ,'.love'        # Returns 'Love' if value is TRUE
         #
        #,'_Odd_Fix_'    # Comment in or out if you get "Odd number of elements in anonymous hash at Orbit.pm"
        }
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
#*  Scope           :   PUBLIC
#*
#*  Description     :   This procedure is used for displaying the OML Template
#******************************************************************************************
sub Orbit::ShowPage
{
  my ( $self, $Template ) = @_;
  my $U = $self->{_Utils};

  use Time::HiRes qw(time);
  # Log the start Time
  my $Time = time;
  $self->{_iStartTime} = int($Time*1000);

  my $TemplatePath = "";

  # Initialize template to PAGE token if defined
  $Template = "" if (!defined($Template));
  $Template = $self->Get_Token('PAGE') if ($Template eq "");

  #
  # Initialize Orbit (CGI)
  #
  $self->initOrbit();

  #
  # Get the Template File Path
  #
  $TemplatePath = $self->SearchTemplateDirs( $Template );

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
#* SetTemplateDir
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
#* SearchTemplateDirs
#* - Sets a Template Directory in the _TEMPLATEDIRS array
#******************************************************************************************
sub Orbit::SearchTemplateDirs
{
  my ( $self, $Template ) = @_;

  return "" if (!defined($Template) || $Template eq "");

  # Uppercase Template per standard
  $Template =~ tr/[a-z]/[A-Z]/;

  my $TemplFile = "";

  #
  # Search through all TEMPLATE PATHS to find OML Template
  #
  if (keys %{$self->{_TEMPLATEDIRS}} > 0) {
    # Loop through the template paths
    my $TemplateDir = "";
    foreach my $i (sort {$a <=> $b}(keys %{$self->{_TEMPLATEDIRS}}))
    {
      #
      # Check for special directives #WORDDIR# #ROOTDIR# #DOMAINDIR#
      #
      $TemplateDir = $self->{_TEMPLATEDIRS}->{$i};
      #
      if ($TemplateDir =~ /.*#_WORDDIR_#\/.*/i) {
        my $rep = $self->Get_Token('_WORDDIR_');
        $TemplateDir =~ s/#_WORDDIR_#\//$rep/i;
        #
      } elsif ($TemplateDir =~ /.*#_ROOTDIR_#\/.*/i) {
        my $rep = $self->{_RootDir};
        $TemplateDir =~ s/#_ROOTDIR_#\//$rep/i;
        #
      } elsif ($TemplateDir =~ /.*#_DOMAINDIR_#\/.*/i) {
        my $rep = $self->{_DomainDir};
        $TemplateDir =~ s/#_DOMAINDIR_#\//$rep/i;
      }
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
#*  Function Name   :   Eval <expression>
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Evaluates an Orbit OML expression and returns:
#*     - (1) TRUE : if the expression evaluates to TRUE, parses to 1, or contains
#*           only tokens which parse out to not null (ie existence test)
#*     - (0) FALSE: if the expression evaluates to FALSE or parses to 0
#*     - ""       : if the expression can not be parsed or invalid expression
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
#*  Procedure Name  :   Logon
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Validates the user/password and creates a User Access Log (session) record
#******************************************************************************************
sub Orbit::Logon
{
  my ( $self ) = @_;

  return "CODE Logon";
} #Logon


#******************************************************************************************
#*  Procedure Name  :   Logoff
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Logs a user out of their session (sets a flag on the user access log)
#*                      If next page is not specified, the LOGON_PAGE will be displayed
#******************************************************************************************
sub Orbit::Logoff
{
  my ( $self ) = @_;

  return "CODE Logoff";
} #Logoff


#******************************************************************************************
#*  Procedure Name  :   Change_Password
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Change a users password based on session stored in a cookie
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
#*  Procedure Name  :   ShowTokenTable
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Shows all the Token / Value combinations
#*                      This is used for debugging and can be called after Show_Page
#*                      or with the #DEBUG[<raw_text_flag>]# token function within any section
#*                      If fn_raw_format_flag = 0, the output will be in the form of an HTML table,
#*                      otherwise it will be in a raw format without decorations
#*                      bPrint (1/0) to print or just return output as value
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
#*  Procedure Name  :   ResetTokenTable
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Removes all Tokens from the Token Table
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
#*  Procedure Name  :   RegisterError
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the ERROR_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterError
{
  my ( $self, $String ) = @_;

  $self->Set_Token('ERROR_TEXT', $String);
} #RegisterError


#******************************************************************************************
#*  Procedure Name  :   RegisterSuccess
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the SUCCESS_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterSuccess
{
  my ( $self, $String ) = @_;

  $self->Set_Token('SUCCESS_TEXT', $String);
} #RegisterSuccess


#******************************************************************************************
#*  Procedure Name  :   RegisterMessage
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the MESSAGE_TEXT token to the specified string
#******************************************************************************************
sub Orbit::RegisterMessage
{
  my ( $self, $String ) = @_;

  $self->Set_Token('MESSAGE_TEXT', $String);
} #RegisterMessage


#******************************************************************************************
#*  Procedure Name  :   AppendError
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Appends a string to the ERROR_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendError
{
  my ( $self, $String, $Separator ) = @_;

  $self->Append_Token('ERROR_TEXT', $String, $Separator);
} #AppendError


#******************************************************************************************
#*  Procedure Name  :   AppendSuccess
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Appends a string to the SUCCESS_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendSuccess
{
  my ( $self, $String, $Separator ) = @_;

  $self->Append_Token('SUCCESS_TEXT', $String, $Separator);
} #AppendSuccess


#******************************************************************************************
#*  Procedure Name  :   AppendMessage
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Appends a string to the MESSAGE_TEXT token, using Separator to separate
#******************************************************************************************
sub Orbit::AppendMessage
{
  my ( $self, $String, $Separator ) = @_;

  $self->Append_Token('MESSAGE_TEXT', $String, $Separator);
} #AppendMessage


#******************************************************************************************
#*  Procedure Name  :   SetHeaderMessage
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets the HEADER_MESSAGE global token to be a combination of:
#*                      ERROR_TEXT, MESSAGE_TEXT, or SUCCESS_TEXT, whichever is set
#*                      The PROMPT_ERROR and PROMPT_SUCCESS tokens will be used if set
#******************************************************************************************
sub Orbit::SetHeaderMessage
{
  my ( $self ) = @_;

  #-- First reset the header message
  $self->Set_Token('HEADER_MESSAGE', "");
  #-- Get the ERROR_TEXT
  my $gv_buffer = $self->Get_Token('ERROR_TEXT');
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '#PROMPT_ERROR#'.
        '<B><I>'.$gv_buffer.'</I></B>');
  }
  #-- Get the MESSAGE_TEXT
  $gv_buffer = $self->Get_Token('MESSAGE_TEXT');
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '<B><I>'.$gv_buffer.'</I></B>');
  }
  #-- Get the SUCCESS_TEXT
  $gv_buffer = $self->Get_Token('SUCCESS_TEXT');
  if ($gv_buffer ne "") {
    $self->Append_Token('HEADER_MESSAGE',
        '#PROMPT_SUCCESS#'.
        '<B><I>'.$gv_buffer.'</I></B>');
  }

  return 0;
} #SetHeaderMessage


#******************************************************************************************
#*  Procedure Name  :   print
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Print the HTML text specified.  Use Oracle Web Server htp.p or
#*                      dbms_output.put if command_line is set ON
#*                      Set fb_no_carriage_return (1) to not print a trailing carriage return
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
#*  Procedure Name  :   Fatal_Error
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Called only when the standard page can not be displayed (ie. No version info).
#*                      Prints the text with very basic HTML in PRE-formatted output,
#*                      along with any ERROR_TEXT, MESSAGE_TEXT, and SUCCESS_TEXT.
#*                      If fn_dump_environment = 1, all Token and environment variables are also displayed.
#*                      The token SHOW_ENV_FLAG will override the fn_dump_environment if set to '0'
#*                      ie) If SHOW_ENV_FLAG = '0', the environment variables will not display
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
#*  Procedure Name  :   initOrbit
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Initialize Orbit before calling Show_Page from the command line
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

} #initOrbit


#******************************************************************************************
#*  Procedure Name  :   LoadEnvTokens
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Resets the internal cache tables and buffers
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
      ||$var eq 'SCRIPT_NAME'
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
      ||$var eq 'REQUEST_METHOD'
      ||$var eq 'GATEWAY_INTERFACE'
      ||$var eq 'AUTH_TYPE'
      #||1   # Hack: Uncomment to show all if needed
      ) {
      $value = $ENV{$var};
      $value =~ s/\n/\\n/g;
      $value =~ s/"/\\"/g;
      $self->Set_Token('ENV_'.$var, $value);
    }
  }

  # Set the special ENV_HOST token based on pieces
  if ($self->Get_Token('ENV_REQUEST_SCHEME') ne "") {
    if ($self->Get_Token('ENV_SERVER_PORT') eq '80'
      #-- only include port if not already on host
      || index($self->Get_Token('ENV_HTTP_HOST'), ':'.$self->Get_Token('ENV_SERVER_PORT')) == -1
      ) {
      $self->Set_Token('ENV_HOST', $self->Get_Token('ENV_REQUEST_SCHEME').'://'.$self->Get_Token('ENV_HTTP_HOST'));
    } else {
      $self->Set_Token('ENV_HOST', $self->Get_Token('ENV_REQUEST_SCHEME').'://'.$self->Get_Token('ENV_HTTP_HOST').':'.$self->Get_Token('ENV_SERVER_PORT'));
    }
  }
  return 0;
} #LoadEnvTokens


#******************************************************************************************
#*  Procedure Name  :   Reset_Cache
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Resets the internal cache tables and buffers
#******************************************************************************************
sub Orbit::Reset_Cache
{
  my ( $self ) = @_;

  return "CODE";
} #Reset_Cache


#******************************************************************************************
#* IsNumber <text>
#*
#* - Determines if string is a valid number.
#*   NULL is NOT a number
#******************************************************************************************/
sub Orbit::IsNumber
{
  my ( $self, $String ) = @_;
  # Null is not a number
  return 0 if (!defined($String) || $String eq "");
  return ($String =~ /^[-]*[0-9]*[\.]*[0-9]*$/)?1:0;
} #IsNumber


#========================================================================================
# END ORBIT SUBROUTINES
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Orbit6;
#******************************************************************************************
1;


#END Orbit::Orbit6;
