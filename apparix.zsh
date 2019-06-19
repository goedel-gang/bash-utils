#                                               .__
# _____________   ______  ______ _____  _______ |__|___  ___
# \___   /\__  \  \____ \ \____ \\__  \ \_  __ \|  |\  \/  /
#  /    /  / __ \_|  |_> >|  |_> >/ __ \_|  | \/|  | >    <
# /_____ \(____  /|   __/ |   __/(____  /|__|   |__|/__/\_ \
#       \/     \/ |__|    |__|        \/                  \/
# FIGMENTIZE: zapparix

# Thin wrapper around Zsh's directory hashing, to provide an Apparix-like
# persistent bookmarking system.

# This script does frequently source $ZAPPARIXRC. If you think this will be a
# problem (eg for some reason a malicious agent has access to your $ZAPPARIXRC)
# you probably shouldn't use it.

# All you need to do is ensure that this script has been sourced, and then call
# `bm <mark>` when you're in a directory that you wish to assign the bookmark
# <mark> to. From then on, you can use ~<mark> anywhere where Zsh is doing
# filename expansion (which is everywhere), so for example you can cd, mv, vim,
# cat, you name it.

# Because it wraps hash, any bookmark must conform to hash's standards, so no
# messing around with spaces and equals signs. Also, any bookmark with prefix
# _GOEDEL_TEST is reserved for use within this script.

# Naturally, this integrates straight into Zsh's completion system, you can
# complete on hashed directories and any contained files or subdirectories, with
# all of your completion configuration just as you've set it.

# Another plus is that the Zsh prompt expansion %~ understands hashed
# directories, so most likely your prompt let you know when you're in one.

# If you're creating bookmarks across different running Zsh sessions, they
# shouldn't clobber one another but they won't update until you run `bm`, with
# or without arguments.

# Also provided is an unbm function, which removes a bookmark with a name. Both
# bm and unbm should provide feedback when you add or delete bookmarks.

# Be warned, this script quite bluntly clears and repopulates the list of
# directory hashes, so if you were using it for something else, either do this
# through zapparix or think of another solution.

# I know that many of these double quotes are probably redundant, but I've been
# writing a lot of Bash and don't have the mental capacity to keep two things
# separate. I might change it sometime, or if whoever is reading this really
# desparately cares, go wild!

ZAPPARIXHOME="${ZAPPARIXHOME:=$HOME/.config/zapparix}"
mkdir -p "$ZAPPARIXHOME"
ZAPPARIXRC="${ZAPPARIXRC:=$ZAPPARIXHOME/zapparixrc}"
touch "$ZAPPARIXRC"
ZAPPARIX_ACTIVE="${ZAPPARIX_ACTIVE:=true}"

typeset -ga ZAPP_DIFF_CMD

# check if diff has colours
if command diff --color=always <(echo abc) <(echo abc) 2>/dev/null; then
    ZAPP_DIFF_CMD=( diff --color=always )
else
    ZAPP_DIFF_CMD=( diff )
fi

alias via='"${EDITOR:-vim}" "$ZAPPARIXRC"'

# indicate differences between $ZAPPARIXRC" and "$ZAPPARIXRC.new"
function zapparix_change() {
    { ! "${ZAPP_DIFF_CMD[@]}" "$ZAPPARIXRC" "$ZAPPARIXRC.new" } || \
        { >&2 echo "no change"; return 1 }
}

function zapp_post() {
    if [ "$ZAPPARIX_ACTIVE" = "true" ]; then
        true
    else
        echo "\e[31mZapparix is inactive\e[0m"
        hash -dr
    fi
}

# If given an argument, create a bookmark with that name.
# Given no argument, it pretty-prints current bookmarks.
# This function serialises bookmarks to $ZAPPARIXRC, using the hash builtin's
# -L. This is a very straightforward step as hash will do all the escaping for
# us, and in fact we can use tabs in $ZAPPARIXRC because they will be escaped by
# hash.
function bm() {
    emulate -L zsh
    setopt pipefail nounset errreturn noclobber
    hash -dr
    source "$ZAPPARIXRC"
    if [[ -n "${1:-}" ]]; then
        mark="$1"
        touch "$ZAPPARIXRC"
        hash -d -- "$mark"="$PWD"
        {echo "# vim: ft=zsh"; hash -dL} > "$ZAPPARIXRC.new"
        zapparix_change || nochange=true
        command mv "$ZAPPARIXRC.new" "$ZAPPARIXRC"
        if [[ -n "${nochange:-}" ]]; then
            zapp_post
            return 1
        fi
    else
        {printf 'mark\ttarget\n';
         hash -dL | \
            grep -v "^#" | \
            sed -E -e 's/^hash -d( --)? //' -e 's/=/'$'\t''/'} | \
            column -t -s $'\t'
    fi
    zapp_post
}

# Toggle zapparix on or off
function zapp() {
    if [ "$ZAPPARIX_ACTIVE" = "false" ]; then
        ZAPPARIX_ACTIVE=true
        source "$ZAPPARIXRC"
        echo "\e[32mZapparix is now active"
    else
        ZAPPARIX_ACTIVE=false
        hash -dr
        echo "\e[31mZapparix is now inactive"
    fi
}

# If given an argument, any bookmarks with that name.
# Otherwise, remove any bookmarks to the current directory.
function unbm() {
    emulate -L zsh
    setopt pipefail nounset errreturn noclobber
    if [[ -n "${1:-}" ]]; then
        mark="$1"
        # remove lines either with hash -d -- $mark= or hash -d $mark= might
        # cause false positives in really truly bizarre circumstances, eg if you
        # like to name your directories "hash -d -- $mark=".
        command grep -v -F "hash -d $mark="$'\n'"hash -d -- $mark=" "$ZAPPARIXRC" \
            > "$ZAPPARIXRC.new"
    else
        # remove lines containing the (quote-escaped) current directory. This
        # seems to be what hash -dL uses to serialise. Again, maybe false
        # positives if you like to name your bookmarks after full directory
        # paths.
        # Avoid false positives due to subdirectories by appending two slashes
        # to mark the end. This avoids having to not use grep -F.
        # Determine how hash quote escaped it by making a dummy hash to it.
        # This dummy will be destroyed at the end of this function, during
        # refresh, anyway.
        hash -d -- _GOEDEL_TEST="$PWD"
        # probably this should be done with awk or perl or something
        quot_pwd="$(hash -dL | \
            command grep '^hash -d\( --\)\? _GOEDEL_TEST=' | \
            command sed -E 's/^hash -d( --)? _GOEDEL_TEST=//')"
        command sed 's#$#//#g' "$ZAPPARIXRC" | \
                command grep -v -F "=$quot_pwd//" | \
                command sed 's#//$##g' \
                > "$ZAPPARIXRC.new"
    fi
    zapparix_change || nochange=true
    command mv "$ZAPPARIXRC.new" "$ZAPPARIXRC"
    hash -dr
    source "$ZAPPARIXRC"
    zapp_post
    if [[ -n "${nochange:-}" ]]; then
        return 1
    fi
}

hash -dr
if [ "$ZAPPARIX_ACTIVE" = "true" ]; then
    source "$ZAPPARIXRC"
fi
