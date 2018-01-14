#!/bin/sh

DIR=$(dirname "$0")
SITE_DIR="as_published_to_github/"

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "Deleting old publication"
rm -rf $SITE_DIR
mkdir -p $SITE_DIR
git worktree prune
rm -rf .git/worktrees/$SITE_DIR

echo "Checking out master branch into public"
git worktree add -B master $SITE_DIR origin/master

echo "Removing existing files"
rm -rf $SITE_DIR/*

echo "Generating site"
hugo

echo "Updating master branch"
cd $SITE_DIR && git add --all && git commit -m "Publishing to master (publish_to_ghpages.sh)" && git push origin master
