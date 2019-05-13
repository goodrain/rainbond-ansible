## 初始化数据库失败

```
# 如果数据库服务安装初始化失败

systemctl stop rbd-db
rm -rf /opt/rainbond/data/rbd-db

systemctl restart rbd-db
bash /tmp/install/updatedb.sh

# 手动push镜像，确保

docker images | grep "goodrain.me" | awk '{print $1":"$2}' | xargs -I {} docker push {}

# 手动上线节点

grctl node list
grctl node up <uid>
```