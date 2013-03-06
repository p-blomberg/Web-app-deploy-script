#!/bin/bash

# nullglob is required for globbing release-list (if no releases exists)
shopt -s nullglob

# check if stdout is a terminal...
if [ -t 1 ]; then
		# see if it supports colors...
		ncolors=$(tput colors)

		if test -n "$ncolors" && test $ncolors -ge 8; then
				bold="$(tput bold)"
				underline="$(tput smul)"
				standout="$(tput smso)"
				normal="$(tput sgr0)"
				black="$(tput setaf 0)"
				red="$(tput setaf 1)"
				green="$(tput setaf 2)"
				yellow="$(tput setaf 3)"
				blue="$(tput setaf 4)"
				magenta="$(tput setaf 5)"
				cyan="$(tput setaf 6)"
				white="$(tput setaf 7)"
		fi
fi

errstar="${bold}${red} * ${normal}"
infostar="${bold}${green} * ${normal}"

LOCK_FILE=.$(basename $1 .sh).lock

################ Functions ###########################

die(){
		echo
		echo "${errstar} ERROR: during stage ${stage}:"
		echo "${errstar}   $*"
		if ! rm $LOCK_FILE; then
				echo "${errstar}"
				echo "${errstar} Failed to delete lock file."
		fi
		local frame=0

		set -o pipefail
		echo "${errstar}"
		echo "${errstar} Callstack:"
		while caller $frame | awk -v errstar="${errstar}" '{print errstar "   "$3":"$1" in "$2}'; do
				((frame++));
		done

		echo "${errstar}"
		echo "${errstar} Variables:"
		echo "${errstar}   VCS: ${VCS}"
		echo "${errstar}   RELEASE_WC: ${RELEASE_WC}"
		echo "${errstar}   EXPORT_TARGET: ${EXPORT_TARGET}"
		echo "${errstar}   SYMLINK_PATH: ${SYMLINK_PATH}"
		echo "${errstar}   DST: ${DST}"

		exit 1
}

phase_start(){
		local desc=""
		if [[ $# -gt 0 ]]; then
				desc=": $*"
		fi
		echo "${infostar} Running \"${stage}\"${desc}"
}

phase_end(){
		echo "${infostar} .. OK"
}

update_pre_hook(){
		return 0
}

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

update_post_hook(){
		return 0
}

do_update(){
		stage="update"
		phase_start
		update_pre_hook || die "update_pre_hook returned non-zero status, aborting"
		eval `update_repo_cmd` || die "Unable to do update local repository"
		update_post_hook || die "update_post_hook returned non-zero status, aborting"
		phase_end
}

export_pre_hook(){
		return 0
}

export_repo_cmd() {
	case $VCS in
		svn)
			echo "svn export \"$RELEASE_WC\" \"${DST}\""
			;;
		git)
			# Until git 1.8 (where git export-index support submodules) must use rsync with --exclude='.git'
			# echo "(cd \"$RELEASE_WC/\"; git checkout-index -a -f --prefix=\"$EXPORT_TARGET/$releasename\" )"
			echo "rsync -av --exclude='.git' \"$RELEASE_WC/\" \"${DST}\""
			;;
	esac
}

export_post_hook(){
		file_prune
		return $?
}

do_export(){
		stage="export"
		phase_start
		export_pre_hook ||  die "export_pre_hook returned non-zero status, aborting"
		eval `export_repo_cmd` || die "Unable to create export"
		export_post_hook || die "export_post_hook returned non-zero status, aborting"
		phase_end
}

file_prune(){
		if [[ ${stage} != "export" ]]; then
				die "file_prune called from stage \"${stage}\", not \"export\" as it should"
		fi
		if [[ ${PRUNE:+1} ]]; then
				for pattern in "${PRUNE[@]}"; do
						find "${EXPORT_TARGET}/$releasename" -regex "${pattern}" -delete -printf "%p removed\n"
				done
		fi
}

symlink_pre_hook(){
		return 0
}

symlink_update() {
		local src=$1
		local dst=$2

		# create new symlink
		ln -s $src ${dst}_tmp || die "Unable to create new symlink"

		# replace old symlink
		mv -Tf ${dst}_tmp $dst || die "Unable to replace production symlink"
}

symlink_post_hook(){
		return 0
}

do_symlink(){
		stage="symlink"
		phase_start
		symlink_pre_hook || die "symlin_pre_hook returned non-zero status, aborting"
		symlink_update $DST $SYMLINK_PATH || die
		symlink_post_hook || die "symlin_post_hook returned non-zero status, aborting"
		phase_end
}

# Delete old releases
do_prune(){
		stage="prune"
		phase_start "Checking for old releases to remove"
		for dir in ${prune[@]}; do
				rm -rf $dir || die
		done
		phase_end
}

# Called when script finishes or if user aborts
cleanup(){
		rm -f $LOCK_FILE || die
}

handle_sigint(){
		cleanup
		echo -e "\n${errstar} Deploy aborted."
		exit 1
}

############## END FUNCTIONS ####################3

# Catch ctrl-c
trap handle_sigint SIGINT

