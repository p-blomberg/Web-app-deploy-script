#!/bin/bash

# nullglob is required for globbing release-list (if no releases exists)
shopt -s nullglob

################ Functions ###########################

update_repo_cmd() {
	case $VCS in
		svn)
			echo "svn up \"$RELEASE_WC\""
			;;
		git)
			echo "(cd \"$RELEASE_WC\"; git pull)"
			;;
	esac
}

export_repo_cmd() {
	case $VCS in
		svn)
			echo "svn export \"$RELEASE_WC\" \"$EXPORT_TARGET/$releasename\""
			;;
		git)
			echo "(cd \"$RELEASE_WC\"; git checkout-index -a -f --prefix=\"$EXPORT_TARGET/$releasename/\" )"
			;;
	esac
}

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

function symlink_update() {
		local src=$1
		local dst=$2
		
		# remove old symlink
		if [[ -e $dst ]]; then
				rm $dst
				if [[ $? -ne 0 ]]; then
						echo "***** Unable to delete production symlink" >&2
						delete_lock_file_and_exit 5
				fi
		fi
		
		# create new symlink
		ln -s $src $dst
		if [ $? -eq 0 ]; then
				echo "***** Production symlink created"
		else
				echo "***** Unable to create production symlink" >&2
				delete_lock_file_and_exit 6
		fi
}

############## END FUNCTIONS ####################3

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


# Create release name
releasename="${releaseprefix:-release}-`date +%Y%m%d%H%M%S`"

# Check that release path exists
if [ ! -e $EXPORT_TARGET ]; then
	echo "***** Export target $EXPORT_TARGET does not seem to exist. Aborting."
	exit 46
fi

# Check vcs that we support selected vcs:
case $VCS in
svn)
	echo "***** Using SVN"
	;;
git)
	echo "***** Using GIT"
	;;
*)
	echo "***** Unknown vcs specifed: $VCS. Aborting."
	exit 49
esac

# abort if the working copy doesn't exist
if [ ! -e ${RELEASE_WC} ]; then
		echo "$0: Working copy '${RELEASE_WC}\` does not exist" > /dev/stderr
		exit 1
fi

# Create list of old releases to an array called "prune"
releases=($EXPORT_TARGET/${prefix:-release}-* $EXPORT_TARGET/$releasename)
prune=()
while [[ ${#releases[*]} -gt 8 ]]; do
		# pop first element from array, store it in "prune"
		prune+=(${releases[0]})
		releases=(${releases[@]:1})
done

# Ask user to confirm
echo "*********************************"
echo "This is what I'll do:"
echo "touch $LOCK_FILE"
update_repo_cmd
export_repo_cmd
echo "rm $SYMLINK_PATH"
echo "ln -s $EXPORT_TARGET/$releasename $SYMLINK_PATH"
for dir in ${prune[@]}; do
		echo "rm -rf $dir"
done
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
eval `update_repo_cmd`
if [ $? -eq 0 ]; then
	echo "***** Update completed"
else
	echo "***** Unable to do update local repository" >&2
	delete_lock_file_and_exit 3
fi


# Export
eval `export_repo_cmd`
if [ $? -eq 0 ]; then
        echo "***** Export created"
else
        echo "***** Unable to create export" >&2
        delete_lock_file_and_exit 4
fi

# update symlink
symlink_update $EXPORT_TARGET/$releasename $SYMLINK_PATH

# Delete old releases
echo "***** Checking for old releases to remove"
for dir in ${prune[@]}; do
		rm -rf $dir
done

# Yay, done!
echo "***** Done."
delete_lock_file_and_exit 0
