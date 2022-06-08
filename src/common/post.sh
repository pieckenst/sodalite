#!/usr/bin/env bash

buildinfo_file="/usr/lib/sodalite-buildinfo"

function del_property() {
    file=$1
    property=$2
    
    if [[ -f $file ]]; then
        if [[ ! -z $(get_property $file $property) ]]; then
            sed -i "s/^\($property=.*\)$//g" $file
        fi
    fi
}

function get_property() {
    file=$1
    property=$2

    if [[ -f $file ]]; then
        echo $(grep -oP '(?<=^'"$property"'=).+' $file | tr -d '"')
    fi
}

function set_property() {
    file=$1
    property=$2
    value=$3

    if [[ -f $file ]]; then
        if [[ -z $(get_property $file $property) ]]; then
            echo "$property=\"$value\"" >> $file
        else
            if [[ $value =~ [[:space:]]+ ]]; then
                value="\"$value\""
            fi

            sed -i "s/^\($property=\)\(.*\)$/\1$value/g" $file
        fi
    fi
}

set -xeuo pipefail

if [[ $(cat $buildinfo_file) != "" ]]; then
    [[ -z $(get_property $buildinfo_file "GIT_TAG") ]] && \
        version_tag="$(get_property $buildinfo_file "GIT_COMMIT")"
    [[ ! -z $(get_property $buildinfo_file "VARIANT") ]] && \
        variant="$(get_property $buildinfo_file "VARIANT")"
fi

###################
# OSTREE MUTATING #
###################

cpe="cpe:\/o:sodaliterocks:sodalite" # cpe:/<part>:<vendor>:<product>:<version>:<update>:<edition>:<language>

if [[ $(get_property /etc/os-release VERSION) =~ (([0-9]{1,3})-([0-9]{2}.[0-9]{1,})(.([0-9]{1,}){0,1}).+) ]]; then
    version="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    version_id="${BASH_REMATCH[2]}"

    [[ ${BASH_REMATCH[5]} > 0 ]] && version+=".${BASH_REMATCH[5]}"
    [[ ! -z $version_tag ]] && version+="+$version_tag"
    [[ ! -z $variant ]] && [[ $variant != "base" ]] && version_pretty="$version ($variant)"

    cpe+=":$version_id:$(echo $version | cut -f2- -d"-")"
else
    version=$(get_property /etc/os-release VERSION)
    version_id=$(get_property /etc/os-release VERSION_ID)
    version_pretty="$version"

    cpe+=":$version_id:-"
fi

if [[ ! -z $variant ]]; then
    set_property /usr/lib/os-release "VARIANT" $variant
    set_property /usr/lib/os-release "VARIANT_ID" $variant

    cpe+=":$variant"
fi

if [[ ! -z $version_id ]]; then
    set_property /etc/upstream-release/lsb-release "ID" "fedora"
    set_property /etc/upstream-release/lsb-release "PRETTY_NAME" "Fedora Linux $version_id"
    set_property /etc/upstream-release/lsb-release "VERSION_ID" "$version_id"
fi

pretty_name="Sodalite $version_pretty"

set_property /usr/lib/os-release "BUG_REPORT_URL" "https:\/\/sodalite.rocks\/bug-report"
set_property /usr/lib/os-release "CPE_NAME" "$cpe"
set_property /usr/lib/os-release "DOCUMENTATION_URL" "https:\/\/sodalite.rocks\/docs"
set_property /usr/lib/os-release "HOME_URL" "https:\/\/sodalite.rocks"
set_property /usr/lib/os-release "ID" "sodalite"
set_property /usr/lib/os-release "ID_LIKE" "fedora"
set_property /usr/lib/os-release "NAME" "Sodalite"
set_property /usr/lib/os-release "PRETTY_NAME" "$pretty_name"
set_property /usr/lib/os-release "SUPPORT_URL" "https:\/\/sodalite.rocks\/support"
set_property /usr/lib/os-release "VERSION" "$version_pretty"
set_property /usr/lib/os-release "VERSION_ID" "$version_id"

del_property /usr/lib/os-release "ANSI_COLOR"
del_property /usr/lib/os-release "PRIVACY_POLICY_URL"
del_property /usr/lib/os-release "REDHAT_BUGZILLA_PRODUCT"
del_property /usr/lib/os-release "REDHAT_BUGZILLA_PRODUCT_VERSION"
del_property /usr/lib/os-release "REDHAT_SUPPORT_PRODUCT"
del_property /usr/lib/os-release "REDHAT_SUPPORT_PRODUCT_VERSION"
del_property /usr/lib/os-release "VERSION_CODENAME"

