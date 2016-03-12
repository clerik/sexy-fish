# Port of sexy-bash-prompt to fishshell.

set -l sexy_fish_prompt_reset normal

# Since fish manage color output, we don't need to do anything except set colors.
# See http://fishshell.com/docs/current/commands.html#set_color for more information.
set -l sexy_fish_prompt_user_color blue
set -l sexy_fish_prompt_preposition_color white
set -l sexy_fish_prompt_device_color cyan
set -l sexy_fish_prompt_dir_color green
set -l sexy_fish_prompt_git_status_color yellow
set -l sexy_fish_prompt_git_progress_color red
set -l sexy_fish_prompt_symbol_color normal

switch $USER
  case root toor
    if set -q fish_color_cwd_root
      set sexy_fish_prompt_user_color $fish_color_cwd_root
    end
    set sexy_fish_prompt_symbol "#"
  case '*'
    set sexy_fish_prompt_symbol "\$"
end

if set -q PROMPT_USER_COLOR;          set sexy_fish_prompt_user_color $PROMPT_USER_COLOR; end
if set -q PROMPT_PREPOSITION_COLOR;   set sexy_fish_prompt_preposition_color $PROMPT_PREPOSITION_COLOR; end
if set -q PROMPT_DEVICE_COLOR;        set sexy_fish_prompt_device_color $PROMPT_DEVICE_COLOR; end
if set -q PROMPT_DIR_COLOR;           set sexy_fish_prompt_dir_color $PROMPT_DIR_COLOR; end
if set -q PROMPT_GIT_STATUS_COLOR;    set sexy_fish_prompt_git_status_color $PROMPT_GIT_STATUS_COLOR; end
if set -q PROMPT_GIT_PROGRESS_COLOR;  set sexy_fish_prompt_git_progress_color $PROMPT_GIT_PROGRESS_COLOR; end
if set -q PROMPT_SYMBOL;              set sexy_fish_prompt_symbol $PROMPT_SYMBOL; end
if set -q PROMPT_SYMBOL_COLOR;        set sexy_fish_prompt_symbol_color $PROMPT_SYMBOL_COLOR; end

# Set up symbols
set -l sexy_fish_prompt_synced_symbol ""
set -l sexy_fish_prompt_dirty_synced_symbol "*"
set -l sexy_fish_prompt_unpushed_symbol "△"
set -l sexy_fish_prompt_dirty_unpushed_symbol "▲"
set -l sexy_fish_prompt_unpulled_symbol "▽"
set -l sexy_fish_prompt_dirty_unpulled_symbol "▼"
set -l sexy_fish_prompt_unpushed_unpulled_symbol "⬡"
set -l sexy_fish_prompt_dirty_unpushed_unpulled_symbol "⬢"

# Apply symbol overrides that have been set in the environment
# DEV: Working unicode symbols can be determined via the following gist
#   **WARNING: The following gist has 64k lines and may freeze your browser**
#   https://gist.github.com/twolfson/9cc7968eb6ee8b9ad877
if set -q PROMPT_SYNCED_SYMBOL;                   set sexy_fish_prompt_synced_symbol $PROMPT_SYNCED_SYMBOL; end
if set -q PROMPT_DIRTY_SYNCED_SYMBOL;             set sexy_fish_prompt_dirty_synced_symbol $PROMPT_DIRTY_SYNCED_SYMBOL; end
if set -q PROMPT_UNPUSHED_SYMBOL;                 set sexy_fish_prompt_unpushed_symbol $PROMPT_UNPUSHED_SYMBOL; end
if set -q PROMPT_DIRTY_UNPUSHED_SYMBOL;           set sexy_fish_prompt_dirty_unpushed_symbol $PROMPT_DIRTY_UNPUSHED_SYMBOL; end
if set -q PROMPT_UNPULLED_SYMBOL;                 set sexy_fish_prompt_unpulled_symbol $PROMPT_UNPULLED_SYMBOL; end
if set -q PROMPT_DIRTY_UNPULLED_SYMBOL;           set sexy_fish_prompt_dirty_unpulled_symbol $PROMPT_DIRTY_UNPULLED_SYMBOL; end
if set -q PROMPT_UNPUSHED_UNPULLED_SYMBOL;        set sexy_fish_prompt_unpushed_unpulled_symbol $PROMPT_UNPUSHED_UNPULLED_SYMBOL; end
if set -q PROMPT_DIRTY_UNPUSHED_UNPULLED_SYMBOL;  set sexy_fish_prompt_dirty_unpushed_unpulled_symbol $PROMPT_DIRTY_UNPUSHED_UNPULLED_SYMBOL; end

