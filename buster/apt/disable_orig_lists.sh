#!/bin/sh

if [ -f /etc/apt/sources.list ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.orig
    touch /etc/apt/sources.list
fi

exit 0
