#!/bin/bash
# This file contains library function useful for both the merge strategy and
# the subproject utility

#
# Constants
GIT_REPO=$( git rev-parse --git-dir )
EMPTY_TREE=$( git hash-object -t tree /dev/null )
CRITICAL_EXIT_CODE=2
CAN_CONTINUE_EXIT_CODE=1
TRUE=0
FALSE=1
NL=$'\n'


#
# Functions

# exit with return value $CRITICAL_EXIT_CODE if the working directory contains
# 
# untracked files or local changes
function fail-if-dirty() {
    local TRUE=0
    local FALSE=1
    local IS_DIRTY=$FALSE
    
    if [[ -n "$(git status --porcelain)" ]]; then
        >&2 echo "FATAL: Working directory contains untracked files."
        IS_DIRTY=$TRUE
    fi
    
    git diff --no-ext-diff --quiet --exit-code
    if [[ $? -ne 0 ]]; then
        >&2 echo "FATAL: Working directory has local changes."
        IS_DIRTY=$TRUE
    fi
    
    if [[ $IS_DIRTY -eq $TRUE ]]; then
        >&2 echo "FATAL: Need to stage changes first."
        exit $CRITICAL_EXIT_CODE
    fi
}

# Convert GLOB to a perl style regular expression, that mimics bash's behavior
# of filename expansions with options 'globstar' and 'dotglob' enabled, as well
# as 'extglob' disabled - see section 3.5.8 of the bash reference manual for
# details
# Features on top of bash:
#  - multiple wildcard patterns can be "or"-ed together with `|`
# Features currently not supported:
#  - predefined character classes ([:alnum:], ...)
#  - equivalence classes ([=c=], ...)
#  - matching of collating symbols ([.symbol.])
#
# Arguments: <pattern_var>
#   pattern_var: Variable with a glob pattern - the glob is converted in-place.
function glob-to-regexp() {
    local -n PATTERN_VAR="$1"
    
    local GLOB="$PATTERN_VAR"
    local GLOB_LEN=${#GLOB}
    local REGEXP="^"

    function _get_char() {
        local -n CHAR_VAR=$1
        local IDX=$2
        
        [[ $IDX -lt $GLOB_LEN ]] \
            && CHAR_VAR="${GLOB:$IDX:1}" \
            || CHAR_VAR=""
    }
    
    function _regexp-escape-char() {
        # escape any of these: .^$*+-?()[]{}\|
        case "$1" in
            #escape any of these
            '.'|'^'|'$'|'*'|'+'|'-'|'?'|'('|')'|'['|']'|'{'|'}'|'\'|'|')
                echo -n "\\$1"
                ;;
            *)
                echo -n "$1"
                ;;
        esac
    }
    
    
    local GLOB_IDX=0
    local CHAR=""
    while [[ $GLOB_IDX -lt $GLOB_LEN ]]; do
        _get_char "CHAR" GLOB_IDX && (( GLOB_IDX++ ))
        
        case "$CHAR" in
            '*')
                # globstar:
                #   (1)   * don't match '/'
                #   (2)  ** (at end of pattern) match zero or more 
                #       (sub)directories and all files therein
                #   (3)  ** (in the middle of pattern) match all filenames in
                #       the current directory and zero or more (sub)directories
                #       (but not the files in any of the subdirectories and not
                #       a trailing '/')
                #   (4) **/ match zero or more (sub)directories
                #   (5) *** (or more) treated like a single star (tested with
                #       bash 4.3 & 4.4)
                # Note: ** behaves differently when used at the end of a pattern
                #       - this is not obvious from the bash reference manual
                #       (see below) and has been observed while analyzing
                #       negative outcomes of test 'subproject/filter-glob.sh'. 
                #       Quoting the reference manual of bash version 4.4,
                #       section 3.5.8.1:
                #       "When the globstar shell option is enabled, and ‘*’ is
                #       used in a filename expansion context, two adjacent ‘*’s
                #       used as a single pattern will match all files and zero
                #       or more directories and subdirectories. If followed by a
                #       ‘/’, two adjacent ‘*’s will match only directories and
                #       subdirectories."
                local STAR_COUNT=1
                while [[ $GLOB_IDX -lt $GLOB_LEN && "${GLOB:$GLOB_IDX:1}" == "*" ]]; do
                    (( STAR_COUNT++ ))
                    (( GLOB_IDX++ ))
                done
                
                if [[ $STAR_COUNT -eq 1 || $STAR_COUNT -gt 2 ]]; then
                    # cases (1)+(5) above
                    REGEXP+="[^/]*"
                elif [[ $GLOB_IDX -lt $GLOB_LEN && "${GLOB:$GLOB_IDX:1}" == "/" ]]; then
                    # case (4) above
                    (( GLOB_IDX++ ))
                    REGEXP+="(.+/)*"
                elif [[ $GLOB_IDX -eq $GLOB_LEN ]]; then
                    # case (2) above
                    REGEXP+=".*"
                else
                    # case (3) above
                    REGEXP+="([^/]*|.*(?=/))"
                fi
                ;;
            '?')
                REGEXP+="."
                ;;
            '[')
                # Note: GLOB_IDX has been incremented above!
                # => It points to `pos($CHAR) + 1` which is the first character
                #    within the character group!
                local GROUP_IDX=$GLOB_IDX
                local GROUP_STRING=""
                
                local NEXT_CHAR=
                _get_char "NEXT_CHAR" $GROUP_IDX
                
                # In the following two cases, the first ']' is part of the
                # character group: '[]]', '[!]]', '[^]]'
                # => skip when searching the end of the group
                if [[ "$NEXT_CHAR" == "!" || "$NEXT_CHAR" == "^" ]]; then
                    GROUP_STRING+="^"
                    (( GROUP_IDX++ )) && _get_char "NEXT_CHAR" $GROUP_IDX
                fi
                if [[ "$NEXT_CHAR" == "]" ]]; then
                    GROUP_STRING+="$NEXT_CHAR"
                    (( GROUP_IDX++ )) && _get_char "NEXT_CHAR" $GROUP_IDX
                fi
                
                # Gather group content until a closing ']' is found
                while [[ -n "$NEXT_CHAR" && "$NEXT_CHAR" != "]" ]]; do
                    if [[ "$NEXT_CHAR" == '\' ]]; then
                        # the escaped character follows
                        (( GROUP_IDX++ )) && _get_char "NEXT_CHAR" $GROUP_IDX
                        GROUP_STRING+="$( _regexp-escape-char "$NEXT_CHAR" )"
                    elif [[ "$NEXT_CHAR" == "-" ]]; then
                        GROUP_STRING+="$NEXT_CHAR"
                    else
                        GROUP_STRING+="$( _regexp-escape-char "$NEXT_CHAR" )"
                    fi
                    
                    (( GROUP_IDX++ )) && _get_char "NEXT_CHAR" $GROUP_IDX
                done
                                   
                if [[ "$NEXT_CHAR" == "]" ]]; then                                      
                    # it's a valid character group with closing ']'
                    # - escapes have already been applied to $GROUP_STRING
                    GLOB_IDX=$(( $GROUP_IDX + 1 ))
                    REGEXP+="[$GROUP_STRING]"
                else
                    # it's not a character group without a closing ']' - escape
                    REGEXP+="\\["
                fi
                ;;
            '\')
                if [[ $GLOB_IDX -eq $GLOB_LEN ]]; then
                    REGEXP+="\\"
                else
                    REGEXP+="$( _regexp-escape-char "${GLOB:$GLOB_IDX:1}" )"
                    (( GLOB_IDX++ ))
                fi
                ;;
            '|')
                REGEXP+="$|^"
                ;;
            *)
                REGEXP+="$( _regexp-escape-char "$CHAR" )"
                ;;
        esac
    done

    PATTERN_VAR="$REGEXP$"
}

