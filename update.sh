#!/bin/bash
#Authors: Luke Matarazzo and Jackson Sadowski
#Purpose: Grab files via SFTP or FTP, update them the way the user defines, and reupload them

if [ "$1" == "--help" -o "$1" == "-h" ]; then
	# echo "CONFIGFILE - File with the text to be found, a tilde (~) on a line by itself and then the changes (temporary)."
	echo "Sample usage: ./update.sh [options] [CONFIGFILE] [options]"
	echo "CONFIGFILE - Text file containing configuration for this script. Sample default configuration file provided as file_updater.conf"
	echo "[DIRECTORY_OF_FILES] - Directory in which the files to be updated are (temporary)."
	echo
	echo "-h, --help - 	Prints this help information."
	echo "-f - 		Specifies the use of FTP rather than SFTP. SFTP is the default protocol for this program."
	#echo "-q, --quiet -	Enables quiet mode and prints very minimal output."
	echo
	echo "Exiting with a status of 1 usually means a general error, such as bad/missing arguments"
	echo "Exiting with a status of 2 means there was a login error, exiting with a status of 3 means there was a"
	echo "connection error, and exiting with a status of 4 means one or more files or directories did not exist on the"
	echo "remote file server."
	exit 0
fi

#function to handle backup files so that nothing is overwritten and an additional .bak is appended to previously
#existing backup files
handleFiles(){
	if test -f $1.bak; then
		if test -f $1.bak.bak; then
			handleFiles $1.bak
		fi
	fi
	/bin/cp $1 $1.bak
}

#function to prompt user for a given value
getValue(){
	read -p "$1" tempVal #prompt for value
	while [ "$tempVal" == "" ]; do #if not given, prompt again
		echo "You cannot leave this value blank..." >&2
		read -p "$1" tempVal
	done

	echo "$tempVal" #return value
}

#function to prompt user for a given value
getPassword(){
	read -s -p "Enter password: " tempVal #prompt for value
	while [ "$tempVal" == "" ]; do #if not given, prompt again
		echo >&2
		echo "You cannot leave this value blank..." >&2
		read -s -p "Enter password: " tempVal
	done

	echo "$tempVal" #return value
}

#set some variables used in the program
path=`/bin/pwd`
ftp_out_file="$path/.file_updater_ftp_output.log"
ftp_error_file="$path/.file_updater_ftp_error.log"
declare -A conf_values
#remote directory: ${conf_values['remote_directory']}
#local directory: ${conf_values['local_directory']}
#changes text file: ${conf_values['changes_file']}
#file: ${conf_values["file$i"]}
#files: ${conf_values["files$i"]}
files_wanted=0
file_wanted=0
files=""

