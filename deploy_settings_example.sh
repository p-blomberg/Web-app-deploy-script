#!/bin/bash

# Repository
VCS="svn" #svn or git supported

# Paths
# Relative paths are relative to the directory this configuration exists in.
LOCK_FILE=deploy.lock
RELEASE_WC=working_copy
EXPORT_TARGET=/var/www/site/releases
SYMLINK_PATH=/var/www/site/example.com

#How many old releases to retain. (Default 8)
#RELEASE_COUNT=8

#PRUNE=(
#    ".*\.xcf"
#)

# Sample hook
#update_post_hook(){
#		echo "in overloaded post update hook"
#}

SETTINGS_FILE_OK=1
