#!/usr/bin/env bash
# Usage: ./build.sh [<variant>] [<working-dir>]

variant="$1"
working_dir="$2"

start_time=$(date +%s)

base_dir="$(dirname "$(realpath -s "$0")")"
buildinfo_file="$base_dir/src/sysroot/common/usr/lib/sodalite-buildinfo"
tests_dir="$base_dir/tests"

git_commit=""
git_tag=""
unified="false"
vendor=""

function emj() {
    emoji="$1"
    emoji_length=${#emoji}
    echo "$emoji$(eval "for i in {1..$emoji_length}; do echo -n " "; done")"
}

function die() {
    echo -e "$(emj "🛑")\033[1;31mError: $@\033[0m"
    cleanup
    exit 255
}

function cleanup() {
    echo "$(emj "🗑️")Cleaning up..."

    rm -f "$buildinfo_file"
    rm -rf /var/tmp/rpm-ostree.*

    if [[ $SUDO_USER != "" ]]; then
        chown -R $SUDO_USER:$SUDO_USER "$working_dir"
    fi
}

function nudo() { # "Normal User DO"
    cmd="$@"
    eval_cmd="$cmd"

    if [[ $SUDO_USER != "" ]]; then
        eval_cmd="sudo -E -u $SUDO_USER $eval_cmd"
    fi

    eval "$eval_cmd"
}

function print_time() {
    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    h_string="hours"
    m_string="minutes"
    s_string="seconds"

    [[ $h == 1 ]] && h_string="hour"
    [[ $m == 1 ]] && m_string="minute"
    [[ $s == 1 ]] && s_string="second"

    output=""

    [[ $h != "0" ]] && output+="$h $h_string"
    [[ $m != "0" ]] && output+=" $m $m_string"
    [[ $s != "0" ]] && output+=" $s $s_string"

    echo $output
}

function ost() {
    command=$1
    options="${@:2}"

    if [[ -z $ostree_repo_dir ]]; then
        die "\$ostree_repo_dir not set"
    fi

    ostree $command --repo="$ostree_repo_dir" $options
}


if ! [[ $(id -u) = 0 ]]; then
    die "Permission denied (are you root?)"
fi

if [[ ! $(command -v "rpm-ostree") ]]; then
    die "rpm-ostree not installed"
fi

[[ $variant == "budgie" ]] && variant="desktop-budgie"
[[ $variant == "deepin" ]] && variant="desktop-deepin"
[[ $variant == "pantheon" ]] && variant="desktop"

echo "$(emj "🪛")Setting up..."

[[ $variant == *.yaml ]] && variant="$(echo $variant | sed s/.yaml//)"
[[ $variant == sodalite* ]] && variant="$(echo $variant | sed s/sodalite-//)"
[[ -z $variant ]] && variant="custom"
[[ -z "$working_dir" ]] && working_dir="$base_dir/build"

if [[ $(command -v "git") ]]; then
    if [[ -d "$base_dir/.git" ]]; then
        git config --global --add safe.directory $base_dir

        git_commit=$(git -C $base_dir rev-parse --short HEAD)
        git_origin_url="$(git config --get remote.origin.url)"

        if [[ "$(git -C $base_dir status --porcelain --untracked-files=no)" == "" ]]; then
            git_tag="$(git -C $base_dir describe --exact-match --tags $(git -C $base_dir log -n1 --pretty='%h') 2>/dev/null)"
        fi

        if [[ "$git_origin_url" != "" ]]; then
            if [[ "$git_origin_url" =~ ([a-zA-Z0-9.-_]+\@[a-zA-Z0-9.-_]+:([a-zA-Z0-9.-_]+)\/([a-zA-Z0-9.-_]+).git) ]]; then
                vendor="${BASH_REMATCH[2]}"
            elif [[ "$git_origin_url" =~ (https:\/\/github.com\/([a-zA-Z0-9.-_]+)\/([a-zA-Z0-9.-_]+).git) ]]; then
                vendor="${BASH_REMATCH[2]}"
            fi
        fi

        echo "$(emj "🗑️")Cleaning up Git repository..."
        nudo git fetch --prune
        nudo git fetch --prune-tags
    fi
fi

build_meta_dir="$working_dir/meta/$git_commit"
ostree_cache_dir="$working_dir/cache"
ostree_repo_dir="$working_dir/repo"
lockfile="$base_dir/src/shared/overrides.yaml"
treefile="$base_dir/src/treefiles/sodalite-$variant.yaml"

mkdir -p $ostree_cache_dir
mkdir -p $ostree_repo_dir
mkdir -p $build_meta_dir
chown -R root:root "$working_dir"

[[ ! -f $treefile ]] && die "sodalite-$variant does not exist"
[[ $variant == *"-unified" ]] && unified="true"

ref="$(echo "$(cat "$treefile")" | grep "ref:" | sed "s/ref: //" | sed "s/\${basearch}/$(uname -m)/")"

if [ ! "$(ls -A $ostree_repo_dir)" ]; then
   echo "$(emj "🆕")Initializing OSTree repository..."
   ost init --mode=archive
fi

buildinfo_content="AWESOME=\"Yes.\"
\nBUILD_DATE=\"$(date +"%Y-%m-%d %T %z")\"
\nBUILD_HOST_KERNEL=\"$(uname -srp)\"
\nBUILD_HOST_NAME=\"$(hostname -f)\"
\nBUILD_HOST_OS=\"$(cat /usr/lib/os-release | grep "PRETTY_NAME" | sed "s/PRETTY_NAME=//" | tr -d '"')\"
\nBUILD_TOOL=\"rpm-ostree $(echo "$(rpm-ostree --version)" | grep "Version:" | sed "s/ Version: //" | tr -d "'")+$(echo "$(rpm-ostree --version)" | grep "Git:" | sed "s/ Git: //")\"
\nGIT_COMMIT=$git_commit
\nGIT_TAG=$git_tag
\nOS_REF=\"$ref\"
\nOS_UNIFIED=$unified
\nOS_VARIANT=\"$variant\"
\nVENDOR=\"$vendor\""

echo -e $buildinfo_content > $buildinfo_file

echo "$(emj "⚡")Building tree..."
echo "================================================================================"

if [[ $SODALITE_BUILD_DRY_BUILD_SLEEP == "" ]]; then
    compose_args=""
    compose_cmd="rpm-ostree compose tree"

    compose_args+="--repo=\"$ostree_repo_dir\""
    [[ $ostree_cache_dir != "" ]] && compose_args+=" --cachedir=\"$ostree_cache_dir\""
    [[ -s $lockfile ]] && compose_args+=" --ex-lockfile=\"$lockfile\""
    [[ $unified == "true" ]] && compose_args+=" --unified-core"

    compose_cmd="$compose_cmd $compose_args $treefile"

    eval "$compose_cmd"
else
    echo "Doing things..."
    sleep $SODALITE_BUILD_DRY_BUILD_SLEEP
fi

[[ $? != 0 ]] && build_failed="true"

echo "================================================================================"

[[ $build_failed == "true" ]] && die "Failed to build tree"

test_failed_count=0

if [[ -d $tests_dir ]]; then
    if (( $(ls -A "$tests_dir" | wc -l) > 0 )); then
        echo "$(emj "🧪")Testing tree..."

        all_commits="$(ost log $ref | grep "commit " | sed "s/commit //")"
        commit="$(echo "$all_commits" | head -1)"
        commit_prev="$(echo "$all_commits" | head -2 | tail -1)"

        [[ $commit == $commit_prev ]] && commit_prev=""

        for test_file in $tests_dir/*.sh; do
            export -f ost

            result=$(. "$test_file" 2>&1)

            if [[ $? -ne 0 ]]; then
                test_message_prefix="Error"
                test_message_color="33"
                ((test_failed_count++))
            else
                if [[ $result != "true" ]]; then
                    test_message_prefix="Fail"
                    test_message_color="31"
                    ((test_failed_count++))
                else
                    test_message_prefix="Pass"
                    test_message_color="32"
                fi
            fi

            echo -e "   ⤷ \033[0;${test_message_color}m${test_message_prefix}: $(basename "$test_file" | cut -d. -f1)\033[0m"

            if [[ $result != "true" ]]; then
                if [[ ! -z $result ]] && [[ $result != "false" ]]; then
                    echo -e "     \033[0;37m${result}\033[0m"
                fi
            fi
        done
    fi
fi

if (( $test_failed_count > 0 )); then
    die "Failed to satisfy tests ($test_failed_count failed). Removing commit '$commit'..."

    if [[ -z $commit_prev ]]; then
        ost refs --delete $ref
    else
        ost reset $ref $commit_prev
    fi
else
    echo "$(emj "✏️")Generating summary..."
    ost summary --update
fi

end_time=$(( $(date +%s) - $start_time ))
highscore="false"
highscore_file="$build_meta_dir/highscore"
prev_highscore=""

if [[ ! -f "$highscore_file" ]]; then
    touch "$highscore_file"
    echo "$end_time" > "$highscore_file"
else
    prev_highscore="$(cat "$highscore_file")"
    if (( $end_time < $prev_highscore )); then
        highscore="true"
        echo "$end_time" > "$highscore_file"
    fi
fi

cleanup

echo "$(emj "✅")Success ($(print_time $end_time))"
[[ $highscore == "true" ]] && echo "🏆 You're Winner (previous: $(print_time $prev_highscore))!"
