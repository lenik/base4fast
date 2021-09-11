#!/bin/bash

    #fontsdir=`mktemp -d`
    fontsdir=/tmp/fonts.copy; mkdir -p $fontsdir

    #cp -aL fonts $fontsdir
    echo "copy actual font files to $fontsdir"
    rsync -amL --delete fonts.prep/* $fontsdir/

    dir=fonts
    if [ ! -d "$dir/zh" ]; then
        mkdir -p $dir
        echo mount -t auto -o bind $fontsdir $dir
        sudo mount -t auto -o bind $fontsdir $dir
    fi

