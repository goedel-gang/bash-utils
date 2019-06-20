#                                          __
# ______ _______   ____    _____  ______ _/  |_
# \____ \\_  __ \ /  _ \  /     \ \____ \\   __\
# |  |_> >|  | \/(  <_> )|  Y Y  \|  |_> >|  |
# |   __/ |__|    \____/ |__|_|  /|   __/ |__|
# |__|                         \/ |__|
# FIGMENTIZE: prompt

# file that sets up my flashy bashy prompt

# this part configures the git bit of my prompt. I highly recommend finding this
# script somewhere. It should in theory just come standard with git.

# this is where it is on my system. Find a copy at
# https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh.
# I also have a backuip copy in my .bash/scripts, but that's not under any kind
# of version control or package management.
source_if_exists /usr/share/git/git-prompt.sh "$HOME/$BASHDOTDIR/scripts/git-prompt.sh"

# show if there are staged/unstaged changes
export GIT_PS1_SHOWDIRTYSTATE=true
# pretty colours
export GIT_PS1_SHOWCOLORHINTS=true
# show if there are untracked files
export GIT_PS1_SHOWUNTRACKEDFILES=true
# show if you have stashed changes
export GIT_PS1_SHOWSTASHSTATE=true
# show relationship with upstream repository
export GIT_PS1_SHOWUPSTREAM=auto

# here follow a set of functions I have defined to compartmentalise my prompt a
# little. They make heavy use of ANSI terminal codes and \[ \], which are used
# to make colours/other styling like bolding, and indicate to Bash that they are
# non-printing, respectively.
# I have hardcoded all the ANSI escape codes for performance reasons - it seems
# to offer a speedup of over 50%, which is worthwile. The tput command used to
# obtain the sequence is also provided as a comment.
# Vim tput hardcoding macro (acts on next match of $(tput[^)]*)
# :let @q = "/\\$(tput[^)]*)\<CR>ft\"ayi(cgn\<C-r>\<C-r>=system(\"\<C-r>a\")\<CR>\<Esc>"
# initialise using 0fly$:<C-r><C-r>"<CR>
# fix escape sequences with :%s/<C-v>x1b/\\e/g (you have to type the proper
# sequences yourself)

# The two remaining targets for optimisation are probably reducing function
# overhead (that is, making the whole thing one disgusting, illegible,
# unmodifiable one-liner) and the apparix_prompt function, which takes a fair
# amount of time. See prompt_profile() later on.

# function which returns a code to make text green if exit status was
# successful, and red otherwise. Indicates the value of a non-zero return
# status. TAKES AN ARGUMENT
exitstatus_prompt() {
    if [[ "$1" == 0 ]]; then
        # echo -n "\[$(tput setaf 2)\]@"
        echo -n "\[\e[38;5;2m\]@"
    else
        # echo -n "\[$(tput setaf 1)\]($1)"
        echo -n "\[\e[38;5;1m\]($1)"
    fi
}

# function to format a nice SHLVL indicating prompt component, to warn about
# nested shells.
shlvl_prompt() {
    if [[ "$SHLVL" = 1 ]]; then
        # echo -n "\[$(tput setaf 7)\]|"
        echo -n "\[\e[38;5;7m\]|"
    else
        # echo -n "\[$(tput setaf 7)\][$SHLVL]"
        echo -n "\[\e[38;5;7m\][$SHLVL]"
    fi
}

# function which returns red if the user has root privileges, and magenta
# otherwise, displaying the username
user_prompt() {
    if [[ $EUID -ne 0 ]]; then
        # echo -n "\[$(tput setaf 5)\]\u"
        echo -n "\[\e[38;5;5m\]\u"
    else
        # echo -n "\[$(tput setaf 1)\]\1"
        echo -n "\[\e[38;5;1m\]\u"
    fi
}

# display PWD in full. Can be modified to display less by setting PROMPT_DIRTRIM
# PROMPT_DIRTRIM=2
dir_prompt() {
    # echo -n "\[$(tput setaf 6)\]$(dirs +0)"
    echo -n "\[\e[38;5;6m\]\w"
}

# function to display the host name
host_prompt() {
    # echo -n "\[$(tput setaf 3)\]\h"
    echo -n "\[\e[38;5;3m\]\h"
}

