#!/bin/bash
    : ${RCSID:=$Id: - @VERSION@ @DATE@ @TIME@ - $}
    : ${PACKAGE:=@PACKAGE@}
    : ${PROGRAM_TITLE:=Docker postgresql startup script}
    : ${PROGRAM_SYNTAX:=[OPTIONS] [--] ...}

    . shlib-import cliboot
    option -q --quiet
    option -v --verbose
    option -h --help
    option    --version

function setopt() {
    case "$1" in
        -h|--help)
            help $1; exit;;
        -q|--quiet)
            LOGLEVEL=$((LOGLEVEL - 1));;
        -v|--verbose)
            LOGLEVEL=$((LOGLEVEL + 1));;
        --version)
            show_version; exit;;
        *)
            quit "invalid option: $1";;
    esac
}

function main() {
    if [ ! -d /etc/postgresql/$PG_MAJOR/main ]; then
        _log1 "Create main cluster..."
        if ! pg_createcluster -d $PGDATA $PG_MAJOR main; then
            quit "Failed to create the main cluster."
        fi
    fi
    /etc/init.d/postgresql start
}

boot "$@"
