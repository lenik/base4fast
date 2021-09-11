#!/bin/bash

    dir="fonts"

    if [ -d $dir ]; then
        echo umount $dir
        sudo umount $dir
        for ((i = 0; i < 5; i++)); do
            if [ -d $dir ]; then
                rmdir -v $dir && break
            else
                break
            fi
            sleepenh 0.1 >/dev/null
        done
    fi

