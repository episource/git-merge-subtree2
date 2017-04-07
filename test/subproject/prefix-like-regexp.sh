#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize  repo
    mkdir -p repo && cd repo
    git init
    mkdir dir
    echo -en "subdirectory name does not contain regexp meta characters" > dir/content.txt
    mkdir dir+
    echo -en "subdirectory name contains regex meta character '+'" > dir+/content.txt
    git add -A
    git commit -m "repo: initial commit"
    
    # Initialize subproject based on 'dir+'
    git subproject init dir+-subproject --their-branch=master --their-prefix="dir+" || return $?
    
    # Assert
    diff -c dir+-subproject/content.txt dir+/content.txt    
    return $?
}

invoke-test $@