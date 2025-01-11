#!/usr/bin/sudo /bin/bash

# 嵌入日志
source core/log.sh
# 嵌入定制命令
source core/chroot.sh

before() {
    # 嵌入安装应用
    source ubuntu/install.sh
    # 嵌入安装应用
    source ubuntu/uninstall.sh

    install 安装镜像定制软件 squashfs-tools genisoimage isolinux xorriso debootstrap
    trap 'uninstall 移除镜像定制软件 squashfs-tools genisoimage isolinux xorriso debootstrap' EXIT
}

check() {
    workspace=$1

    log INFO 检查工作区目录是否存在
    if [ ! -d "${workspace}" ]; then
        log INFO 创建工作区 "directory=${workspace}"
        mkdir --parents "${workspace}"
    fi
}

auth() {
    if [[ -n ${username} ]]; then # 创建用户
        gid=1000
        uid=1000
        customize "${basedir}" 创建用户组 groupadd --gid ${uid} --system "${username}"
        customize "${basedir}" 创建用户 useradd --uid ${uid} --gid ${gid} --system "${username}" --home-dir /home/"${username}"
    fi

    if [[ -n ${password} ]]; then # 配置密码
        customize "${basedir}" 设置用户密码 echo "${username}:${password}" | chpasswd
    fi

    if [[ -n ${root_password} ]]; then # 配置根账号密码
        customize "${basedir}" 设置根用户密码 echo "root:${root_password}" | chpasswd
    fi
}

prepare() {
    arch=$1
    version=$2
    packages=$3
    basedir=$4

    codename=$(curl -s https://changelogs.ubuntu.com/meta-release | grep Name: | tail -n1)

    log INFO 准备文件系统 "filepath=${basedir}"
    sudo debootstrap --arch="${arch}" --include="${packages}" --variant=minbase "${codename}" "${basedir}" https://mirrors.ustc.edu.cn/ubuntu

    dev="${basedir}/dev"
    log INFO 开始挂载文件系统 "filepath=${dev}"
    sudo mount --options --rbind /dev "${dev}"
    log INFO 挂载文件系统成功 "filepath=${dev}"

    proc="${basedir}/proc"
    log INFO 开始挂载文件系统 "filepath=${proc}"
    sudo mount --options --rbind /proc "${proc}"
    log INFO 挂载文件系统成功 "filepath=${proc}"

    sys="${basedir}/sys"
    log INFO 开始挂载文件系统 "filepath=${sys}"
    sudo mount --options --rbind /sys "${sys}"
    log INFO 挂载文件系统成功 "filepath=${sys}"

    trap 'sudo unmount ${dev} ${proc} ${sys}' EXIT
}

kubernetes() {
    before # 准备执行环境

    workspace="${3:-kubernetes}"
    check "${workspace}"

    basedir="${workspace}/ubuntu-${version}-${arch}"

    version=${1:-24.10}
    arch=${2:-amd64}

    root_password=${4}
    username=${5:-kubernetes}
    password=${6}

  packages="bash"
  packages="${packages},locales"


    log INFO 开始定制系统 "root=${basedir}"
  customize "${basedir}" 更新系统 apt update
  customize "${basedir}" 升级系统 apt upgrade
  customize "${basedir}" 使用Bash环境 chsh --shell /usr/bin/bash
  customize "${basedir}" 设置时间为重庆 apt install tzdata -y && cp /usr/share/zoneinfo/Asia/Chongqing /etc/localtime
  customize "${basedir}" 安装SSH服务器并 apt install openssh-server -y
  customize "${basedir}" 开启ROOT账号登录权限 echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/root
}
