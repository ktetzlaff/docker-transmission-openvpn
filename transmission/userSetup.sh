#!/bin/bash

# More/less taken from https://github.com/linuxserver/docker-baseimage-alpine/blob/3eb7146a55b7bff547905e0d3f71a26036448ae6/root/etc/cont-init.d/10-adduser
source /etc/openvpn/utils.sh

RUN_AS=root

if [ -n "$PUID" ] && [ ! "$(id -u root)" -eq "$PUID" ]; then
    RUN_AS=abc
    if [ ! "$(id -u ${RUN_AS})" -eq "$PUID" ]; then
        usermod -o -u "$PUID" ${RUN_AS};
    fi
    if [ -n "$PGID" ] && [ ! "$(id -g ${RUN_AS})" -eq "$PGID" ]; then
        groupmod -o -g "$PGID" ${RUN_AS};
    fi

    if [[ "true" = "$LOG_TO_STDOUT" ]]; then
      chown ${RUN_AS}:${RUN_AS} /dev/stdout
    fi

    echo "TRANSMISSION_HOME is currently set to: ${TRANSMISSION_HOME}"
    if [[ "${TRANSMISSION_HOME%/*}" != "/config" ]]; then
            echo "WARNING: TRANSMISSION_HOME is not set to the default /config/<transmission-home>, this is not recommended."
            echo "TRANSMISSION_HOME should be set to /config/transmission-home OR another custom directory on /config/<directory>"
            echo "If you would like to migrate your existing TRANSMISSION_HOME, please stop the container, add volume /config and move the transmission-home directory there."
    fi
    #Old default transmission-home exists, use as fallback
    if [ -d "/data/transmission-home" ]; then
        TRANSMISSION_HOME="/data/transmission-home"
        echo "WARNING: Deprecated. Found old default transmission-home folder at ${TRANSMISSION_HOME}, setting this as TRANSMISSION_HOME. This might break in future versions."
        echo "We will fallback to this directory as long as the folder exists. Please consider moving it to /config/<transmission-home>"
    fi

    # Make sure directories exist before chown and chmod
    mkdir -p /config \
        "${TRANSMISSION_HOME}" \
        "${TRANSMISSION_DOWNLOAD_DIR}" \
        "${TRANSMISSION_INCOMPLETE_DIR}" \
        "${TRANSMISSION_WATCH_DIR}"

    echo "Enforcing ownership on transmission config directory"
    chown -R ${RUN_AS}:${RUN_AS} \
        /config

    echo "Applying permissions to transmission config directory"
    chmod -R go+X,u=rwX \
        /config

    if [ "$GLOBAL_APPLY_PERMISSIONS" = true ] ; then
        echo "Setting owner for transmission paths to ${PUID}:${PGID}"
        chown -R ${RUN_AS}:${RUN_AS} \
            "${TRANSMISSION_DOWNLOAD_DIR}" \
            "${TRANSMISSION_INCOMPLETE_DIR}" \
            "${TRANSMISSION_WATCH_DIR}"

        echo "Setting permissions for download and incomplete directories"
        TRANSMISSION_UMASK_OCTAL=$(printf '%03g' $(printf '%o\n' $(jq .umask ${TRANSMISSION_HOME}/settings.json)))
        DIR_PERMS=$(printf '%o\n' $((0777 & ~TRANSMISSION_UMASK_OCTAL)))
        FILE_PERMS=$(printf '%o\n' $((0666 & ~TRANSMISSION_UMASK_OCTAL)))
        echo "Mask: ${TRANSMISSION_UMASK_OCTAL}"
        echo "Directories: ${DIR_PERMS}"
        echo "Files: ${FILE_PERMS}"

        find "${TRANSMISSION_DOWNLOAD_DIR}" "${TRANSMISSION_INCOMPLETE_DIR}" -type d \
        -exec chmod $(printf '%o\n' $((0777 & ~TRANSMISSION_UMASK_OCTAL))) {} +
        find "${TRANSMISSION_DOWNLOAD_DIR}" "${TRANSMISSION_INCOMPLETE_DIR}" -type  f \
        -exec chmod $(printf '%o\n' $((0666 & ~TRANSMISSION_UMASK_OCTAL))) {} +

        echo "Setting permission for watch directory (775) and its files (664)"
        chmod -R o=rX,ug=rwX \
            "${TRANSMISSION_WATCH_DIR}"
    fi
fi

echo "
-------------------------------------
Transmission will run as
-------------------------------------
User name:   ${RUN_AS}
User uid:    $(id -u ${RUN_AS})
User gid:    $(id -g ${RUN_AS})
-------------------------------------
"

export PUID
export PGID
export RUN_AS