function sexy_fish_prompt_get_git_branch
  # On branches, this will return the branch name
  # On non-branches, (no branch)
  set ref (git symbolic-ref HEAD 2> /dev/null | sed -e 's/refs\/heads\///')
  if test -n $ref
    echo $ref
  else
    echo "(no branch)"
  end
end

function sexy_fish_prompt_get_git_progress
  # Detect in-progress actions (e.g. merge, rebase)
  # https://github.com/git/git/blob/v1.9-rc2/wt-status.c#L1199-L1241
  set git_dir (git rev-parse --git-dir)
  set git_status ''

  # git merge
  if test -f $git_dir/MERGE_HEAD
    set git_status $git_status" [merge]"
  else if test -d $git_dir/rebase-apply
    # git am
    if test -f $git_dir/rebase-apply/applying
      set git_status $git_status" [am]"
    # git rebase
    else
      set git_status $git_status" [rebase]"
    end
  else if test -d $git_dir/rebase-merge
    # git rebase --interactive/--merge
    set git_status $git_status" [rebase]"
  else if test -f $git_dir/CHERRY_PICK_HEAD
    # git cherry-pick
    set git_status $git_status" [cherry-pick]"
  end
  if test -f $git_dir/BISECT_LOG
    # git bisect
    set git_status $git_status" [bisect]"
  end
  if test -f $git_dir/REVERT_HEAD
    # git revert --no-commit
    set git_status $git_status" [revert]"
  end

  echo $git_status
end

function sexy_fish_prompt_is_branch1_behind_branch2 -a branch1 branch2
  # $ git log origin/master..master -1
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  # Find the first log (if any) that is in branch1 but not branch2
  set first_log (git log "$branch1".."$branch2" -1 2> /dev/null)
  # echo first_log $first_log

  # Exit with 0 if there is a first log, 1 if there is not
  test -n "$first_log"
end

function sexy_fish_prompt_branch_exists -a branch
  # List remote branches           | # Find our branch and exit with 0 or 1 if found/not found
  command git branch --remote 2> /dev/null | grep --quiet $branch
end

function sexy_fish_prompt_parse_git_ahead
  # Grab the local and remote branch
  set branch (sexy_fish_prompt_get_git_branch)
  set remote_branch "origin/$branch"

  # $ git log origin/master..master
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  sexy_fish_prompt_is_branch1_behind_branch2 $remote_branch $branch
  set is_behind $status
  sexy_fish_prompt_branch_exists $remote_branch
  set remote $status

  # If the remote branch is behind the local branch
  # or it has not been merged into origin (remote branch doesn't exist)
  if test $is_behind = 0 -o $remote = 0
    # echo our character
    false
  else
    true
  end
end

function sexy_fish_prompt_parse_git_behind
  # Grab the branch
  set branch (sexy_fish_prompt_get_git_branch)
  set remote_branch "origin/$branch"

  # $ git log master..origin/master
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  # If the local branch is behind the remote branch
  sexy_fish_prompt_is_branch1_behind_branch2 {$branch} {$remote_branch}
  if test $status -eq 0
    # echo our character
    false
  else
    true
  end
end

function sexy_fish_prompt_parse_git_dirty
  # If the git status has *any* changes (e.g. dirty), echo our character
  set stat (git status --porcelain 2> /dev/null)
  if test -n "$stat"
    false
  else
    true
  end
