#!/path/to/deploy.sh

# Repository type (git or svn)
VCS="git"

# All relative paths are relative to the directory this configuration exists in.

# A lock file is used to ensure multiple deploys aren't run at the same time.
# LOCK_FILE=deploy.lock

# Path to an existing working copy (user must checkout/clone the repository
# before the first deploy, the deploy script only updates/pulls new revisions)
RELEASE_WC=working_copy

# Directory where exported versions will be placed
EXPORT_TARGET=/var/www/site/releases

# Symlink target for the latest release
SYMLINK_PATH=/var/www/site/example.com

# How many old releases to retain.
# RELEASE_COUNT=8

# File patterns to remove from the export. If you create a custom
# `export_post_hook` you must manually call `file_prune` if you need this
# feature.
# PRUNE=(o
# 	".*\.xcf"
# )

# Sample hook
# update_post_hook(){
#		echo "in overloaded post update hook"
# }

SETTINGS_FILE_OK=1
