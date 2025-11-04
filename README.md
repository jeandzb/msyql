### 官方文档：
https://dev.mysql.com/doc/mysql-operator/en/mysql-operator-properties.html#mysql-operator-spec-innodbclusterspecbackupschedulesindex

#### 0,镜像和chart版本：  
- operator的chart版本为最新，其operator镜像版本也要是最新的，不然会报错。  
- innodbcluster的chart版本为最新，镜像router要和mysql-server的版本一致，可以不用最新版本。 

#### 1,router的镜像在operator的crd资源中根据mysql的版本来自动定义，内容如下：  
```yaml
                edition:
                  type: string
                  pattern: "^(community|enterprise)$"
                  description: "MySQL Server Edition (community or enterprise)"
```
仓库地址和版本号会根据mysql-server的地址来自动匹配，所以根据mysql的版本，router的镜像会自动定义为：
```yaml
registry.cn-beijing.aliyuncs.com/alphesh-soft/mysql-router:8.0.28
```
所以最好不改变crd的内容，私有仓库的镜像保证为community-*镜像就行了。  
#### 2,配置文件：  
- 注意：  
Operator 优先： 请记住，MySQL Operator 会管理核心的复制配置。这份 my.cnf 是对 Operator 的补充和调优，请勿覆盖 server_id、gtid_mode 等 Operator 自动生成的参数。  

#### 3,重复使用helm部署innodbcluster时，发现资源不创建，可能是innodbcluster资源的问题  
查询innodbcluster资源是否存在：
```shell
kubectl get innodbcluster -n mysql
```
删除innodbcluster资源：
```shell
kubectl delete innodbcluster -n mysql mysqlcluster
```
发现删除不掉此资源，可能是finalizer的问题，需要手动删除finalizer。
kubectl edit innodbcluster mysqlcluster -n mysql
删除finalizer相关的内容即可
再删除即可

