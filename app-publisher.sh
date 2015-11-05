#!/bin/bash
#
# Copyright (C) 2014 Wenva <lvyexuwenfa100@126.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

spushd() {
     pushd "$1" 2>&1> /dev/null
}

spopd() {
     popd 2>&1> /dev/null
}

info() {
     local green="\033[1;32m"
     local normal="\033[0m"
     echo -e "[${green}INFO${normal}] $1"
}

error() {
     local red="\033[1;31m"
     local normal="\033[0m"
     echo -e "[${red}ERROR${normal}] $1"
}

# 获取当前目录
current_dir() {
    if [ ${0:0:1} = '/' ] || [ ${0:0:1} = '~' ]; then
        echo "$(dirname $0)"
    else
        echo "`pwd`/$(dirname $0)"
    fi
}

usage() {
cat << EOF

USAGE: `basename $0` [-f] <api key> <user key> <repo> <branch> <recipient> [<recipient> ...]

DESCRIPTION:
-f: 强制更新
<api key>: 蒲公英账号API Key
<user key>: 蒲公英账号User Key
<repo>: 工程仓库路径
<branch>: 分支
<recipient>: 被邀请人

EOF
}

app_release_note() {
    echo `git log -1| sed '1,4d'`
}

# $1 app path
app_icon_path() {
    APP_PATH=$1
    echo "$APP_PATH/`$LS -S $APP_PATH|awk '/AppIcon/{print $0}'|head -1`"
}

# $1 app path
app_bundle_name() {
    echo `plistutil -i $1/Info.plist -d | sed -n -e '/CFBundleName/,/string/p'|awk -F[\<\>] '/string/{print $3}'`
}

app_bundle_version() {
    echo `plistutil -i $1/Info.plist -d | sed -n -e '/CFBundleShortVersionString/,/string/p'|awk -F[\<\>] '/string/{print $3}'`
}

app_build_version() {
    echo `plistutil -i $1/Info.plist -d | sed -n -e '/CFBundleVersion/,/string/p'|awk -F[\<\>] '/string/{print $3}'`
}

build() {
    xcodebuild clean -sdk iphoneos -configuration Release

    WORKSPACE=`$LS|awk '/.xcworkspace/{print $0}'`
    SCHEME=`xcodebuild -list|sed -n -e '/Schemes:/,//p'|sed '1d'|head -1`
    if test -z $WORKSPACE;then
        xcodebuild -sdk iphoneos -configuration Release -derivedDataPath build -scheme $SCHEME
    else 
        xcodebuild -workspace $WORKSPACE -scheme $SCHEME -derivedDataPath build
    fi
}

check() {
    if test -z "`command -v $1`"; then
        error "检测 $1 ... no"
        exit -1
    else 
        info "检测 $1 ... yes"
    fi
}


LS=/bin/ls

# 检测所有命令是否安装
info "检测环境..."
check rm
check ls
check git
check zip
check curl
check msmtp
check mkdir
check base64
check xcodebuild
check qrencode
info "检测完毕."

FORCE=0
while getopts "f" opt; do
    case $opt in
        f) FORCE=1
            shift
            ;;
    esac
done

if [ $# -lt 4 ]; then
    usage
    exit 0;
fi

API_KEY=$1
USER_KEY=$2
REPO=$3
BRANCH=$4
FILENAME=`basename $REPO .git`
shift
shift
shift
shift

# $1
send_error(){
error "[$FILENAME] $1"
exit -1
}

check_result(){
    if [ "$?" != "0" ];then
        send_error $1
    fi
}

if test -z $BRANCH; then
    BRANCH=master
fi

# 进入工程对应的repo
HUB_PATH=~/app-publisher-hub
mkdir -p $HUB_PATH
spushd $HUB_PATH

# 进入工程目录，并检测是否有更新
if [ $FORCE == "1" ];then
    NEED_UPDATE=1
else
    NEED_UPDATE=0
fi

info "同步代码..."
if [ ! -d $FILENAME ];then
    `git clone $REPO --branch $BRANCH`
    if [ "$?" == "1" ];then
        NEED_UPDATE=1
    else 
        send_error "同步错误，请检查仓库配置."
    fi
    spushd $FILENAME
    NEED_UPDATE=1
else
    spushd $FILENAME

    # 检测是否有更新
    if test -z "`git pull origin $BRANCH|grep 'Already up-to-date'`"; then
        if [ "$?" == "1" ];then
            NEED_UPDATE=1
            info "存在新版本..."
        else 
            send_error "同步错误，请检查仓库配置."
        fi
    else 
        info "没有更新."
    fi
fi

PROJECT=`$LS|awk -F. '/.xcodeproj/{print $1}'`
if [ "$NEED_UPDATE" == "1" ]; then
    git checkout $BRANCH
    build
    check_result "代码编译错误，请检测."
    APP_PATH="build/Build/Products/Release-iphoneos/$PROJECT.app"
    IPA_PATH="build/$PROJECT.ipa"
    package.sh $APP_PATH $IPA_PATH

    APP_NAME=`app_bundle_name $APP_PATH`
    APP_SHORT_VERSION=`app_bundle_version $APP_PATH`
    APP_BUILD_VERSION=`app_build_version $APP_PATH`
    LOGO_PATH=`app_icon_path $APP_PATH`
    RELEASE_NOTE="`app_release_note`"

    info "上传iPA到蒲公英...(需要一些时间，请耐心等候)"
    URL=`publish.sh "$API_KEY" "$USER_KEY" "$IPA_PATH" "$RELEASE_NOTE"`
    info "上传完成[$URL]."

    count=$#
    for ((i=0;i<$count;i++))
    do
        info "邀请$1..."
        invite.sh "$URL" "$LOGO_PATH" "$APP_NAME" "$APP_SHORT_VERSION" "$APP_BUILD_VERSION" $1
        shift
    done
fi

spopd
spopd
