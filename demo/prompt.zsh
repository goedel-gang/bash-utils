# Zsh prompt with vi mode indicator, git information, and powerline-ey filled in
# background. Known to not look terrible in gruvbox colours.
# This prompt taken from
# goedel-gang/dotfiles/master/.zsh/prompts
# it's not the one I actually use. as I use powerlevel10k. I have also written a
# custom p10k segment for apparix that can be found at the aforementioned
# location.

autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
setopt transient_rprompt
# RPROMPT=\$vcs_info_msg_0_
# PROMPT=\$vcs_info_msg_0_'%# '
# basically ripped from man zshcontrib
# yet to customize more
# need to use %%b for bold off
# TODO: customise this for dirty state
zstyle ':vcs_info:*' actionformats \
    '%K{green}%F{black} (%s)-[%b|%a]%u%c %f%k'
zstyle ':vcs_info:*' formats       \
    '%K{green}%F{black} (%s)-[%b]%u%c %f%k'
zstyle ':vcs_info:*' stagedstr "*"
zstyle ':vcs_info:*' unstagedstr "+"
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b:%r'
# don't waste time on VCS that nobody uses
zstyle ':vcs_info:*' enable git cvs svn hg
zstyle ':vcs_info:*' check-for-changes true

# right prompt with some information
status_prompt="%F{black}%(?.%F{green}OK .%K{red}%B%F{yellow} %? %b)"
shlvl_prompt="%(2L.%F{black}%K{yellow} %L .)"
hist_prompt="%K{blue}%F{black} %h %k%f"
RPROMPT="$status_prompt$shlvl_prompt$hist_prompt"

function zle-line-init zle-keymap-select {
    # notify-send "$(date +%M:%S) zle $KEYMAP"
    case "$KEYMAP" in
        main|viins)
            vi_colour=cyan
            ;;
        vicmd)
            vi_colour=magenta
            ;;
        *)
            vi_colour=white
            ;;
    esac
    zle reset-prompt
    # _p9k_zle_keymap_select
}

zle -N zle-line-init
zle -N zle-keymap-select

# two-line prompt, with a blank line behind it.
# If zsh is in apparix mode, also indicate the current bookmark
if [[ "$GOEDEL_APPARIX" == "true" ]]; then
    function apparix_prompt {
        iz_bm="$(amibm)"
        if [[ -n "$iz_bm" ]]; then
            echo " $iz_bm "
        fi
    }
    apparix_indicator="%K{cyan}%F{black}\$(apparix_prompt)"
else
    apparix_indicator=""
fi
host_prompt="%(!.%F{yellow}%K{red}.%F{black}%K{yellow}) %n@%m "
dir_prompt="%F{black}%K{blue} %~ "
PROMPT=$'\n'"%F{\$vi_colour}┌─$host_prompt$dir_prompt$apparix_indicator%k\$vcs_info_msg_0_"$'\n%F{\$vi_colour}└─%f '
PROMPT2=".. "
RPROMPT2="%_"
