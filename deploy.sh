#!/bin/bash

DIR=`dirname "$0"`
SETTINGS_FILE=$DIR/deploy_settings.sh

if [ ! -e $SETTINGS_FILE ]; then
	echo "Cannot find settings file. Expected location: $SETTINGS_FILE"
	exit 47
fi

eval $($SETTINGS_FILE)
if [ $? -eq 0 ]; then
	echo "***** Settings file eval OK"
else
	echo "***** Unable to eval settings file $SETTINGS_FILE" >&2
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
	delete_lock_file_and_exit 2
fi

# Update checkout
svn up $RELEASE_WC
if [ $? -eq 0 ]; then
	echo "***** Update completed"
else
	echo "***** Unable to do 'svn up'" >&2
	delete_lock_file_and_exit 3
fi

# Create release name
releasename="release-`date +%Y%m%d%H%M%S`"

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
dirs=`ls $EXPORT_TARGET|sort -r`
dir_count=`echo $dirs|wc -w`
num_delete=$(($dir_count-8))
if [ $num_delete -gt 0 ]; then
	for dir in `echo $dirs|tail -n $num_delete`; do
		echo "Deleting $dir"
		rm -rf $dir
		if [ $? -ne 0 ]; then
			echo "***** Unable to delete $dir" >&2
		fi
	done
fi

# Yay, done!
echo "***** Done."
delete_lock_file_and_exit 0
