#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"


NL=$'\n'

function the-test() {
    # work around git-for-windows/git#1019
    # https://github.com/git-for-windows/git/issues/1019
    export MSYS="noglob"
    export MSYS_NO_PATHCONV=1

    # Initialize repo
    mkdir -p repo && cd repo
    git init
    
    # Initialize source branch
    git checkout --orphan source
      
    local CONTENT="source branch"
    mkdir subtree
    echo -n $CONTENT > subtree/abc.txt
    echo -n $CONTENT > subtree/def.txt
    echo -n $CONTENT > subtree/ghi.txt
    echo -n $CONTENT > subtree/jkl.txt 

    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    git reset --hard
        
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject source --their-prefix=subtree --filter="a?c.txt|d[^|]f.txt|g*.*|jkl.txt\|*.*"
    
    # Assert first 3/4 files have been checked out
    [[ -e my-subproject/abc.txt ]] || return $?
    [[ -e my-subproject/def.txt ]] || return $?
    [[ -e my-subproject/ghi.txt ]] || return $?
    [[ ! -e my-subproject/jkl.txt ]] || return $?
}

invoke-test $@