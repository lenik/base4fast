#!/bin/sh
    mkdir -vp jdk-1.8.0-64
    echo mount -t bind /opt/java/jdk-1.8.0-64 jdk-1.8.0-64
    sudo mount -t auto -o bind /opt/java/jdk-1.8.0-64 jdk-1.8.0-64

