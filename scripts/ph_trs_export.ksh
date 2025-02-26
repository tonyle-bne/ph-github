#!/bin/ksh
# Program   :  ph_trs_export.ksh
# Title     :  PH Data Export
#
# Programmer:  Tony Baisden
# Date      :  9 August 2004
#
# Purpose   :  This program is based on ph_export.ksh and is used to export 
#              ph data to macaw (the trs machine)
#
#                                   Modification History
# ****************************************************************************
# Programmer: Tony Baisden
# Date      : 9 August 2004
# Change    : Created script based on existing ph_export script.  
#
# Programmer: Jason Smith
# Date      : 10 December 2004
# Change    : Convert ftp call to sftp.
#           : Added create_temp_file, transfer_files and add_command functions.
#
# 06-Apr-2005  M Huth   Changed "bye" to "quit" in sftp command to adhere to
#                       requirements in future OS version.
#			Added in sftp_status variable and IF to cater for when
#			the sftp fails and send on an email to relevant people. 
#
# 07-Jun-2006 E Wood    Added the alternative export that uses a new delimiter.
# 25-Sep-2006 M Huth  Changed sftp location
# 14 Jun 2011 J Choy  Removed conditional email and made it send regardless at the end
# 25 Jul 2012 T Le    Add single quote when referencing the function create_temp_file to create tempfile
# ****************************************************************************
#



# Initialise Production Environment Variables.
if [ "$1" != "" ]; then
  ORACLE_SID=$1; export ORACLE_SID
  ORAENV_ASK=NO; export ORAENV_ASK
  . /opt/app/qv/local/qvenv
fi

logfile="ph_trs_export."`date '+%y%m%d.%H%M.log'`;     	export logfile
logpath="$LOGS/$logfile";                               export logpath

email_recipients="qv-maint@qut.edu.au"; 	

# Redirect all output (stdout and stderr) to a log file.
exec 1> $logpath; exec 2>&1

echo $logpath
echo "Job: ph_trs_export.ksh"
echo 
echo "#############################################################################"
echo "## PH Export Script -> Populates 2 files in $DATA                          ##"
echo "## ph_trs_exporrt3.lis and ph_trs_export3_alt.lis                          ##"
echo "## and then ftps them to macaw.qut.edu.au                                  ##"
echo "#############################################################################" 
echo


echo
echo "Step 1: (`date`)"
echo "Extract data to file ph_trs_export3.lis ."
echo
echo "sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_trs_export.sql"
if ! sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_trs_export.sql
then
   echo "Bad exit from sqlplus ph_trs_export.sql.        (`date`)"
   exit 1
fi

echo
echo "Step 2: (`date`)"
echo "Extract data to file ph_trs_export3_alt.lis ."
echo
echo "sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_trs_export_alt.sql"
if ! sqlplus -s $QVMGR_CREDENTIAL @$SQL/ph_trs_export_alt.sql
then
   echo "Bad exit from sqlplus ph_trs_export_alt.sql.        (`date`)"
   exit 1
fi

#------------------------------------------------------------------------------
function create_temp_file
{
   tempfile="/tmp/`basename $0`_cmd.$$"
   rm -f $tempfile
   touch $tempfile
#   trap "/bin/rm -f $tempfile" 0
#   echo $tempfile
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
echo "Step 3: (`date`)"
echo "Make sure extract worked and rename file."
if [ -s $DATA/ph_trs_export3.lis ]
then
        get_connection_details TRS 
 
        # Create temporary file
        tempfile=`create_temp_file`
               
	# Set batch commands
        add_command  "put $DATA/ph_trs_export3.lis ph_data.txt" 
        add_command  "quit"
 
        # Transfer file to TRS 
        transfer_files 
	
        
else
   echo "PH data file is empty or does not exist."
   exit 1
fi

#------------------------------------------------------------------------------
echo
echo "Step 4: (`date`)"
echo "Make sure extract worked and rename file."
if [ -s $DATA/ph_trs_export3_alt.lis ]
then
        get_connection_details TRS

        # Create temporary file
        tempfile=`create_temp_file`

        # Set batch commands
        add_command  "put $DATA/ph_trs_export3_alt.lis ph_data_alt.txt"
        add_command  "quit"

        # Transfer file to TRS
        transfer_files

else
   echo "PH alternate data file is empty or does not exist."
   exit 1
fi

   mailx -s "[LOG] $logfile" $email_recipients < $LOGS/$logfile

exit 0