if [ $# -gt 1 ]; then
		echo "Bad usage"
		exit 48
fi

if [ $# -eq 1 ]; then
		SETTINGS_FILE=$1
else
		SETTINGS_FILE=$(dirname "$0")/deploy_settings.sh
fi

if [ ! -e $SETTINGS_FILE ]; then
		echo "${errstar} Cannot find settings file. Expected location: $SETTINGS_FILE"
		exit 1
fi

SETTINGS_FILE_OK=0
source "$SETTINGS_FILE"
if [ $SETTINGS_FILE_OK -eq 1 ]; then
		echo "${infostar} Settings file OK"
else
		echo "${errstar}Unable to parse settings file $SETTINGS_FILE" >&2
		exit 1
fi

# Move to correct working directory if script is called from another location to
# fix relative paths
DIR=$(readlink -f $(dirname "${SETTINGS_FILE}"))
echo "${infostar} Working directory: ${DIR}"
cd ${DIR}

# Create release name
releasename="${releaseprefix:-release}-`date +%Y%m%d%H%M%S`"
DST=$(readlink -f "${EXPORT_TARGET}/${releasename}")

# Check that release path exists
if [ ! -e "${EXPORT_TARGET}" ]; then
		echo "${errstar} Export target $EXPORT_TARGET does not seem to exist. Aborting."
		exit 1
fi

# abort if the working copy doesn't exist
if [ ! -e ${RELEASE_WC} ]; then
		echo "${errstar} Working copy '${RELEASE_WC}\` does not exist"
		exit 1
fi

# normalize symlink path
SYMLINK_PATH=$(readlink -f "$SYMLINK_PATH")

# Check vcs that we support selected vcs:
case $VCS in
		svn)
				echo "${infostar} Using SVN"
				if [ ! -e ${RELEASE_WC}/.svn ]; then
						echo "${errstar} Export target ${RELEASE_WC} is not a subversion repository. Aborting."
						exit 1
				fi
				;;
		git)
				echo "${infostar} Using GIT (${RELEASE_WC})"
				if [ ! -e ${RELEASE_WC}/.git ]; then
						echo "${errstar} Export target ${RELEASE_WC} is not a git repository. Aborting."
						echo "${errstar} You should initialize the folder by cloning the repository of your choice and checkout the correct branch, e.g:"
						echo "${errstar}   1. git clone git@example.net:REPO \"${RELEASE_WC}\""
						echo "${errstar}   2. cd \"${RELEASE_WC}\""
						echo "${errstar}   3. git checkout BRANCH"
						exit 1
				fi
				;;
		*)
				echo "${errstar} Unknown vcs specifed: $VCS. Aborting."
				exit 1
esac

# abort if SYMLINK_PATH exists but is not a symlink
if [[ ( -e ${SYMLINK_PATH} ) && (! -L ${SYMLINK_PATH}) ]]; then
		echo "${errstar} SYMLINK_PATH already exists but it not a symlink. Check configuration and/or remove ${SYMLINK_PATH} manually."
		exit 1
elif [[ (-L ${SYMLINK_PATH}) && (! -e ${SYMLINK_PATH}) ]]; then
		echo "${errstar} Warning: ${SYMLINK_PATH} is a dangling symlink."
fi

# Create list of old releases to an array called "prune"
releases=($EXPORT_TARGET/${prefix:-release}-* $EXPORT_TARGET/$releasename)
prune=()
while [[ ${#releases[*]} -gt ${RELEASE_COUNT:-8} ]]; do
		# pop first element from array, store it in "prune"
		prune+=(${releases[0]})
		releases=(${releases[@]:1})
done

# Check for lock file
if [ -e $LOCK_FILE ]; then
    echo "${errstar} Lock file \"$LOCK_FILE\" exists, bailing out." >&2
    exit 1
fi

# Ask user to confirm
echo
echo "*********************************"
echo "This is what I'll do (excluding hooks):"
echo "  touch $LOCK_FILE"
echo -n "  "; update_repo_cmd
echo -n "  "; export_repo_cmd
echo "  ln -s $DST ${SYMLINK_PATH}_tmp"
echo "  mv -Tf ${DST}_tmp $dst"
for dir in ${prune[@]}; do
		echo "  rm -rf $dir"
done
if [[ ${PRUNE:+1} ]]; then
		for pattern in "${PRUNE[@]}"; do
				echo "  find \"${DST}\" -regex \"${pattern}\" -delete"
		done
fi
echo "  rm $LOCK_FILE"
echo "*********************************"
echo
answer="fail"
until [[ "$answer" = "yes" ]]; do
		echo -n "${bold}Do you wish to continue?${normal} [${green}yes${normal}/${red}no${normal}] "
		read answer
		if [[ "$answer" = "no" ]]; then
				echo "Aborting."
				exit 45
		fi
done

# Create lock file
touch $LOCK_FILE || die "Unable to create lock file"

stage=none
do_update
do_export
do_symlink
do_prune

# remove lock and restore cwd
cleanup

echo "${infostar} Deploy complete."
