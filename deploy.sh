#!/bin/bash

if [ $# -gt 1 ]; then
	echo "Bad usage"
	exit 48
fi

if [ $# -eq 1 ]; then
	SETTINGS_FILE=$1
else
	DIR=`dirname "$0"`
	SETTINGS_FILE=$DIR/deploy_settings.sh
fi

if [ ! -e $SETTINGS_FILE ]; then
	echo "Cannot find settings file. Expected location: $SETTINGS_FILE"
	exit 47
fi

SETTINGS_FILE_OK=0
source "$SETTINGS_FILE"
if [ $SETTINGS_FILE_OK -eq 1 ]; then
	echo "***** Settings file OK"
else
	echo "***** Unable to parse settings file $SETTINGS_FILE" >&2
	exit 123
fi

delete_lock_file_and_exit() {
	# Delete lock file
	rm $LOCK_FILE
	if [ $? -eq 0 ]; then
		echo "***** Lock file deleted successfully."
	else
		echo "***** Failed to delete lock file." >&2
		exit 666
	fi

	exit $1	
}

# Create release name
releasename="release-`date +%Y%m%d%H%M%S`"

# Check that release path exists
if [ ! -e $EXPORT_TARGET ]; then
	echo "***** Export target $EXPORT_TARGET does not seem to exist. Aborting."
	exit 46
fi

# Ask user to confirm
echo "*********************************"
echo "This is what I'll do:"
echo "touch $LOCK_FILE"
echo "svn up $RELEASE_WC"
echo "svn export $RELEASE_WC $EXPORT_TARGET/$releasename"
echo "rm $SYMLINK_PATH"
echo "ln -s $EXPORT_TARGET/$releasename $SYMLINK_PATH"
# Check old releases
dirs=`ls $EXPORT_TARGET`
dir_count=`echo $dirs|wc -w`
num_delete=$(($dir_count-8))
if [ $num_delete -gt 0 ]; then
	deleted=0
	for dir in `echo $dirs`; do
		echo "rm -rf $EXPORT_TARGET/$dir"
		deleted=$(($deleted+1))
		if [ $deleted -eq $num_delete ]; then
			break
		fi
	done
fi
echo "rm $LOCK_FILE"
echo "*********************************"
answer="fail"
#until (( "$answer" == "yes" )) || (( "$answer" == "no" )); do
until [ "$answer" == "yes" ]; do
	echo "Do you wish to continue? Please answer with yes or no."
	read answer
	if [ "$answer" == "no" ]; then
		echo "Aborting."
		exit 45
	fi
done

# Check for lock file
if [ -e $LOCK_FILE ]; then
        echo "***** Lock file $LOCK_FILE exists, bailing out." >&2
        exit 1
fi

# Create lock file
touch $LOCK_FILE
if [ $? -eq 0 ]; then
	echo "***** Lock file created"
else
	echo "***** Unable to create lock file" >&2
	exit 2
fi

# Update checkout
svn up $RELEASE_WC
if [ $? -eq 0 ]; then
	echo "***** Update completed"
else
	echo "***** Unable to do 'svn up'" >&2
	delete_lock_file_and_exit 3
fi


# Export
svn export $RELEASE_WC $EXPORT_TARGET/$releasename
if [ $? -eq 0 ]; then
        echo "***** Export created"
else
        echo "***** Unable to create export" >&2
        delete_lock_file_and_exit 4
fi

# Delete symlink
rm $SYMLINK_PATH
if [ $? -eq 0 ]; then
        echo "***** Production symlink deleted"
else
        echo "***** Unable to delete production symlink" >&2
        delete_lock_file_and_exit 5
fi

# create symlink
ln -s $EXPORT_TARGET/$releasename $SYMLINK_PATH
if [ $? -eq 0 ]; then
        echo "***** Production symlink created"
else
        echo "***** Unable to create production symlink" >&2
        delete_lock_file_and_exit 6
fi

# Delete old releases
echo "***** Checking for old releases to remove"
dirs=`ls $EXPORT_TARGET`
dir_count=`echo $dirs|wc -w`
num_delete=$(($dir_count-8))
if [ $num_delete -gt 0 ]; then
	deleted=0
	for dir in `echo $dirs`; do
		echo "rm -rf $EXPORT_TARGET/$dir"
		rm -rf $EXPORT_TARGET/$dir
		deleted=$(($deleted+1))
		if [ $deleted -eq $num_delete ]; then
			break
		fi
	done
fi

# Yay, done!
echo "***** Done."
delete_lock_file_and_exit 0
