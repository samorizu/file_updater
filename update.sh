#!/bin/bash
#Authors: Jackson Sadowski and Luke Matarazzo
#Purpose: Grab files via SFTP or FTP, update them the way the user defines, and reupload them

if [ "$1" == "--help" -o "$1" == "-h" ]; then
	echo "CONFIGFILE - File with the text to be found, a tilde (~) on a line by itself and then the changes (temporary)."
	#echo "CONFIGFILE - Text file containing each file on the remote FTP server that needs to be updated. Each file should be on a separate line."
	echo "[DIRECTORY_OF_FILES] - Directory in which the files to be updated are (temporary)."
	echo
	echo "-h, --help - 	Prints this help information."
	echo "-f - 		Specifies the use of FTP rather than SFTP. SFTP is the default protocol for this program."
	echo "-s - 		Specifies the use of FTPS rather than SFTP. SFTP is the default protocol for this program."
	echo "-q, --quiet -	Enables quiet mode and prints very minimal output."
	echo
	echo "Exiting with a status of 1 usually means a general error, such as bad/missing arguments"
	echo "Exiting with a status of 2 means there was an ftp login error, exiting with a status of 3 means there was an ftp"
	echo "connection error."
	exit 0
fi

if [ $# -lt 1 ]; then
  echo "Usage: ./update.sh [CONFIGFILE] [options]"
  exit 1
fi

handleFiles(){
	if test -f $1.bak; then
		handleFiles $1.bak
	fi
}

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
temp=""

#read in and process config file data
while read line; do
	if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ]; then
		continue;
	fi
	key=`/bin/echo $line | /usr/bin/awk -F"=" '{print $1}'`
	val=`/bin/echo $line | awk -F"=" '{print $2}'`
	if [ "$key" == "files" ]; then
		((files_wanted++))
		#conf_values=([$key$files_wanted]="$val")
		conf_values[$key$files_wanted]="$val"
		#echo "${conf_values[$key$files_wanted]}"
	elif [ "$key" == "file" ]; then
		((file_wanted++))
		conf_values[$key$file_wanted]="$val"
	else
		temp="$key"
		#conf_values=([$key]="$val")
		conf_values[$key]="$val"
		#echo "${conf_values[$key]}"
	fi
done < $1

if test ! -e ${conf_values['changes_file']}; then
	echo "Please enter a changes file that exists"
	exit 1
fi

#echo "files wanted: $files_wanted"
#echo "value of local_directory: ${conf_values[local_directory]}"
# echo "value of changes_file: ${conf_values['changes_file']}"

#declare -a myKeys
# for key in ${!conf_values[*]}; do
# 	#myKeys=("$myKeys" "$key")
# 	echo "value for $key: ${conf_values[$key]}"
# done

#exit 0

for param in $@; do
	if [ ${param:0:1} == "-" ]; then
		ftp_option=${param:1:1}
		break
	fi
done

if test ! -d ${conf_values['local_directory']}; then
	/bin/mkdir ${conf_values['local_directory']}
fi

cd ${conf_values['local_directory']}

read -p "FTP host (example ftp.server.com): " host
read -p "FTP user: " user
read -s -p "FTP password: " pass
echo #get a newline after printing ftp password prompt

#get the files we want to get into two separate strings
files=""
file=""
for (( i = 1; i <= $files_wanted; i++ )); do
	files+="${conf_values["files$i"]} "
	#echo "files: ${conf_values["files$i"]}"
done
#echo "files: '$files'"
for (( i = 1; i <= $file_wanted; i++ )); do
	file+="${conf_values["file$i"]} "
	#echo "file: ${conf_values["file$i"]}"
done
#echo "file: '$file'"

if [ "$files" == "" -a "$file" == "" ]; then
	echo "You have not entered any files you want to download"
	exit 1
fi

if [ "$ftp_option" == "f" ]; then
	ftp -inv $host <<EOF >$ftp_out_file 2>$ftp_error_file
user $user $pass
cd ${conf_values['remote_directory']}
mget $files $file
bye
EOF
else
	echo "sftp not yet implemented"
	exit 0
# 	sftp -inv $host <<EOF >>$ftp_out_file 2>>$ftp_error_file
# user $user $pass
# cd ${conf_values['remote_directory']}
# mget $files $file
# bye
# EOF
fi

loginFail=`/bin/grep -i "Login failed" $ftp_out_file`
error=$loginFail
status=2
connectionFail=`/bin/grep -i "connection timed out" $ftp_error_file`

if [ "$connectionFail" != "" ]; then
	error=$connectionFail
	status=3
fi

if [ "$error" != "" ]; then
	echo "Error: $error" >&2
	exit $status
fi

#exit 0

#get files in a variable and go back to original directory that we started in
list=`/bin/ls`
#cd $path
num_files=0

#loop through list of files perform manipulations of each file
for file in $list; do
	handleFiles $file
	/bin/cp $file $file.bak #make backup
	$path/manipulator.pl $path/${conf_values['changes_file']} < $file > $file.new #manipulate file and put it at $file.new
	result=`/bin/cat $file.new` #get what's in the newly manipulated file
	if [ "$result" != "" ]; then
		num_files+=1
		/bin/rm $file
		/bin/mv $file.new $file
	else
		/bin/rm $file.new
		/bin/mv $file.bak $file
	fi
done

#go back to directory with downloaded and edited files in it and upload the new files
#cd ${conf_values['local_directory']}
ftp -inv $host <<EOF >> $ftp_out_file 2>>$ftp_error_file
user $user $pass
cd ${conf_values['remote_directory']}
mput $files $file
bye
EOF
#cd ..

if [ $num_files -gt 0 ]; then
	echo "All eligible files were uploaded successfully."
else
	echo "No files were copied. Maybe none of them met the criterion." 1>&2
	exit 1
fi

exit 0

read -p "Would you like to revert all or some files (A/S/N): " choice
choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
if [ "$choice" = "A" -o "$choice" = "ALL" ]; then
	for file in $files; do
		if test -e $file.bak; then
			/bin/mv $file.bak $file
		fi
	done
elif [ "$choice" = "S" -o "$choice" = "SOME" ]; then
	for file in $files; do
		if test -e $file.bak; then
			read -p "Would you like to revert $file (Y/N): " choice
			choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
			if [ "$choice" = "Y" -o "$choice" = "YES" ]; then
				/bin/mv $file.bak $file
			fi
		fi
	done
fi

#cd $2
files=`/bin/echo *.rev`
for file in $files; do
	$protocol -inv $host <<EOF
	user $user $pass
	cd testing
	put $file ${file:0:${#file}-4}
	bye
EOF
done >> $ftp_out_file 2>>ftp_error_file
#cd ..

echo "All reverted files uploaded successfully."
