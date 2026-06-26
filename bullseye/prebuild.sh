#!/bin/bash

    for dir in jdk-21.0.7; do
        if [ ! -d "$dir/bin" ]; then
            mkdir -vp $dir
            echo mount -t auto -o bind /opt/java/$dir $dir
            sudo mount -t auto -o bind /opt/java/$dir $dir
        fi
    done

    cp -a $HOME/.ssh/authorized_keys .

