#!/usr/bin/env bash
# ------------------------------------
# default jvm args if you do not config in /jetty/boot.ini
# ------------------------------------
JVM_ARGS="-server -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Djava.io.tmpdir=/tmp -Djava.net.preferIPv6Addresses=false"
JVM_GC="-XX:+DisableExplicitGC -XX:+PrintGCDetails -XX:+PrintHeapAtGC -XX:+PrintTenuringDistribution -XX:+UseConcMarkSweepGC -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
JVM_GC=$JVM_GC" -XX:CMSFullGCsBeforeCompaction=0 -XX:+UseCMSCompactAtFullCollection -XX:CMSInitiatingOccupancyFraction=80"
JVM_HEAP="-XX:SurvivorRatio=8 -XX:PermSize=256m -XX:MaxPermSize=256m -XX:+HeapDumpOnOutOfMemoryError -XX:ReservedCodeCacheSize=128m -XX:InitialCodeCacheSize=128m"
JVM_SIZE="-Xmx4g -Xms4g"

# ------------------------------------
# do not edit
# ------------------------------------

function monitorinit(){
    echo "maoyan monitor init start"
    if [ -z "$MONITOR_PATH" ]; then
	    MONITOR_PATH="/data/appdatas/maoyanmonitor"
    fi
    if [ ! -d "$MONITOR_PATH" ]; then
	    mkdir $MONITOR_PATH
    fi
    clientxml="$MONITOR_PATH/client.xml"
    datasourcesxml="$MONITOR_PATH/datasources.xml"
    serverxml="$MONITOR_PATH/server.xml"
    cat deploy/online/config/client.xml > $clientxml
    cat deploy/online/config/datasources.xml > $datasourcesxml
    cat deploy/online/config/server.xml > $serverxml
}

function init() {
    monitorinit
#    判断变量LOG_PATH变量是否为空，为空返回真，则执行对LOG_PATH的赋值
    if [ -z "$LOG_PATH" ]; then
        LOG_PATH="/opt/logs/mobile/$MODULE"
    fi
#    判断变量WORK_PATH变量是否为空，为空返回真，则执行对WORK_PATH的赋值
    if [ -z "$WORK_PATH" ]; then
        WORK_PATH="/opt/meituan/mobile/$MODULE"
    fi
    WEB_ROOT=$WORK_PATH/webroot
#    将*.war解压到webroot路径下
    unzip *.war -d webroot
#    循环建立目录，LOG_PATH有多级目录，需要-p
    mkdir -p $LOG_PATH

    #定时清理日志
    cleanpath="$WORK_PATH/clean.sh"
    echo "#!/bin/bash" > $cleanpath
    echo "find $LOG_PATH -mtime +1 -exec /bin/gzip {} \;" >> $cleanpath
    echo "find $LOG_PATH -mtime +3 -exec rm -fr {} \;" >> $cleanpath
    chmod +x $cleanpath
    (crontab -l|grep -v $cleanpath ; echo "58 05 * * * /bin/bash $cleanpath > /dev/null 2>&1" ) | crontab
}

function run() {
    #根据java版本,决定java命令的位置
    JAVA_CMD=$JAVA_VERSION
#    判断java版本是否为空，为空就赋值java，不为空就赋值/usr/local/$JAVA_VERSION/bin/java
    if [ -z "$JAVA_VERSION" ]; then
        JAVA_CMD="java" #系统默认的java命令
    else
        JAVA_CMD="/usr/local/$JAVA_VERSION/bin/java"
    fi

    EXEC="exec"
    CONTEXT=/
    cd $WEB_ROOT
#    判断在$WEB_ROOT下WEB-INF/classes/release文件是否存在,如果存在就把里面的东西拷贝到WEB-INF/classes下
    if [ -e "WEB-INF/classes/release" ]; then
        cp -rf WEB-INF/classes/release/* WEB-INF/classes
    fi
#    使得boot.ini中的jvm参数生效
    if [ -e "WEB-INF/classes/jetty/boot.ini" ]; then
        source WEB-INF/classes/jetty/boot.ini
    fi


    CLASSPATH=WEB-INF/classes
#    遍历WEB-INF/lib下的jar
    for i in WEB-INF/lib/*
    do
        CLASSPATH=$CLASSPATH:$i
    done
#    把CLASSPATH赋值到环境变量
    export CLASSPATH
    JAVA_ARGS="-Djetty.webroot=$WEB_ROOT"
    EXEC_JAVA="$EXEC $JAVA_CMD $JVM_ARGS $JVM_SIZE $JVM_HEAP $JVM_JIT $JVM_GC"
    EXEC_JAVA=$EXEC_JAVA" -Xloggc:$LOG_PATH/$MODULE.gc.log -XX:ErrorFile=$LOG_PATH/$MODULE.vmerr.log -XX:HeapDumpPath=$LOG_PATH/$MODULE.heaperr.log"
    EXEC_JAVA=$EXEC_JAVA" -Djetty.appkey=$MODULE -Djetty.context=$CONTEXT -Djetty.logs=$LOG_PATH"
    EXEC_JAVA=$EXEC_JAVA" $JAVA_ARGS"
    if [ "$UID" = "0" ]; then
        ulimit -n 1024000
        umask 000
    else
        echo $EXEC_JAVA
    fi
    $EXEC_JAVA com.sankuai.mms.boot.Bootstrap 2>&1
}

# ------------------------------------
# actually work
# ------------------------------------
init
run