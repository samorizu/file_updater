#!/bin/bash
#Authors: Jackson Sadowski and Luke Matarazzo
#Purpose: Grab files via SFTP or FTP, update them the way the user defines, and reupload them

if [ $1 = "--help" ]; then
	echo "Printing help information"
	echo "CONFIGFILE - File with the text to be found, a tilde (~) on a line by itself and then the changes (temporary)."
	#echo "CONFIGFILE - Text file containing each file on the remote FTP server that needs to be updated. Each file should be on a separate line."
	echo "[DIRECTORY_OF_FILES] - Directory in which the files to be updated are (temporary)."
	echo "-f - Specifies the use of FTP rather than SFTP. SFTP is the default protocol for this program."
	echo "-s - Specifies the use of FTPS rather than SFTP. SFTP is the default protocol for this program."
	exit 0
fi

if [ $# -lt 1 ]; then
  echo "Usage: ./update.sh [CONFIGFILE] [options]"
  exit 1
fi

path=`pwd`
ftp_out_file="$path/.file_updater_ftp_output.log"
ftp_error_file="$path/.file_updater_ftp_error.log"
declare -A conf_values
files_wanted=0
temp=""

while read line; do
	if [ "${line:0:1}" == "#" -o "${line:0:1}" == "" ]; then
		continue;
	fi
	key=`echo $line | awk -F"=" '{print $1}'`
	val=`echo $line | awk -F"=" '{print $2}'`
	if [ "$key" == "files" ]; then
		((files_wanted++))
		#conf_values=([$key$files_wanted]="$val")
		conf_values[$key$files_wanted]="$val"
		#echo "${conf_values[$key$files_wanted]}"
	else
		temp="$key"
		#conf_values=([$key]="$val")
		conf_values[$key]="$val"
		#echo "${conf_values[$key]}"
	fi
done < $1

echo "files wanted: $files_wanted"
echo "value of local_directory: ${conf_values[local_directory]}"

#echo "${!address[*]}"   # The array indices ...
for key in ${!conf_values[*]}; do
	echo "value for $key: ${conf_values[$key]}"
done

exit 0

for param in $@; do
	if [ ${param:0:1} == "-" ]; then
		ftp_option=${param:1:1}
		break
	fi
done

if test ! -d $2; then
	mkdir $2
fi

cd $2

read -p "FTP host (example ftp.server.com): " host
read -p "FTP user: " user
read -s -p "FTP password: " pass

if [ "$ftp_option" == "f" ]; then
	protocol=ftp
elif [ "$ftp_option" == "s" ]; then
	protocol=ftps
else
	export SSHPASS=$pass
	sshpass -e sftp -oBatchMode=no -b - $user@$host << !
	   put file.txt
	   bye
!
fi

#Uses the ftp command with the -inv switches. -i turns off interactive prompting. -n Restrains FTP from attempting the auto-login feature. -v enables verbose and progress.
$protocol -inv $host <<EOF >$ftp_out_file 2>$ftp_error_file
user $user $pass
cd testing
mget *.asp
bye
EOF
exit 0
echo "get here"

cd ..
files=`ls $2`
num_files=0

for file in $files; do
	cp $2/$file $2/$file.bak
	$path/manipulator.pl $1 < $2/$file > $2/$file.new
	result=`cat $2/$file.new`
	if [ "$result" != "" ]; then
		num_files=$num_files+1
		rm $2/$file
		mv $2/$file.new $2/$file
	else
		rm $2/$file.new
		mv $2/$file.bak $2/$file
	fi
done

cd $2
$protocol -inv $host <<EOF >> $ftp_out_file 2>>ftp_error_file
user $user $pass
cd testing
mput *.asp
bye
EOF
cd ..

if [ $num_files -gt 0 ]; then
	echo "All eligible files were uploaded successfully."
else
	echo "No files were copied. Maybe none of them met the criterion." 1>&2
	exit 1
fi
read -p "Would you like to revert all or some files (A/S/N): " choice
choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
if [ "$choice" = "A" -o "$choice" = "ALL" ]; then
	for file in $files; do
		if test -e $2/$file.bak; then
			mv $2/$file.bak $2/$file
		fi
	done
elif [ "$choice" = "S" -o "$choice" = "SOME" ]; then
	for file in $files; do
		if test -e $2/$file.bak; then
			read -p "Would you like to revert $file (Y/N): " choice
			choice=`echo $choice | tr '[:lower:]' '[:upper:]'`
			if [ "$choice" = "Y" -o "$choice" = "YES" ]; then
				mv $2/$file.bak $2/$file
			fi
		fi
	done
fi

cd $2
files=`echo *.rev`
for file in $files; do
	$protocol -inv $host <<EOF
	user $user $pass
	cd testing
	put $file ${file:0:${#file}-4}
	bye
EOF
done >> $ftp_out_file 2>>ftp_error_file
cd ..

echo "All reverted files uploaded successfully."
