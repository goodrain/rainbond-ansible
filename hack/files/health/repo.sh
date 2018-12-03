check_type="{{ pillar['install-type'] }}"

#Logfile=/tmp/.repo.$(date +%Y%m%d)
#Oldlogfile=/tmp/.repo.$(date +%Y%m%d --date='1 days ago')

if [ "$check_type" == "online" ];then
    curl -I -s  http://127.0.0.1:8081/artifactory/libs-release/ | head -1 | grep 200
    if [ "$?" -eq 0 ];then
        exit 0
    else
        exit 1
    fi
else
    #[ -f "$Oldlogfile" ] && rm -rf $Oldlogfile && touch $Logfile
    #[ -f "$Logfile" ] || && touch $Logfile
    curl -I -s  http://127.0.0.1:8081/artifactory/webapp/#/home | head -1 | grep 200
    if [ "$?" -eq 0 ];then
        exit 0
    else
        exit 1
    fi
fi