end

function sexy_fish_prompt_is_on_git
  command git rev-parse 2> /dev/null
end

function sexy_fish_prompt_get_git_status
  # Grab the git dirty and git behind
  sexy_fish_prompt_parse_git_dirty
  set dirty_branch $status
  sexy_fish_prompt_parse_git_ahead
  set branch_ahead $status
  sexy_fish_prompt_parse_git_behind
  set branch_behind $status

  # echo dirty_branch $dirty_branch
  # echo branch_ahead $branch_ahead
  # echo branch_behind $branch_behind

  # Iterate through all the cases and if it matches, then echo
  if test $dirty_branch -eq 1 -a $branch_ahead -eq 1 -a $branch_behind -eq 1
    echo $sexy_fish_prompt_dirty_unpushed_unpulled_symbol
  else if test $branch_ahead -eq 1 -a $branch_behind -eq 1
    echo $sexy_fish_prompt_unpushed_unpulled_symbol
  else if test $dirty_branch -eq 1 -a $branch_ahead -eq 1
    echo $sexy_fish_prompt_dirty_unpushed_symbol
  else if test $branch_ahead -eq 1
    echo $sexy_fish_prompt_unpushed_symbol
  else if test $dirty_branch -eq 1 -a $branch_behind -eq 1
    echo $sexy_fish_prompt_dirty_unpulled_symbol
  else if test $branch_behind -eq 1
    echo $sexy_fish_prompt_unpulled_symbol
  else if test $dirty_branch -eq 1
    echo $sexy_fish_prompt_dirty_synced_symbol
  else # clean
    echo $sexy_fish_prompt_synced_symbol
  end
end

function sexy_fish_prompt_get_git_info
  # Grab the branch
  set branch (sexy_fish_prompt_get_git_branch)

  # If there are any branches
  if test -n $branch
    # Echo the branch
    set output $branch

    # Add on the git status
    set output "$output"(sexy_fish_prompt_get_git_status)

    # Echo our output
    echo $output
  end
end

function fish_prompt
  # From fishshell fish_prompt.
  # Precalculate the hostname and set a variable to save a few cycle.
  if not set -q __fish_prompt_hostname
    set -g __fish_prompt_hostname (hostname|cut -d . -f 1)
  end

  # Add an empty line above the prompt.
  echo ''

  # Set $git to an empty string.
  set git ''
  # Call sexy_fish_prompt_is_on_git to verify if we are in a git managed repository.
  sexy_fish_prompt_is_on_git
  if test $status = 0
            # set on
    set git $git(set_color --bold $sexy_fish_prompt_preposition_color)'on '
            # set branch and symbol
    set git $git(set_color --bold $sexy_fish_prompt_git_status_color)(sexy_fish_prompt_get_git_info)
            # set progress
    set git $git(set_color --bold $sexy_fish_prompt_git_progress_color)(sexy_fish_prompt_get_git_progress)
  end

       # echo user
  echo (set_color --bold $sexy_fish_prompt_user_color)"$USER"(set_color $sexy_fish_prompt_reset) \
       # echo at
       (set_color --bold $sexy_fish_prompt_preposition_color)"at"(set_color $sexy_fish_prompt_reset) \
       # echo hostname
       (set_color --bold $sexy_fish_prompt_device_color)"$__fish_prompt_hostname"(set_color $sexy_fish_prompt_reset) \
       # echo in
       (set_color --bold $sexy_fish_prompt_preposition_color)"in"(set_color $sexy_fish_prompt_reset) \
       # echo shortcuted working directory and git part
       (set_color --bold $sexy_fish_prompt_dir_color)(prompt_pwd) "$git"(set_color $sexy_fish_prompt_reset)
       # echo prompt symbol
  echo (set_color --bold $sexy_fish_prompt_symbol_color)"$sexy_fish_prompt_symbol "
end