# function to display an apparix bookmark if you're in one.
# This is a little bit of a performance bottleneck, as indicated by
# prompt_profile. As far as I can see there aren't any really trivial
# optimisations left, and as it stands it's about 2-3 times slower than any
# other component
apparix_prompt() {
    # assume that amibm has empty output if it's unsuccessful, to avoid having
    # to re-run it
    # Check if apparix exists by checking if there is an amibm command.
    # Alternative might be to check if APPARIXHOME exists but this is I think
    # nicer
    if >/dev/null 2>&1 command -v amibm; then
        # escape backticks and dollars so that bash doesn't get confused about
        # command substitution
        local goedel_bm="$(amibm | sed 's/[$`]/\\&/g')"
        if [[ -n "$goedel_bm" ]]; then
            # echo -n " \[$(tput setaf 4)\]($goedel_bm)"
            echo -n " \[\e[38;5;4m\]($goedel_bm)"
        fi
    fi
}

if version_assert 4 3 0; then
    # tell the readline library to show a vi mode indicator.
    # this could go in inputrc, but I have my reasons that make it more
    # straightforward to just do it here, for Bash.
    bind "set show-mode-in-prompt on"
    # TODO: is there way to make this work nicely with search mode?
    # also TODO: can I put colours in here without breaking my prompt? who knows. it
    # doesn't seem to understand \[ and \]. Ideally I would have it act the way my
    # "pzsh" prompt looks, but I don't think it will be feasibly. Therefore, I have
    # it go between a character and no character for maximum visibility
    bind "set vi-ins-mode-string \"< >\""
    bind "set vi-cmd-mode-string \"<N>\""
    # this would colour in the matching part of what you're completing on
    # bind "set colored-completion-prefix"
else
    >&2 echo "(your bash is too old for a pretty Vi mode indicator)"
fi

# function to build a pretty looking prompt, inspired by Stijn van Dongen's
# taste in prompts, but with more colours.
goedel_prompt() {
    # it's important that this goes first, in order to get the exit status
    # before it runs out
    local GOEDEL_EXIT_STATUS="$?"
    # some prompt-escaped terminal codes for ease of reference
    # local iz_bold="\[$(tput bold)\]"
    # local iz_reset="\[$(tput sgr0)\]"
    local iz_bold="\[\e[1m\]"
    local iz_reset="\[\e[m\e(B\]"
    # construct the prompt from all the earlier components
    local iz_prompt="$iz_bold$(user_prompt)$(exitstatus_prompt "$GOEDEL_EXIT_STATUS")$(host_prompt)$(shlvl_prompt)$(dir_prompt)$(apparix_prompt)$iz_reset"

    # Inside here, I put the prompt to use. I've personally got it on two lines,
    # and padded by a line in front, as that's what I've gotten used to from my
    # zsh P10K prompt, but this is optional.

    # the first branch only works if you sourced git-prompt.sh earlier.
    if >/dev/null 2>&1 command -v __git_ps1; then
        # This last part uses __git_ps1 to inject some information about dirty
        # states and branches when in a git repository. This can be made much
        # prettier using just vanilla zsh, with the vcs_info autoload function.

        # The two arguments that __git_ps1 takes are a prefix to the git part of
        # the prompt, and a suffix. I leave the suffic as just a space.
        __git_ps1 $'\n'"$iz_prompt" $'\n'" $iz_bold\[\e[38;5;7m\]->$iz_reset "
    else
        PS1=$'\n'"$iz_prompt"$'\n'" $iz_bold\[\e[38;5;7m\]->$iz_reset "
    fi
}

PROMPT_COMMAND='goedel_prompt'

# small function to do a very simple profile of the different prompt components
prompt_profile() {
    LOOPS=200
    echo "Profiling each component with $LOOPS loops"
    for component in goedel_prompt user_prompt exitstatus_prompt host_prompt\
        shlvl_prompt dir_prompt apparix_prompt __git_ps1; do
        echo
        echo -n "$component..."
        time for ((i=0; i<LOOPS; i++)); do
            # mock some arguments for the component that want them
            >/dev/null 2>&1 "$component" 1 1
        done
    done
}
