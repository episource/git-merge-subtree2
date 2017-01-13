#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize repo
    local TARGET_REPO="$PWD/target"
    local SOURCE_REPO_BARE="$PWD/source.bare"
    local SOURCE_REPO_WORK="$PWD/source.work"
    mkdir -p "$TARGET_REPO" "$SOURCE_REPO_BARE" "$SOURCE_REPO_WORK"
    
    # Initialize source
    cd "$SOURCE_REPO_BARE" && git init --bare
    cd "$SOURCE_REPO_WORK" && git clone "$SOURCE_REPO_BARE" "."
    mkdir subtree
    echo -e "b\nc\nd" > subtree/subtree.txt
    git add -A
    git commit -m "source: initial commit" && git push

    # Initialize target
    cd "$TARGET_REPO" && git init
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject "$SOURCE_REPO_BARE::master" --their-prefix=subtree || return 1

    # Update source
    cd "$SOURCE_REPO_WORK"
    echo -e "e" >> subtree/subtree.txt
    git add -A
    git commit -m "source: append 'e'" && git push

    # Change target's version of my-subproject before pulling again
    cd "$TARGET_REPO"
    sed -i -r 's/c/x/g' my-subproject/subtree.txt
    git add -A
    git commit -m "target: replace 2nd line 'c' with 'x'"

    # Update my-subproject
    git subproject pull my-subproject || return 1
    
    diff -c - my-subproject/subtree.txt << EOF
b
x
d
e
EOF
    
    [[ $? -eq 0 ]] || return 1
    
    # Push merged state to source
    git subproject push my-subproject || return 1
    
    # Now change 2nd line in source (x->y)
    cd "$SOURCE_REPO_WORK" && git pull
    echo -e "b\ny\nd\ne" > subtree/subtree.txt
    git add -A
    git commit -m "source: replace 2nd line 'x' with 'y'" && git push
    
    # Pull again - their should be no conflict (no local changes)!
    cd "$TARGET_REPO"
    git subproject pull my-subproject --diff3 || return 1

    # Assert
    
    # ... content
    diff -c - my-subproject/subtree.txt << EOF || return 1
b
y
d
e
EOF

    # ... has the temp branch been deleted?
    [[ "$( git branch | wc -l )" -eq 1 ]] || return 1
    
    # ... the tmp branch is not referenced within the commit messages
    git log master | grep -q "git-subproject-tmp-" && return 1
    cd "$SOURCE_REPO_BARE"
    git log master | grep -q "git-subproject-tmp-" && return 1
    
    return 0
}

invoke-test $@