#!/bin/bash
# This file contains library function useful for both the merge strategy and
# the subproject utility

#
# Constants
GIT_REPO=$( git rev-parse --git-dir )
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
        >&2 echo "ERROR: Working directory contains untracked files."
        IS_DIRTY=$TRUE
    fi
    
    git diff --no-ext-diff --quiet --exit-code
    if [[ $? -ne 0 ]]; then
        >&2 echo "ERROR: Working directory has local changes."
        IS_DIRTY=$TRUE
    fi
    
    if [[ $IS_DIRTY -eq $TRUE ]]; then
        >&2 echo "ERROR: Need to stage changes first."
        exit $CRITICAL_EXIT_CODE
    fi
}

# remove leading and trailing slashs, reduce duplicated slashs to single slashs
function normalize-prefix() {
    echo -n "$1" | sed -r -e "s/\/+/\//g" -e "s/^\/+//" -e "s/\/+$//" 
}

# Validate and resolve the branch/reference name stored in a variable named $1
# (first argument) to an unambigious name:
# 1) if the branch starts with "heads/" and "refs/$BRANCH" exists, "heads/" is
# stripped from the beginning of the branch name and the result is returned
# 2) if "refs/heads/$BRANCH" exist, "$BRANCH" is returned unchanged
# 3) if "refs/remotes/$BRANCH" exists, "remotes/$BRANCH" is returned
# 4) if "refs/$BRANCH" exists, "$BRANCH" is returned unchanged
# Arguments: <branch_var>
#    <branch_var>: variable storing the branch name to be verified and expanded
function resolve-branch() {
    declare -n BRANCH=$1
    
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
    
    >&2 echo "ERROR: Branch not found: $BRANCH"
    return $CRITICAL_EXIT_CODE
}

# Set $1=$2 if [[ -z "$1" ]]
function set-if-zero() {
    declare -n VAR=$1
    if [[ -z "$VAR" ]]; then
        VAR=$2
    fi
}

# Shift a tree, such that only files found below a given prefix directory are
# considered for merging. 
# arguments: <tree> <shift>
#             <tree>: name of a variable containing the id of a treeish or the
#                     name of a branch. The variable is updated to the id of
#                     the shifted treeish.
#     <their-prefix>: shift tree, such that only files found below
#                     <their-prefix> are considered
function shift-tree() {
    declare -n TREEISH=$1
    local PREFIX=$2
    
    # if specified, extract the tree object corresponding to $PREFIX
    if [[ -n $THEIR_PREFIX ]]; then
        LS_REV=( $(git ls-tree -rd "$TREEISH" | grep "\s$PREFIX$" --max-count 1) )
        
        if [[ -z ${LS_REV[@]} ]]; then
            >&2 echo "'$TREEISH' does not include a folder '$PREFIX'"
            exit 2
        fi
        
        TREEISH=${LS_REV[2]}
    fi
    
    # use the index to prepare their tree
    if [[ -z $MY_PREFIX ]]; then
        # the merge is not limited to a sub directory ($MY_PREFIX) of $MINE,
        # hence there are no files outside $MY_PREFIX to preserve
        # => prepare their tree starting with an empty index
        git read-tree --empty
        git read-tree $TREEISH
    else 
        # the merge is limited to a sub directory ($MY_PREFIX) of $MINE,
        # hence there are files outside $MY_PREFIX to preserve
        # => initialize their tree using $MINE and replace everything below
        #    $MY_PREFIX
        git reset --mixed $MINE
        git rm -q --cached "$MY_PREFIX/*" &> /dev/null
        git read-tree --prefix="$MY_PREFIX" $TREEISH
    fi
    TREEISH=$(git write-tree)
}