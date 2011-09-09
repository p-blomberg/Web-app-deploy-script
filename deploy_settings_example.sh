#!/bin/bash

LOCK_FILE=deploy.lock
VCS="svn" #svn or git supported
RELEASE_WC=working_copy
EXPORT_TARGET=/var/www/site/releases
SYMLINK_PATH=/var/www/site/example.com

SETTINGS_FILE_OK=1
