#!/bin/bash
    echo umount jdk-1.8.0-64
    sudo umount jdk-1.8.0-64
    for ((i = 0; i < 5; i++)); do
        rmdir -v jdk-1.8.0-64 && break
    done

