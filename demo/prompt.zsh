#                                          __
# ______ _______   ____    _____  ______ _/  |_
# \____ \\_  __ \ /  _ \  /     \ \____ \\   __\
# |  |_> >|  | \/(  <_> )|  Y Y  \|  |_> >|  |
# |   __/ |__|    \____/ |__|_|  /|   __/ |__|
# |__|                         \/ |__|
# FIGMENTIZE: prompt

# alternative prompt without any plugins or fancy fonts. Basically emulates
# the important bits of my powerline prompt
autoload -Uz vcs_info
function precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
# RPROMPT=\$vcs_info_msg_0_
# PROMPT=\$vcs_info_msg_0_'%# '
# basically ripped from man zshcontrib
# yet to customize more
# need to use %%b for bold off
# TODO: customise this for dirty state
zstyle ':vcs_info:*' actionformats \
    '%K{002}%F{000} (%s)-[%b|%a]%u%c %f%k'
zstyle ':vcs_info:*' formats       \
    '%K{002}%F{000} (%s)-[%b]%u%c %f%k'
zstyle ':vcs_info:*' stagedstr "*"
zstyle ':vcs_info:*' unstagedstr "+"
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b:%r'
# don't waste time on VCS that nobody uses
zstyle ':vcs_info:*' enable git cvs svn hg
zstyle ':vcs_info:*' check-for-changes true

# right prompt with some information
status_prompt="%F{000}%(?.%F{002}OK .%K{001}%B%F{003} %? %b)"
shlvl_prompt="%(2L.%F{000}%K{003} %L .)"
hist_prompt="%K{004}%F{000} %h %k%f"
RPROMPT="$status_prompt$shlvl_prompt$hist_prompt"

function zle-line-init zle-keymap-select {
    # notify-send "$(date +%M:%S) zle $KEYMAP"
    case "$KEYMAP" in
        main|viins)
            vi_colour=006
            ;;
        vicmd)
            vi_colour=005
            ;;
        *)
            vi_colour=015
            ;;
    esac
    zle reset-prompt
    # _p9k_zle_keymap_select
}

zle -N zle-line-init
zle -N zle-keymap-select

# two-line prompt, with a blank line behind it.
# If zsh is in apparix mode, also indicate the current bookmark
if [ "$GOEDEL_APPARIX" = "true" ]; then
    function apparix_prompt {
        iz_bm="$(amibm)"
        if [ -n "$iz_bm" ]; then
            echo " $iz_bm "
        fi
    }
    apparix_indicator="%K{cyan}%F{black}\$(apparix_prompt)"
else
    apparix_indicator=""
fi
host_prompt="%(!.%F{003}%K{001}.%F{000}%K{003}) %n@%m "
dir_prompt="%F{000}%K{004} %~ "
PROMPT=$'\n'"%F{\$vi_colour}┌─$host_prompt$dir_prompt$apparix_indicator%k\$vcs_info_msg_0_"$'\n%F{\$vi_colour}└─%f '
PROMPT2=".. "
RPROMPT2="%K{cyan} %^ %k"