# remove leading './' or '/' from filter globstar
# arguments: <glob_var>
#    glob_var: variable storing the glob pattern - updated in-place
function normalize-glob() {
    local -n GLOB_VAR=$1
    GLOB_VAR="${GLOB_VAR#./}"
    GLOB_VAR="${GLOB_VAR#/}"
}

# remove leading and trailing slashs, reduce duplicated slashs to single slashs
# arguments: <prefix_var>
#    prefix_var: variable storing the prefix path - updated in-place
function normalize-prefix() {
    local -n PREFIX_VAR=$1
    PREFIX_VAR=$( echo -n "$PREFIX_VAR" | sed -r -e "s/\/+/\//g" -e "s/^\/+//" -e "s/\/+$//" )
}

# Validate and resolve the branch/reference name stored in a variable named $1
# (first argument) to an unambigious name:
# 1) if the branch name contains "::" it is left unchanged (it's a reference to
#    a remote repository)
# 2) if the branch starts with "heads/" and "refs/$BRANCH" exists, "heads/" is
# stripped from the beginning of the branch name and the result is returned
# 3) if "refs/heads/$BRANCH" exist, "$BRANCH" is returned unchanged
# 4) if "refs/remotes/$BRANCH" exists, "remotes/$BRANCH" is returned
# 5) if "refs/$BRANCH" exists, "$BRANCH" is returned unchanged
# Arguments: <branch_var>
#    <branch_var>: variable storing the branch name to be verified and expanded
function resolve-branch() {
    local -n BRANCH=$1
    
    if [[ "$BRANCH" == *"::"* ]]; then
        return 0
    fi
    
    # The result corresponding to the first matching candidate is returned
    local CANDIDATES=("heads/$BRANCH" "remotes/$BRANCH" "$BRANCH")
    local RESULTS=(   "$BRANCH"       "remotes/$BRANCH" "$BRANCH")
    if [[ "$BRANCH" == heads/* ]]; then
        CANDIDATES=( "$BRANCH"           "${CANDIDATES[@]}" )
        RESULTS=(    "${BRANCH##heads/}" "${RESULTS[@]}" )
    fi
    
    for ref in "${CANDIDATES[@]}"; do
        if git show-ref -q --verify "refs/$ref"; then
            BRANCH="${RESULTS[0]}"
            return 0
        fi
        
        CANDIDATES=( "${CANDIDATES[@]:1}" )
        RESULTS=( "${RESULTS[@]:1}" )
    done
    
    >&2 echo "FATAL: Branch not found: $BRANCH"
    return $CRITICAL_EXIT_CODE
}

# Set $1=$2 if [[ -z "$1" ]]
function set-if-zero() {
    declare -n VAR=$1
    if [[ -z "$VAR" ]]; then
        VAR=$2
    fi
}

# Swap contents of variables named $1 and $2.
function swap-vars() {
    local -n VAR1=$1
    local -n VAR2=$2
    
    local TMP="$VAR1"
    VAR1="$VAR2"
    VAR2="$TMP"
}

# Prepare a source or base tree for merging, such that only files matching a
# given prefix and filter regexp are considered for merging. 
# Arguments: <source_tree_var> <source_prefix> <target_tree> <target_prefix> <filter_regexp>
#   source_tree_var: name of a variable referencing a source/base tree object or
#                    branch - the variable is updated to reference the shifted
#                    tree object
#     source_prefix: only files in the tree referenced by <source_tree_var>,
#                    whose paths starts with <source_prefix> shall be considered
#                    for merging
#       target_tree: name of a the target tree object or branch
#     target_prefix: within the tree referenced by <source_tree_var>, the prefix
#                    directory <source_prefix> is renamed to <target_prefix>
#     filter_regexp: consider only files from source tree whose relative paths
#                    match this filter expression (pcre)
#
# The resulting treeish contains files from from the tree referenced by
# <source_tree_var> and <target_tree>:
#   - files from <target_tree> not matching <target_prefix>/*
#   - files from <source_tree(_var)> matching <source_prefix>/* and
#     <filter_regex>  with <source_prefix> changed to <target_prefix>
function prepare-remote-tree() {
    local -n SOURCE_TREE_VAR=$1
    local SOURCE_PREFIX=$2
    local TARGET_TREE=$3
    local TARGET_PREFIX=$4
    local FILTER_REGEXP=$5

    local FROM_TREE="$SOURCE_TREE_VAR"
    
    # if specified, extract the tree object corresponding to $REMOTE_PREFIX
    if [[ -n "$SOURCE_PREFIX" ]]; then
        LS_TREE_RESULT=( $(git ls-tree -rd "$SOURCE_TREE_VAR" | grep --perl-regexp "\t$SOURCE_PREFIX$" --max-count 1) )
        
        if [[ -z ${LS_TREE_RESULT[@]} ]]; then
            >&2 echo "'$SOURCE_TREE_VAR' does not include a directory '$SOURCE_PREFIX'"
            return 2
        fi
        
        FROM_TREE=${LS_TREE_RESULT[2]}
    fi
    
    # use the index to prepare their tree
    if [[ -z "$TARGET_PREFIX" ]]; then
        # the merge is not limited to a sub directory ($TARGET_PREFIX) of
        # $TARGET_TREE, hence there are no files outside $TARGET_PREFIX to
        # preserve => prepare $FROM_TREE starting with an empty index
        git read-tree --empty
        git read-tree "$FROM_TREE"
    else 
        # the merge is limited to a sub directory ($TARGET_PREFIX) of 
        # $TARGET_TREE, hence there are files outside $TARGET_PREFIX to preserve
        # => initialize $FROM_TREE using $TARGET_TREE and replace everything
        #    below $TARGET_PREFIX
        git reset --mixed "$TARGET_TREE"
        git rm -q --cached "$TARGET_PREFIX/*" &> /dev/null
        git read-tree --prefix="$TARGET_PREFIX" "$FROM_TREE"
    fi
    
    if [[ -n "$FILTER_REGEXP" ]]; then
            # note: TARGET_PREFIX is never empty!
            git ls-files -c -- "$TARGET_PREFIX" | sed -e "s/^$TARGET_PREFIX\///" \
                | grep -v --perl-regexp "$FILTER_REGEXP" \
                | sed -e "s/^/$TARGET_PREFIX\//" \
                | xargs --no-run-if-empty git rm -rfq --cached --
    fi
        
    SOURCE_TREE_VAR=$(git write-tree)
}

# A merge strategy like built-in resolve.
# Based on https://github.com/git/git/blob/master/git-merge-resolve.sh
# Arguments: <base_tree> <target_tree> <source_tree>
#  xxx_tree: id of a tree object to merge
# Variables: MERGE_FILE_CONFLICT_STYLE, MERGE_FILE_MODE
function merge-resolve() {
    local BASE_TREE="$1"
    local TARGET_TREE="$2"
    local SOURCE_TREE="$3"
    
    # Update index to match working directory, then merge trees
    git reset --mixed 
    git read-tree -m -u --aggressive $BASE_TREE $TARGET_TREE $SOURCE_TREE \
        || return $CRITICAL_EXIT_CODE

    # Read-tree does a simple merge, that might leave unresolved files behind
    # Using 'git write-tree' it is easy to test for unresolved files.
    echo "Trying simple merge."
    if result_tree=$(git write-tree 2>/dev/null); then
        return 0
    else 
        # see https://github.com/git/git/blob/master/git-merge-resolve.sh
        echo "Simple merge failed, trying Automatic merge."
        export MERGE_FILE_ARGS="$MERGE_FILE_CONFLICT_STYLE $MERGE_FILE_MODE"
        if git-merge-index -o git-merge-one-file2 -a
        then
            return 0
        else
            return $CAN_CONTINUE_EXIT_CODE
        fi
    fi
}