#if there are command line arguments, find ftp option if given
if [ $# -ge 1 ]; then
	#find option, figure out whether it's f or s and store in variable
	counter=0 #counter
	for param in $@; do
		counter+=1
		if [ ${param:0:1} == "-" ]; then
			ftp_option=${param:1:1}
			if [ 1 -eq $counter ]; then
				shift
			fi
			break
		fi
	done
fi

#if there is still a command line argument, that means they gave a config file
if [ $# -ge 1 ]; then
	if test ! -e $1; then #make sure given config file exists
		echo "Please enter a configuration file that exists"
		exit 1
	fi

	#read in and process config file data
	while read line; do
		if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ]; then
			continue;
		fi
		key=`/bin/echo $line | /usr/bin/awk -F"=" '{print $1}'`
		val=`/bin/echo $line | awk -F"=" '{print $2}'`
		if [ "$key" == "files" ]; then
			((files_wanted++))
			conf_values[$key$files_wanted]="$val"
		elif [ "$key" == "file" ]; then
			((file_wanted++))
			conf_values[$key$file_wanted]="$val"
		else
			conf_values[$key]="$val"
		fi
	done < $1

	#get the files we want to get into one string
	for (( i = 1; i <= $files_wanted; i++ )); do
		files+="${conf_values["files$i"]} "
	done
	for (( i = 1; i <= $file_wanted; i++ )); do
		files+="${conf_values["file$i"]} "
	done
else #they did not enter any command line arguments so no config file, prompt for info
	conf_values['local_directory']=$(getValue "Enter local directory: ")
	conf_values['remote_directory']=$(getValue "Enter remote directory: ")
	conf_values['changes_file']=$(getValue "Enter the changes file: ")
	read -p "Enter file you want to download and change: " temp
	while [ "$temp" != "" ]; do
		files+="$temp "
		read -p "Enter file you want to download and change (leave blank when done): " temp
	done
fi


if [ "$files" == "" ]; then #if they didn't give any files to change/download, print error and quit
	echo "You have not entered any files you want to download"
	exit 1
fi

#test some values given
if test ! -e ${conf_values['changes_file']}; then #check if given changes file exists
	echo "Please enter a changes file that exists"
	exit 1
fi

if test ! -d ${conf_values['local_directory']}; then #check if local directory given exists
	/bin/mkdir ${conf_values['local_directory']}
fi

cd ${conf_values['local_directory']}

#prompt for user and server info
host=$(getValue "Enter host (example ftp.server.com): ")
user=$(getValue "Enter user: ")
pass=""

if [ "$ftp_option" == "f" ]; then #ftp
	# read -s -p "FTP password: " pass #prompt for password
	# read -s -p "Password: " pass #prompt for password
	pass=$(getPassword) #prompt
	echo #put a newline after the password prompt
	ftp -inv $host <<EOF >$ftp_out_file 2>$ftp_error_file
user $user $pass
cd ${conf_values['remote_directory']}
mget $files
bye
EOF
	otherFail=`/bin/grep -i "550" $ftp_out_file` #check if file or directory was missing
else #sftp
	sftp -oBatchMode=no -b - $user@$host <<EOF >$ftp_out_file 2>$ftp_error_file
cd ${conf_values['remote_directory']}
mget $files
bye
EOF
	otherFail=`/bin/grep -i "no such" $ftp_out_file` #check if file or directory was missing
fi

#check for errors
loginFail=`/bin/grep -i "Login failed" $ftp_out_file`
error=$loginFail
status=2
connectionFail=`/bin/grep -i "connection timed out" $ftp_error_file`

if [ "$connectionFail" != "" ]; then #check for connection failure
	error=$connectionFail
	status=3
elif [ "$otherFail" != "" ]; then #check for missing file or directory error
	error=$otherFail
	status=4
fi

if [ "$error" != "" ]; then #if there was an ftp error, print error message and exit
	echo "Error: $error" >&2
	exit $status
fi

echo "Files successfully downloaded from server." #print success message

#get files in a variable and go back to original directory that we started in
list=`/bin/ls`
num_files=0

#loop through list of files perform manipulations of each file
for file in $list; do
	if [[ "$file" =~ ".bak" ]]; then
		continue
	fi
	handleFiles $file
	$path/manipulator.pl $path/${conf_values['changes_file']} < $file > $file.new #manipulate file and put it at $file.new
	result=`/bin/cat $file.new` #get what's in the newly manipulated file
	if [ "$result" != "" ]; then
		((num_files++))
		/bin/rm $file
		/bin/mv $file.new $file
	else
		/bin/rm $file.new
		/bin/mv $file.bak $file
	fi
done

#upload new files
if [ "$ftp_option" == "f" ]; then #ftp
	ftp -inv $host <<EOF >>$ftp_out_file 2>>$ftp_error_file
user $user $pass
cd ${conf_values['remote_directory']}
mput $files
bye
EOF
else #sftp
	echo "Attempting to upload files to server..."
	sftp -oBatchMode=no -b - $user@$host <<EOF >>$ftp_out_file 2>>$ftp_error_file
cd ${conf_values['remote_directory']}
mput $files
bye
EOF
fi

#check for errors
loginFail=`/bin/grep -i "Login failed" $ftp_out_file`
error=$loginFail
status=2
connectionFail=`/bin/grep -i "connection timed out" $ftp_error_file`

if [ "$connectionFail" != "" ]; then #check for connection failure
	error=$connectionFail
	status=3
fi

if [ "$error" != "" ]; then #if there was an ftp error, print error message and exit
	echo "Error: $error" >&2
	exit $status
fi

if [ $num_files -gt 0 ]; then
	echo "All eligible files were uploaded successfully."
else
	echo "No files were successfully altered. Maybe none of them met the criterion." 1>&2
	exit 1
fi

#ask if user wants to revert some or all of files. if some, figure out which
filesToRevert=""
read -p "Would you like to revert all or some files (A/S/N): " choice
choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
if [ "$choice" = "A" -o "$choice" = "ALL" ]; then #revert all
	for file in $files; do
		if test -e $file.bak; then
			/bin/mv $file.bak $file
		fi
	done
	filesToRevert="$files"
elif [ "$choice" = "S" -o "$choice" = "SOME" ]; then #revert some
	for file in $files; do
		if test -e $file.bak; then
			read -p "Would you like to revert $file (Y/N): " choice
			choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
			if [ "$choice" = "Y" -o "$choice" = "YES" ]; then
				/bin/mv $file.bak $file
				filesToRevert+="$file "
			fi
		fi
	done
fi

#upload reverted files
if [ "$filesToRevert" != "" ]; then
	if [ "$ftp_option" == "f" ]; then #ftp
		ftp -inv $host <<EOF >> $ftp_out_file 2>>$ftp_error_file
user $user $pass
cd ${conf_values['remote_directory']}
mput $filesToRevert
bye
EOF
	else #sftp
		sftp -oBatchMode=no -b - $user@$host <<EOF >>$ftp_out_file 2>>$ftp_error_file
cd ${conf_values['remote_directory']}
mput $filesToRevert
bye
EOF
	fi

	#check for errors
	loginFail=`/bin/grep -i "Login failed" $ftp_out_file`
	error=$loginFail
	status=2
	connectionFail=`/bin/grep -i "connection timed out" $ftp_error_file`

	if [ "$connectionFail" != "" ]; then #check for connection failure
		error=$connectionFail
		status=3
	fi

	if [ "$error" != "" ]; then #if there was an ftp error, print error message and exit
		echo "Error: $error" >&2
		exit $status
	fi

	echo "All reverted files uploaded successfully." #print success message
fi


