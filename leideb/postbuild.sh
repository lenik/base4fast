#!/bin/bash

    dir=jdk-1.8.0.-64

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

