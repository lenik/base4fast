#!/bin/bash
set -x

cd /etc/yum
    sed -i.backup 's/^enabled=1/enabled=0/' pluginconf.d/fastestmirror.conf

cd /etc/yum.repos.d
    mkdir bak
    for f in \
            CentOS-Base.repo \
            ; do
        [ -f "$f" ] && mv "$f" bak/
    done

    curl -o CentOS-Base.repo \
        http://mirrors.163.com/.help/CentOS7-Base-163.repo

    yum install -y epel-release

    for f in \
            epel.repo \
            epel-testing.repo \
            epel-7.repo \
            ; do
        if [ -f "$f" ]; then
            mv "$f" bak/
        fi
    done
    curl -o epel-7.repo \
        http://mirrors.aliyun.com/repo/epel-7.repo

cd /tmp
    curl -o remi-release-7.rpm \
        http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
    rpm -Uvh remi-release-7*.rpm

cd /root
    mkdir -p .pip
    touch .pip/pip.conf

    sed -i.backup \
        -r 's/^index-url\s*=\s*.+$/index-url = http:\/\/mirrors.aliyun.com\/pypi\/simple\//' \
        .pip/pip.conf

    # If file not changed, write contents back to pip.conf
        diff "~/.pip/pip.conf" "~/.pip/pip.conf.backup" &> /dev/null

    if [ $? -eq 0 ]; then
        cat > ~/.pip/pip.conf <<EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
EOF
    fi

