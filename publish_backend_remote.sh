#!/bin/bash
# Author: BarryNg
# Date: 2019-01-05
# Description: 远程自动发布脚本（配合Jenkins使用）
# 提醒：使用该脚本前先配置好目标服务器的免密登录。

# V1.2版本更新说明：
# 1、优化传输方式，采用rsync代替scp，采用传输文件夹代替传输war包（提高速度）

# V1.1版本更新说明：
# 1、改为远程部署
# 2、增加备份步骤
# 3、PKG_PATH采用jenkins的$WORKSPACE环境变量

# 步骤说明：
# 1、备份当前程序
# 2、复制war到对应目录（远程）
# 3、删除原来目录
# 4、解压war包 & 删除war包
# 5、重启tomcat

# 参数说明：
# 1、PROJECT_NAME：项目名称(war包名称，解压目录名称)，例：PROJECT_NAME="schoolhonor"
# 2、TARGET_PATH：应用部署目录，例：TARGET_PATH="/data/wwwroot/java"
# 3、TOMCAT_HOME：tomcat目录，例：TOMCAT_HOME="/data/tomcat/schoolhonor-tomcat"
# 4、PKG_PATH：jenkins打包完的程序目录(/root/.jenkins/workspace/项目名称 后的路径)，例：PKG_PATH="target/schoolhonor_backend"
# 5、SSH_USER：远程主机登录用户
# 6、SSH_HOST：远程主机IP
# 7、SSH_PORT：远程主机登录端口
# eg: /tool/shellscript/schoolhonor_remote.sh schoolhonor /data/wwwroot /usr/local/tomcat  target/schoolhonor_backend root 192.168.0.115 22

PROJECT_NAME="$1"
TARGET_PATH="$2"
TOMCAT_HOME="$3"
PKG_PATH="$4"
SSH_USER="$5"
SSH_HOST="$6"
SSH_PORT="$7"

function backup()
{
	ssh -p $SSH_PORT ${SSH_USER}@${SSH_HOST} "tar -czf $TARGET_PATH/$PROJECT_NAME-$(date +%s).tar.gz $TARGET_PATH/$PROJECT_NAME/*;"
	if [ $? -ne 0 ];then
		echo -e "\n\e[1;31mERROR:程序备份失败\e[0m"
	    exit 10;
	else
		echo -e "\n\e[1;34mINFO:程序备份成功\e[0m"
	fi
}

function deploy_rsync(){
	echo $WORKSPACE/$PKG_PATH
	if ( [ -n "$PKG_PATH" ] && [ -e  $WORKSPACE/$PKG_PATH ] )
	then
		# 删除目标目录，解压war，复制目录
		rm -rf $WORKSPACE/$PKG_PATH/$PROJECT_NAME;
		unzip $WORKSPACE/$PKG_PATH.war -d $WORKSPACE/$PKG_PATH/../$PROJECT_NAME;
		rsync -azP --delete -e "ssh -p $SSH_PORT" $WORKSPACE/$PKG_PATH/../$PROJECT_NAME $SSH_USER@$SSH_HOST:$TARGET_PATH >/dev/null
		if [ $? -ne 0 ]
        then
        	echo -e "\n\e[1;31mERROR:未成功部署，请检查是否已添加该服务器到 ${SSH_USER}@${SSH_HOST} 的免密登录。\e[0m"
            exit 10
        else
        	echo -e "\n\e[1;34mINFO:打包文件复制成功\e[0m"
        fi
	else
		echo -e "\n\e[1;31mERROR:打包文件不存在\e[0m"
		exit 10
	fi
}

function get_tomcat_pid(){
    PID=""
    PID=$(ssh -p $SSH_PORT ${SSH_USER}@${SSH_HOST} ps aux |grep "$TOMCAT_HOME "|grep -v 'grep' |awk '{print $2}')
}

function project_stop(){
	get_tomcat_pid
	if [ -n "$PID" ]
    then
            ssh -p $SSH_PORT ${SSH_USER}@${SSH_HOST} "kill -9 $PID"
            echo -e "\n\e[1;34mINFO:进程已杀\e[0m"
            ssh -p $SSH_PORT ${SSH_USER}@${SSH_HOST} "${TOMCAT_HOME}/bin/shutdown.sh"
            sleep 3
    else
            echo "INFO: $PROJECT_NAME id 已经关闭"
    fi
    PID=""
	echo -e "\n\e[1;34mINFO:容器关闭成功\e[0m"
}

function project_start(){
	ssh -p $SSH_PORT ${SSH_USER}@${SSH_HOST} "$TOMCAT_HOME/bin/startup.sh > /dev/null"
	echo -e "\n\e[1;34mINFO:容器启动成功\e[0m"
}

# main
if ([ -z "$PROJECT_NAME" ] || [ -z "$TARGET_PATH" ] || [ -z "$TOMCAT_HOME" ] || [ -z "PKG_PATH" ] || [ -z "SSH_USER" ] || [ -z "SSH_HOST" ] || [ -z "SSH_PORT" ] )
then
        echo -e "\n\e[1;31mERROR:参数检查失败, 以下为必要参数：\e[0m"
        echo -e "PROJECT_NAME\t-\t$PROJECT_NAME"
        echo -e "TARGET_PATH\t-\t$TARGET_PATH"
        echo -e "TOMCAT_HOME\t-\t$TOMCAT_HOME"
        echo -e "PKG_PATH\t-\t$PKG_PATH"
        echo -e "SSH_USER\t-\t$SSH_USER"
        echo -e "SSH_HOST\t-\t$SSH_HOST"
        echo -e "SSH_PORT\t-\t$SSH_PORT"
        exit 10
fi

backup
deploy_rsync
project_stop
project_start