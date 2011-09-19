What is this?
=============
This is a simple script to push new versions of svn or git projects to a production directory on a web server.

What does it do?
================
1. It updates your (already created) working copy. (Do NOT use this working copy for development. You don't want conflicts here - ever!)
2. It creates a new release name named release-YYYYMMDDHHIISS
3. It runs `svn export $working_copy $EXPORT_TARGET/$releasename`
4. It deletes a symlink (to your old release)
5. It creates a symlink (to the new release)
6. It deletes all releases older than ten deploys. Remember that a new deploy always is created when you run the deploy script, even if no changes have been made.

How do I use it?
================
1. Check out your svn repo on the production server. Creating a user and home directory for the project might be a good idea - then you can simply add ssh keys for everyone who should have access to deploy updates. On the downside, this means that you don't know who did the deploy.
2. You should now have a working copy on the server. Remember that your entire working copy will be deployed - if you only want a subdirectory, i.e. "trunk" or "production", make your checkout more specific.
3. Grab `deploy.sh` and `deploy_settings_example.sh`, put them somewhere that makes sense to you. (Perhaps the home directory of the project.)
4. Have a look in `deploy_settings_example.sh`, change the paths. Rename the file to `deploy_settings.sh` when you're done.
5. Create the export target folder ("releases"). Make sure to give enought privileges to the user who will run the deploy script.
6. Move your current production folder into the export target folder. Create a symlink from your old location.
7. Check privileges on the symlink. The deploy user needs to be able to delete the symlink and create it again.
8. Log in as the correct user and give it a try.
