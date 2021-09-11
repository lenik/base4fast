#!/bin/bash

    dir=tex

    if [ ! -d "$dir/bin" ]; then
        mkdir -vp $dir
        echo mount -t auto -o bind /usr/local/tex $dir
        sudo mount -t auto -o bind /usr/local/tex $dir
    fi

