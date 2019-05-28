# FIGMENTIZE: prompt
#                                          __
# ______ _______   ____    _____  ______ _/  |_
# \____ \\_  __ \ /  _ \  /     \ \____ \\   __\
# |  |_> >|  | \/(  <_> )|  Y Y  \|  |_> >|  |
# |   __/ |__|    \____/ |__|_|  /|   __/ |__|
# |__|                         \/ |__|

# file that sets up my flashy bashy prompt

# This is a redacted version of the one at goedel-gang/dotfiles/master/.bash
# which has a Git segment and a vi-mode indicator.

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

# function which returns magenta if the user has root privileges, and yellow
# otherwise
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
    local goedel_bm="$(amibm)"
    if [[ -n "$goedel_bm" ]]; then
        # echo -n " \[$(tput setaf 4)\]($goedel_bm)"
        echo -n " \[\e[38;5;4m\]($goedel_bm)"
    fi
}

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
    if silent command -v __git_ps1; then
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
            silent "$component" 1 1
        done
    done
}
