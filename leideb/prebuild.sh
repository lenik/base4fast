#!/bin/bash

    dir=jdk-1.8.0-64

    if [ ! -d "$dir/bin" ]; then
        mkdir -vp $dir
        echo mount -t auto -o bind /opt/java/jdk-1.8.0* $dir
        sudo mount -t auto -o bind /opt/java/jdk-1.8.0* $dir
    fi

    cp -a $HOME/.ssh/authorized_keys .

