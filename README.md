# app-publisher

该脚本集成了代码同步、编译、单元测试、打包、发布、邀请等一系列发布流程，通过该脚本可以大大简化iOS APP内部发布。Coder再也不用为内部发布手忙脚乱的~

* 代码同步 - 基于GIT，同步指定分支
* 编译 - 通过xcodebuild来编译工程
* 单元测试
* 打包 - 生成相应的ipa文件
* 发布 - 发布到蒲公英
* 邀请 - 邮件邀请测试人员

### 配置
<pre>
export PATH=$PATH:/你的路径/app-publisher
</pre>

另外，该脚本会用到一些工具，因此需要进行预先安装和配置, 当然脚本也有检测.

* xcode - 从Apple Store安装
* git - 版本管理工具(sudo brew install git)
* msmtp - 邮件发送工具(sudo brew install msmtp)
* qrencode - 二维码生成工具(sudo brew install qrencode)

### 使用
<pre>
USAGE: app-publisher.sh [-f] < api key> < user key> < repo> < branch> < recipient> [< recipient> ...]

DESCRIPTION:
-f: 强制更新
< api key>: 蒲公英账号API Key
< user key>: 蒲公英账号User Key
< repo>: 工程仓库路径
< branch>: 分支
< recipient>: 被邀请人
</pre>
例子
<pre>
app-publisher.sh -f xxxxxxxxxxx xxxxxxxxx git@192.168.61.223:weiju/weiju-ios.git develop xuwenfa@star-net.cn
</pre>

成功后输出如下邮件
![image](http://7ximmr.com1.z0.glb.clouddn.com/app-publisher.jpg)