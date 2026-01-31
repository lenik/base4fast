FROM debian:buster
MAINTAINER Lenik <lenik@bodz.net>
LABEL \
    description = "Debian/GNU-Linux & uni tools" \
    version = "1.11"

COPY apt /etc/apt/
RUN /etc/apt/disable_orig_lists.sh; \
    apt-get update
RUN apt-get install -y --force-yes \
        2tree \
        ai-utils \
        apache2-enh \
        apt-enh \
        ascgen \
        autover \
        bash-alias \
        bash-enh \
        bash-ex \
        bash-shlib \
        catme \
        cdtree \
        configutils \
        coolauto \
        coolclip \
        coolcmd \
        cooldeb \
        cooldiff \
        coolgen \
        coolhex \
        coollog \
        coolmake \
        coolpdf \
        coolqt \
        coolrpm \
        coolsql \
        cooltask \
        cooltex \
        cooltext \
        coolutils \
        cwdex \
        debinst \
        dejar \
        diskutils \
        dltools \
        do-mount \
        dprog \
        emacs-pref-xjl \
        eplutils \
        err-demux \
        esperanto-dict \
        filestats \
        fileutils-xjl \
        gcc-enh \
        gcdutils \
        git-enh \
        git-fat \
        gpg-enh \
        grepl \
        hackscripts \
        imgauto \
        ini-utils \
        isoutils \
        isz-tool \
        jad \
        laxar \
        lddd \
        libbas-c \
        libbas-d-dev \
        libcmt-perl \
        libcpf \
        libcpf-dev \
        libdog-dev \
        libm4-xjl \
        libsqltiger-postgresql \
        libuni-java \
        lilygen \
        m2proj \
        mjpl \
        mkchm \
        mksize \
        modcmds \
        mountfile \
        ms-sys \
        msync \
        nameutils \
        npm-enh \
        onoff \
        openssl-enh \
        patchbuild \
        pingmon \
        python-enh \
        quickweb \
        repl \
        repos-styles \
        rrdtool-enh \
        rsync-rrc \
        screen-enh \
        shelj \
        sox-enh \
        sqlite-enh \
        squashfs-enh \
        ssh-enh \
        symlinkutils \
        textcodecs \
        ttc2ttf \
        ttfutils \
        tty-fx \
        usecode \
        vcscmds \
        vexmount \
        vim \
        vim-enh \
        visualcss \
        whichm \
        whoare \
        winedit \
        x509utils \
        xmlproc \
        xmlutils \
        yapp-enh \
        zhspeak \
        ziputils \
        z-latex

ENV LANG en_US.utf8
RUN sed -i \
        -e '/en_US.UTF-8/s/^# //g' \
        -e '/zh_CN.UTF-8/s/^# //g' \
        -e '/zh_TW.UTF-8/s/^# //g' \
        -e '/ja_JP.UTF-8/s/^# //g' \
        -e '/ko_KR.UTF-8/s/^# //g' \
        -e '/th_TH.UTF-8/s/^# //g' \
        /etc/locale.gen && \
    locale-gen

COPY apt/sources.list.d/bodz.list /etc/apt/sources.list.d/

COPY jdk-1.8.0/ /opt/java/jdk-1.8.0
RUN apt-get install -y --force-yes \
    coolmaven \
    jdk-local

COPY bash.bashrc /etc
COPY docker-clean /etc/apt/apt.conf.d

RUN groupadd --gid 700 dev; \
    groupmod --gid 300 wget; \
    usermod --uid 300 wget; \
    useradd --uid 999 -g dev -m -p l. lenik; \
    mkdir /home/lenik/.ssh
COPY authorized_keys /home/lenik/.ssh

ENTRYPOINT ["/bin/bash", "-i"]