sed -i "/^$/d" /usr/lib/os-release

echo "$pretty_name" > /usr/lib/sodalite-release
echo "$pretty_name" > /usr/lib/system-release
echo $(echo "$cpe" | sed "s@\\\\@@g") > /usr/lib/system-release-cpe

rm /etc/os-release
rm /etc/system-release
rm /etc/system-release-cpe

ln -s /usr/lib/os-release /etc/os-release
ln -s /usr/lib/sodalite-release /etc/sodalite-release
ln -s /usr/lib/system-release /etc/system-release
ln -s /usr/lib/system-release-cpe /etc/system-release-cpe

#########
# HACKS #
#########

# TODO: Work out if we even need some of these, as the related issues are
#       pretty old.

# BUG: https://github.com/projectatomic/rpm-ostree/issues/1542#issuecomment-419684977
for x in /etc/yum.repos.d/*modular.repo; do
    sed -i -e 's,enabled=[01],enabled=0,' ${x}
done

# BUG: https://bugzilla.redhat.com/show_bug.cgi?id=1265295
if ! grep -q '^Storage=persistent' /etc/systemd/journald.conf; then
    (cat /etc/systemd/journald.conf && echo 'Storage=persistent') > /etc/systemd.journald.conf.new
    mv /etc/systemd.journald.conf{.new,}
fi

# SEE: https://src.fedoraproject.org/rpms/glibc/pull-request/4
# Basically that program handles deleting old shared library directories
# mid-transaction, which never applies to rpm-ostree. This is structured as a
# loop/glob to avoid hardcoding (or trying to match) the architecture.
for x in /usr/sbin/glibc_post_upgrade.*; do
    if test -f ${x}; then
        ln -srf /usr/bin/true ${x}
    fi
done

# SEE: https://github.com/coreos/fedora-coreos-tracker/issues/1139
# rpm in Fedora 36 has moved location and symlinks to /usr/lib/sysimage/rpm,
# which already exists, so we'll just delete it until the issue is fixed in the
# upstream
if [[ $version_id -gt 35 ]]; then
    rm -rf /usr/lib/sysimage/rpm
fi

# BUG: Parent Controls doesn't appear to work correctly for Fedora versions
#      under 35. We'll remove various things immediately visible to the user,
#      but leave `malcontent-control` intact.

if [[ $version_id -lt 36 ]]; then
    rm -f "/usr/share/applications/org.freedesktop.MalcontentControl.desktop"
    rm -f "/usr/lib64/switchboard/system/libparental-controls.so"
    rm -rf "/usr/share/doc/switchboard-plug-parental-controls/"
fi

############
# REMOVALS #
############

# HACK: Removing files here instead because we're not using --unified-core
#       (see https://github.com/sodaliterocks/sodalite/issues/9#issuecomment-1010384738)

declare -a to_remove=(
    # evolution-data-server
    "/etc/xdg/autostart/org.gnome.Evolution-alarm-notify.desktop"
    "/usr/libexec/evolution-data-server/evolution-alarm-notify"
    # fedora-workstation-backgrounds
    "/usr/share/backgrounds/fedora-workstation/"
    "/usr/share/doc/fedora-workstation-backgrounds/"
    "/usr/share/gnome-background-properties/fedora-workstation-backgrounds.xml"
    "/usr/share/licenses/fedora-workstation-backgrounds"
    # firefox
    "/usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js"
    # gnome-control-center
    #"/usr/bin/gnome-control-center"
    "/usr/libexec/cc-remote-login-helper"
    "/usr/libexec/gnome-control-center-print-renderer"
    "/usr/libexec/gnome-control-center-search-provider"
    "/usr/share/applications/gnome-applications-panel.desktop"
    "/usr/share/applications/gnome-background-panel.desktop"
    "/usr/share/applications/gnome-bluetooth-panel.desktop"
    "/usr/share/applications/gnome-camera-panel.desktop"
    "/usr/share/applications/gnome-color-panel.desktop"
    "/usr/share/applications/gnome-control-center.desktop"
    "/usr/share/applications/gnome-datetime-panel.desktop"
    "/usr/share/applications/gnome-default-apps-panel.desktop"
    "/usr/share/applications/gnome-diagnostics-panel.desktop"
    "/usr/share/applications/gnome-display-panel.desktop"
    "/usr/share/applications/gnome-info-overview-panel.desktop"
    "/usr/share/applications/gnome-keyboard-panel.desktop"
    "/usr/share/applications/gnome-location-panel.desktop"
    "/usr/share/applications/gnome-lock-panel.desktop"
    "/usr/share/applications/gnome-microphone-panel.desktop"
    "/usr/share/applications/gnome-mouse-panel.desktop"
    "/usr/share/applications/gnome-multitasking-panel.desktop"
    "/usr/share/applications/gnome-network-panel.desktop"
    "/usr/share/applications/gnome-notifications-panel.desktop"
    "/usr/share/applications/gnome-online-accounts-panel.desktop"
    "/usr/share/applications/gnome-power-panel.desktop"
    "/usr/share/applications/gnome-printers-panel.desktop"
    "/usr/share/applications/gnome-region-panel.desktop"
    "/usr/share/applications/gnome-removable-media-panel.desktop"
    "/usr/share/applications/gnome-search-panel.desktop"
    "/usr/share/applications/gnome-sharing-panel.desktop"
    "/usr/share/applications/gnome-sound-panel.desktop"
    "/usr/share/applications/gnome-thunderbolt-panel.desktop"
    "/usr/share/applications/gnome-universal-access-panel.desktop"
    "/usr/share/applications/gnome-usage-panel.desktop"
    "/usr/share/applications/gnome-user-accounts-panel.desktop"
    "/usr/share/applications/gnome-wacom-panel.desktop"
    "/usr/share/applications/gnome-wifi-panel.desktop"
    "/usr/share/applications/gnome-wwan-panel.desktop"
    "/usr/share/bash-completion/completions/gnome-control-center"
    "/usr/share/dbus-1/services/org.gnome.ControlCenter.SearchProvider.service"
    "/usr/share/dbus-1/services/org.gnome.ControlCenter.service"
    "/usr/share/doc/gnome-control-center/"
    "/usr/share/glib-2.0/schemas/org.gnome.ControlCenter.gschema.xml"
    "/usr/share/gnome-control-center/"
    "/usr/share/gnome-shell/search-providers/gnome-control-center-search-provider.ini"
    "/usr/share/locale/*/LC_MESSAGES/gnome-control-center-2.0.mo"
    "/usr/share/locale/*/LC_MESSAGES/gnome-control-center-2.0-timezones.mo"
    "/usr/share/man/man1/gnome-control-center.1.gz"
    "/usr/share/metainfo/gnome-control-center.appdata.xml"
    "/usr/share/polkit-1/actions/org.gnome.controlcenter.datetime.policy"
    "/usr/share/polkit-1/actions/org.gnome.controlcenter.remote-login-helper.policy"
    "/usr/share/polkit-1/actions/org.gnome.controlcenter.user-accounts.policy"
    "/usr/share/polkit-1/rules.d/gnome-control-center.rules"
    "/usr/share/sounds/gnome/"
    # gnome-session
    "/usr/share/wayland-sessions/gnome.desktop"
    "/usr/share/wayland-sessions/gnome-wayland.desktop"
    "/usr/share/xsessions/gnome.desktop"
    "/usr/share/xsessions/gnome-xorg.desktop"
    # light-locker
    "/etc/xdg/autostart/light-locker.desktop"
    # plank
    "/etc/xdg/autostart/plank.desktop"
    # ufw
    "/etc/ufw/"
    "/usr/lib/python3.10/site-packages/ufw/"
    "/usr/lib/systemd/system/ufw.service"
    "/usr/libexec/ufw/"
    "/usr/sbin/ufw"
    "/usr/share/doc/ufw/"
    "/usr/share/licenses/ufw/"
    "/usr/share/locale/*/LC_MESSAGES/ufw.mo"
    "/usr/share/man/man8/ufw-framework.8.gz"
    "/usr/share/man/man8/ufw.8.gz"
    "/usr/share/ufw/"
    # misc.
    "/usr/share/bookmarks/"
    "/usr/share/icewm/"
    "/usr/share/pixmaps/faces/"
)

if [[ $variant != "experimental-pantheon-nightly" ]]; then
    # These Pantheon packages are considered broken, so we'll only keep them
    # for this variant
    to_remove+=(
        # switchboard-plug-locale
        "/usr/lib64/switchboard/personal/liblocale-plug.so"
        "/usr/share/doc/switchboard-plug-locale/"
    )
fi

for file in ${to_remove[@]}; do
    rm -rf $file
done

########
# MISC #
########

# Sets background for System (in Switchboard) to use behind the logo
ln -s $(get_property /usr/share/glib-2.0/schemas/io.elementary.desktop.gschema.override picture-uri | sed -E 's/file:\/\///' | sed -E "s/'//g") /usr/share/backgrounds/elementaryos-default

glib-compile-schemas /usr/share/glib-2.0/schemas

systemctl disable gdm
systemctl enable generate-oemconf
systemctl enable lightdm
systemctl enable touchegg
systemctl enable update-appcenter-flatpak
