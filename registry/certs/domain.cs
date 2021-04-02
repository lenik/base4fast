#!/bin/bash
    . shlib-import mkcert.cs

    DN_C="CN"
    DN_ST="Zhejiang"
    DN_O="boDz Software Lab"
    DN_OU="Certificate Authority"
    DN_CN="localhost"
    DN_emailAddress="ca@bodz.net"

    main "$@"

