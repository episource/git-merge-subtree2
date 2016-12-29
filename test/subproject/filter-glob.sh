#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"


NL=$'\n'
TEST_PATTERNS=( '*' '**' '**/*' '*/**' '*/*' '**.txt' '**/*/*.txt' '*/D?[!0-9]/*.txt' '*d?r/*.*.txt' '**/d?r*/*/*.txt' '[^a-z][!a-zA-Z]/*.txt' '.?!,^$+-()[]{}.txt' '/**.txt' '/**/*/*.txt' './**.txt' './**/*/*.txt')

function the-test() {
    # Initialize repo
    mkdir -p repo && cd repo
    git init
    
    # Initialize source branch
    git checkout --orphan source
    
    mkdir subtree
    mkdir subtree/A9
    mkdir subtree/d_r
    mkdir subtree/dir
    mkdir subtree/dir.!
    mkdir subtree/dir/DIR
    echo -n "source branch" > 'subtree/..!,^$+-()[]{}.txt'
    echo -n "source branch" > subtree/file.txt
    echo -n "source branch" > subtree/.file.bin
    echo -n "source branch" > subtree/A9/file.txt
    echo -n "source branch" > subtree/A9/other.ext    
    echo -n "source branch" > subtree/d_r/file.txt
    echo -n "source branch" > 'subtree/d_r/strange.!()'
    echo -n "source branch" > subtree/dir/.file.txt
    echo -n "source branch" > subtree/dir/crazy.![]
    echo -n "source branch" > subtree/dir.!/file.txt
    echo -n "source branch" > subtree/dir.!/.other.txt
    echo -n "source branch" > subtree/dir/DIR/.more.txt
    echo -n "source branch" > subtree/dir/DIR/more.bin
    
    # Calculate expected file sets using bash builtin globbing
    (
        mkdir results
        cd subtree
    
        set +x
        
        LC_ALL="C"
        shopt -s globstar
        shopt -s dotglob
        shopt -s nullglob
        shopt -u extglob
        
        echo "=== Expected results"
        
        for (( i=0; i < ${#TEST_PATTERNS[@]}; i++ )); do
            local RESULT=""
            
            # remove leading './' or '/'
            local PATTERN="${TEST_PATTERNS[$i]#./}"
            PATTERN="${PATTERN#/}"
            
            for path in $PATTERN; do 
                [[ -f "$path" ]] && RESULT+="$path$NL"
            done
            
            echo -n "$RESULT" | sort > ../results/$i.txt
            echo "--- TEST_PATTERNS[$i]: ${TEST_PATTERNS[$i]}"
            cat ../results/$i.txt
        done
        
        echo "==="
    )
    
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    git reset --hard
        
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init results source --their-prefix=results
    
    # Initialize different subprojects with the patterns and compare the result
    # with bash's built-in globbing
    for (( i=0; i < ${#TEST_PATTERNS[@]}; i++ )); do
        git subproject init "filter-test-$i" source --their-prefix=subtree --filter-is-glob --filter="${TEST_PATTERNS[$i]}" || return $?
        find "filter-test-$i" -type f -printf '%P\n' | sort | diff -y results/$i.txt - || return $?
    done
    
}

invoke-test $@