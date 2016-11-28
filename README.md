# Subtree2 merging strategy for git
**Subtree2** is a merge strategy for git similiar to the [built-in subtree strategy](https://git-scm.com/docs/merge-strategies#_merge_strategies). Additionally, **subtree2** has the ability to merge sub-directories of the source branch, too. Like the default subtree strategy it can also merge to sub-directories of the target branch.

The merge strategy is accompanied by a utility script called **subproject**, that can be used for pulling a sub-directory of a different branch or repository into a subdirectory of the target/current branch. It merges using `--squash`, so that the history does not become cluttered. Source branch and commit are remembered within the merge commit's message to simplify later updates. A subproject can also be merged back into the source branch.


## Comparison with built-in strategies
| **feature**                                                   | **`-s subtree2`**         | **built-in `-s subtree`**            | **built-in `-s recursive -Xsubtree=<prefix>`**
|:-------------------------------------------------------------:|:-------------------------:|:------------------------------------:|:--------------------------------------------:|
| **Merging from a sub-directory of the source branch**         | `-Xtheir-prefix=<prefix>` | -                                    | -
| **Merging to a sub-directory of the target branch**           | `-Xmy-prefix=<prefix>`    | (tries to auto-detect sub-directory) | `-Xsubtree=\<prefix\>`                        
| **Merge Algorithm** [1]                                       | like built-in `resolve`   | ??? (most likely `recursive`)        | `recursive`
| **Merging unrelated histories (--allow-unrelated-histories)** | fast forward merge respecting source and target prefix; explicit base can be given using `-Xbase=\<base\>` | merges source branch into an automatically chosen sub-folder or the root of the target branch (most likely not the place you expect) | ignores explicit prefix unless the prefix directory is known to git
| Well tested                                                   | no                        | probably                             | probably

[1] [Some background information on `recursive` vs `resolve` strategy](http://blog.plasticscm.com/2011/09/merge-recursive-strategy.html)

## Options
 * `-Xtheir-prefix=<prefix>`: Consider only files in sub-directory \<prefix\> of source branch
 * `-Xmy-prefix=<prefix>`: Merge to sub-directory \<prefix\> of target branch
 * `-Xbase=<base-id>`: Use the given commit id as base revision during 3way merge instead (usefull when re-merging after `git merge --squash`)
 * `-Xbase-prefix=<prefix>: The (old) \<prefix\> applicable to the base if different from `their-prefix` (because the directory has been renamed)

## Install Subtree2
Add a working copy of this repository to your path.

## Subproject utility
```
$ git subproject help
Include another branch or a sub-directory thereof as sub-directory of the
current branch. By refering to remote branches, other repositories can be
included as well. Subproject merges using --squash, so that the history does not
become cluttered. Source branch and commit are remembered within the merge
commit's message to simplify later updates. A subproject can also be merged back
into the source branch.
Note: Subproject uses \`git merge -s subtree2 --squash ...\` for merging.
    
git subproject init <my-prefix> (--their-branch=<their-branch> | <their-branch>) [-m <message>] [--format=<format>] [--their-prefix=<their-prefix>]
git subproject pull <my-prefix> [-m <message>] [--format=<format>] [--their-prefix=<their-prefix>] [--their-branch=<their-branch>] [--base=<base>] [--base-prefix=<base-prefix>] [--diff3] [--ours|--theirs|--union]
git subproject push <my-prefix> [-m <message>] [--format=<format>]

Init:
    Copy a remote branch's content to a sub-directory <my-prefix> of the current
    branch. The command will refuse to run if <my-prefix> already exists.
    
       my-prefix: mandatory - sub-directory in which their branch will be
                  included
    their-branch: mandatory - branch to be merged into a sub-directory of the
                  current branch
    their-prefix: optional - limit merging to this sub-directory of their
                  branch
         message: optional - custom commit message
          format: optional - pass to \`git log\`'s format option when appending
                  a description of the merged history to the commit message; use
                  \`--format=\` to suppress the history

Pull:
    Update a subproject by merging changes from the upstream branch.
    This command can also be used to change the name and/or prefix of the
    upstream branch.
    
       my-prefix: mandatory - sub-directory containing an existing subproject
    their-branch: optional - change the name of the upstream branch for now and
                  the future; you might need to specify a different base for
                  merging (see below)
            base: optonal - overwrite the common-ancestor used for 3way merge;
                  this might be usefull if the source branch's history has been
                  rewritten; note - no history can be embedded into the commit
                  message when this option is used
    their-prefix: optional - change their prefix if the directory has been
                  renamed since the last update
     base-prefix: optional - overwrite the prefix applied to the common
                  ancestor; this might be necessary when specifying a custom
                  base
         message: optional - custom commit message
          format: optional - pass to \`git log\`'s format option when appending
                  a description of the merged history to the commit message; use
                  \`--format=\` to suppress the history
           diff3: optional - show conflicts in "diff3" style, that is the common
                  ancestor's version is included in confict markers
            ours:
          theirs:
           union: optional - resolve conflicts favouring our (or their or both)
                  side of the lines.
           
Push:
    Push local changes to the upstream branch. Refused if the upstream branch
    has changed since the last update.
    
       my-prefix: mandatory - sub-directory containing an existing subproject
         message: optional - custom commit message
          format: optional - pass to \`git log\`'s format option when appending
                  a description of the merged history to the commit message; use
                  \`--format=\` to suppress the history
                  
Continue:
    Continue a pull/push operation after merge conflicts have been resolved.
```
