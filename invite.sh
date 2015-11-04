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

QRCODE_PATH=/tmp/qrcode.png

usage() {
cat << EOF

USAGE: $0 <invite url> <logo path> <bundle name> <bundle short version> <bundle build version> <recipient>

DESCRIPTION:
<invite url>: 邀请的链接
<logo path>: logo图标路径
<bundle name>: APP名称
<bundle short version>: APP版本
<bundle build version>: APP编译版本
<recipient>: 受邀请人

EXAMPLE:

$0 http://www.weiju.com ./logo.png 微居 1.0.0 100 xuwenfa@star-net.cn

EOF
}

# Send mail to someone
#
# $1 logo path
# $2 app bundle name
# $3 app bundle short version
# $4 app bundle build version
# $5~$n recipient
send_mail() {
    logo_path=$1
    bundle_name=$2
    bundle_short_version=$3
    bundle_build_version=$4
    subject="$bundle_name iOS 发布新版本$bundle_short_version($bundle_build_version)"

    msmtp $5 $5 << EOF
SUBJECT:$subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="X1234567890";
Content-Transfer-Encoding: 7bit

This is a MIME Encoded Message 
--X1234567890
Content-Type: text/html;charset=UTF-8
Content-Transfer-Encoding: 7bit

<html>
<body>
<center>
<img src="cid:logo" style="width:100px;height:100px;border-radius:20px;"/>
<h1>$bundle_name $bundle_short_version($bundle_build_version)</h1>
我们邀请您测试 $bundle_name iOS APP.<br>请用手机扫描下方的二维码安装.
<br>
<img src="cid:qrcode" style="width:200px;height:200px;"/>
</body>
</html>

--X1234567890
Content-Type: image/png;
Content-Disposition: inline; filename="logo.png"
Content-ID: <logo>
Content-Transfer-Encoding: base64
Content-Description: "qrcode"

`base64 $logo_path`

--X1234567890
Content-Type: image/png;
Content-Disposition: inline; filename="qrcode.png"
Content-ID: <qrcode>
Content-Transfer-Encoding: base64
Content-Description: "qrcode"

`base64 $QRCODE_PATH`

EOF
}

qrcode(){
    `qrencode -o $QRCODE_PATH -s 10 $1`
}

if [ $# -lt 6 ]; then
    usage
    exit 0;
fi

info "生成二维码..."
qrcode $1
info "发送邮件..."
send_mail $2 $3 $4 $5 $6
info "发送完成."
