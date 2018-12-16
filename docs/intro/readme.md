## 节点身份属性说明

默认节点身份属性有

```
deploy ## 部署节点，默认第一个节点
master/new-master ## 管理节点，运行k8s和rainbond服务组件 new-master 新增管理节点
worker/new-worker ## 计算节点，主要运行应用 new-worker 新增计算节点
etcd ## etcd
lb  ## 负载均衡节点
storage ## 存储服务端节点，目前只支持nfs
```