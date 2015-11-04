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

set -e

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

USAGE: $0 <api key> <user key> <repo> [<branch>]

DESCRIPTION:
<api key>: 蒲公英账号API Key
<user key>: 蒲公英账号User Key
<repo>: 工程仓库路径
<branch>: 分支, 若不指定，则为master

EOF
}

LS=/bin/ls

if [ $# -lt 3 ]; then
    usage
    exit 0;
fi

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
    WORKSPACE=`$LS|awk '/.xcworkspace/{print $0}'`
    SCHEME=`xcodebuild -list|sed -n -e '/Schemes:/,//p'|sed '1d'|head -1`
    if test -z $WORKSPACE;then
        xcodebuild -sdk iphoneos -configuration Release -derivedDataPath build -scheme $SCHEME
    else 
        xcodebuild -workspace $WORKSPACE -scheme $SCHEME -derivedDataPath build
    fi
}

API_KEY=$1
USER_KEY=$2
REPO=$3
BRANCH=$4
if test -z $BRANCH; then
    BRANCH=master
fi

# 进入工程对应的repo
HUB_PATH=~/app-publisher-hub
FILENAME=`basename $REPO .git`
mkdir -p $HUB_PATH
spushd $HUB_PATH

# 进入工程目录，并检测是否有更新
NEED_UPDATE=1
if [ ! -d $FILENAME ];then
    `git clone $REPO --branch $BRANCH`
    spushd $FILENAME
    NEED_UPDATE=1
else
    spushd $FILENAME

    # 检测是否有更新
    if test -z "`git pull origin $BRANCH|grep 'Already up-to-date'`"; then
        NEED_UPDATE=1
        info "存在新版本..."
    fi
fi

PROJECT=`$LS|awk -F. '/.xcodeproj/{print $1}'`
if [ "$NEED_UPDATE" == "1" ]; then
    git checkout $BRANCH
    build
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

    invite.sh "$URL" "$LOGO_PATH" "$APP_NAME" "$APP_SHORT_VERSION" "$APP_BUILD_VERSION" xuwenfa@star-net.cn
fi

spopd
spopd

