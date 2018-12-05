## 节点身份属性说明

默认节点身份属性有

```
deploy ## 部署节点，默认第一个节点
master ## 管理节点，运行k8s和rainbond服务组件
worker ## 计算节点，主要运行应用
etcd ## etcd
lb  ## 负载均衡节点
storage ## 存储服务端节点，目前只支持nfs
```