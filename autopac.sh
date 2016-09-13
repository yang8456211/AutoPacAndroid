#!bin/bash
# contact atany9787@163.com

# 分包模式
# 0:从配置文件 game_name_config.ini中读取出包的信息，批处理打包
# 1:传入模式s，使用的时候用Mode=1
Mode=0

# Apktool版本
APKTOOL_JAR="apktool_2.1.0.jar"

# 签名名称
SIGN_NAME="ygkey"
SIGN_ALIAS="12345"
SIGN_PASS="123456"

# 目录相对路径 
# root,这里以相对路径
ROOT_PATH="./"
# TMP目录
TMP_PATH=$ROOT_PATH"/TMP"
# tool目录，放工具
TOOL_PATH=$ROOT_PATH"/tool"
# common目录，放配置签名等
COMMON_PATH=$ROOT_PATH"/common"
# out目录,apk输出的目录
OUTPUT_PATH=$ROOT_PATH"/output"

# 输入的apk的路径
input_apk_path=""
output_apk_path=""

# --------------- 游戏参数 ---------------

# 游戏名称
game_name=""
# 渠道号
game_channel=""
game_channel_pinyin=""

# 游戏新的包名
game_package_name=""



# --------------- 脚本变量 ---------------
# apktool 反编译出来的路径
unpacpath=""

# 签名完成的apk路径
signpacpath=""

# apktool 合成包的路径
apkpacpath=""

# readConfig 
read_config() {
    inifile=$1 
    _readIni=`awk -F '=' '$1~/'package[d]*'/{print $2}' $inifile`
    echo $_readIni
}

help_info() {
cat << ENTER
     ============= Auto pac For game =============
     Version: 1.0
     Date: 20160907
     Usage: Auto repackage For the game, modify package name and subchannel
     e.g.: 
        Mode0: sh autopac.sh inputApkPath gamename
        Mode1: sh autopac.sh inputApkPath gamename channel outputApkPath
            inputApkPath: 待分包的apk路径
            gamename: 游戏名称英文首字母小写
            channel: 渠道号
            outputApkPath: 完成输出apk的路径
     ============= Auto pac For game =============
ENTER
}


do_get_prama(){
    game_channel_pinyin=${1%%:*}
    game_channel=${1##*:}
    echo "[package name is "$game_package_name" channel is "$game_channel"]"
}

do_change(){

    game_package_name="com.szdiybo."$game_name"."$game_channel_pinyin

    echo "[package name is "$game_package_name"]"

    manifest=$unpacpath"/AndroidManifest.xml"

    sed -i '' "s~^.*<meta-data android:name=\"SDK_CHANNEL\".*~        <meta-data android:name=\"SDK_CHANNEL\" android:value=\""$game_channel"\"/>~g" $manifest


    # 修改包名
    old_pacname=`cat $manifest | grep "package=" | head -n 1 | awk -F 'package=\"' '{print $2}' | awk -F '\"' '{print $1}' |  xargs echo `
    echo "==>"$old_pacname
    sed -i '' "s~package=\""$old_pacname\""~package="\"$game_package_name\""~g" $manifest


    cat $manifest | grep "SDK"
}

do_unpac(){

    echo "---------------------------- Unpac ----------------------------"

    if [[ -d $TMP_PATH ]];then
        rm -rf $TMP_PATH
    fi
    mkdir $TMP_PATH

    unpacpath=$TMP_PATH"/"$game_name

    mkdir $unpacpath 

    signpacpath=$TMP_PATH"/"$game_name"_autosign"

    mkdir $signpacpath

    apkpacpath=$TMP_PATH"/"$game_name"_apk"

    mkdir $apkpacpath

    java -jar $ROOT_PATH/tool/apktool/$APKTOOL_JAR d -f $input_apk_path -o $unpacpath

    # 初始化清空output
    rm -rf $OUTPUT_PATH"/*"
}

do_repac(){
    echo "---------------------------- rePac ----------------------------"
    do_change

    outapk=$apkpacpath"/"$game_package_name".apk"

    # apktool重新回包 以免apktool的一些临时改动
    java -jar $ROOT_PATH/tool/apktool/$APKTOOL_JAR b $unpacpath -o $outapk

    re_sign $outapk
}


re_sign(){

    unsign_apkname=$1
    sign_apkname=$signpacpath"/"$game_package_name".apk"

    # 重新签名
    keystore_name=$COMMON_PATH"/sign/"$SIGN_NAME

    #         显示信息              签名文件                   签名密码                生成apk                                            未签名apk        alias   
    jarsigner -verbose -keystore $keystore_name -storepass $SIGN_PASS -signedjar $sign_apkname -digestalg SHA1 -sigalg MD5withRSA $unsign_apkname $SIGN_ALIAS 

    cp -rf $sign_apkname $output_apk_path"/"
}

if [[ $Mode == 0 ]];then
    if [[ $# < 2 ]];then
        echo "args is wrong"
        help_info
        exit 199
    else
        input_apk_path=$1
        game_name=$2

        # 找到配置文件
        config_name=$game_name"_config.ini"
        config_path=$COMMON_PATH"/config/"$config_name

        # 配置名字
        if [[ ! -f $config_path ]];then
            echo "Can't find "$config_path" abort, please check if the config is exist"
            exit 198
        fi

        # 签名名字
        sign_path=$COMMON_PATH"/sign/"$SIGN_NAME
        if [[ ! -f $sign_path ]];then
            echo "Can't find "$sign_path" abort, please check if the sign file is exist"
            exit 197
        fi

        packages=`read_config $config_path`

        echo "packages is "$packages

        do_unpac

        output_apk_path=$OUTPUT_PATH

        for pac in $packages
        do
            #for循环中操作打包流程 pac为 包名:子渠道名称
            do_get_prama $pac
            do_repac
        done
    fi
elif [[ $Mode == 1 ]];then
    if [[ $# < 6 ]];then
        echo "ERROR:Args is wrong"
        help_info
        exit 199
    elif [[ $1"x" == "x" || $2"x" == "x" || $3"x" == "x" || $4"x" == "x" ]];then
        echo "ERROR:存在参数为空，退出"
        help_info
        exit 198
    fi

    #Mode1: sh autopac.sh inputApkPath gamename channel subchannel payWay outputApkPath

    input_apk_path=$1
    game_name=$2
    game_channel=$3
    output_apk_path=$4


    # 签名名字
    sign_path=$COMMON_PATH"/sign/"$SIGN_NAME
    if [[ ! -f $sign_path ]];then
        echo "Can't find "$sign_path" abort, please check if the sign file is exist"
        exit 197
    fi

    do_unpac

    do_repac
fi