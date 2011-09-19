#!/bin/bash

LOCK_FILE=/home/foobar/site/deploy.lock
VCS="svn" #svn or git supported
RELEASE_WC=/home/foobar/site/working_copy
EXPORT_TARGET=/var/www/site/releases
SYMLINK_PATH=/var/www/site/example.com

SETTINGS_FILE_OK=1
