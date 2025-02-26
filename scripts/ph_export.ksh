#!/bin/ksh
# Program   :  ph_export.ksh
# Title     :  PH Data Export
#
# Programmer:  P.Deacon
# Date      :  30-Oct-95
#
# Purpose   :  This program controls the extraction of the data file used
#              by the PH server and Phonebook.
#
#                                   Modification History
# ****************************************************************************
## HISTORY DELETED
#
# Programmer: Trajan Goldsworthy
# Date      : 11 September 2003
# Change    : Changed log file name to new standard format: program_name.yymmdd.hhmm.log
#
# Programmer: Jason Smith
# Date      : 10 December 2004
# Change    : Convert rcp calls to scp.
#           : Added create_temp_file, transfer_files and add_command functions.
#
# 02-Feb-2005  M Huth   Fixed name of ftped file from "h_export3.lis" to "ph_export3.lis"
# 18-Mar-2005  M Huth   Changed "bye" to "quit" in sftp commands to adhere to
#                       requirements in future OS version.
#
# 07-Jun-2006 E Wood    Removed the ldap file generation as the service is
#                       decomissioned.
# 18-Sep-2006 E Wood    Removed commented out code that is uneeded.
# 25-Sep-2006 M Huth	Changed sftp location
# 30-Apr-2007 E Wood    Added a new sftp destination as per net apps request.
# 16-Jun-2007 E Wood    Fixed file transfer to bellflower to use the same tempfile
#                       created in the previous step.
# 23-Jun-2007 J Choy    Bustard is decommisioned. SFTP to bustard removed.
# 05 Jul 2011 J Choy    Add command to send email of log
# 08 Jul 2011 J Choy    Convert to UNIX file format
# 25 Jul 2012 T Le    Add single quote when referencing the function create_temp_file to create tempfile
# 31 Aug 2012 J Choyh   Change name of tempfile which executes ftp commands. it was named the same as another script and so, was getting overwritten.
# ****************************************************************************
#

# Initialise Production Environment Variables.
if [ "$1" != "" ]; then
  ORACLE_SID=$1; export ORACLE_SID
  ORAENV_ASK=NO; export ORAENV_ASK
  . /opt/app/qv/local/qvenv
fi

logfile="ph_export."`date '+%y%m%d.%H%M.log'`;     export logfile
logpath="$LOGS/$logfile";                               export logpath
email_recipients="qv-support@qut.edu.au"; 	

# Redirect all output (stdout and stderr) to a log file.
exec 1> $logpath; exec 2>&1

echo "#############################################################################"
echo "## PH Export Script -> Populates 1 file in $DATA                           ##"
echo "## ph_exporrt3.lis                                                         ##"
echo "## and then uses sftp to transfer the file to bellflower.qut.edu.au        ##"
echo "#############################################################################"
echo

echo
echo "Step 1: (`date`)"
echo "Extract data to file ph_export3.lis ."
echo
echo "sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_export3.sql"
if ! sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_export3.sql
then
   echo "Bad exit from sqlplus ph_export3.sql.        (`date`)"
   exit 1
fi

#------------------------------------------------------------------------------
function create_temp_file
{
   tempfile="/tmp/`basename $0`_bellflower_cmd.$$"
   rm -f $tempfile
   touch $tempfile
}

#------------------------------------------------------------------------------
function transfer_files
{
   /usr/bin/sftp -b $tempfile $USER@$HOST
}

#------------------------------------------------------------------------------
function add_command
{
   echo $1 >> $tempfile
}

#------------------------------------------------------------------------------

echo
echo "Step 2: (`date`)"
echo "Make sure extract worked and export the file."
if [ -s $DATA/ph_export3.lis ]
then
   # Send file to bellflower
   get_connection_details BELLFLOWER
   tempfile=create_temp_file
   add_command "cd /web/phdata"
   add_command "put $DATA/ph_export3.lis ph_export3.lis"
   add_command "quit"
   transfer_files

   rm -f $tempfile
else
   echo "PH data file is empty or does not exist."
   exit 1
fi

mailx -s "[LOG] $logfile" $email_recipients < $LOGS/$logfile

exit 0

