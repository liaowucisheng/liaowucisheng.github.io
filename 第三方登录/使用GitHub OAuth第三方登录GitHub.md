# GitHub OAuth 第三方应用使用github登录

## 配置

1. 访问 https://github.com/settings/developers 创建 OAuth Apps
2. 填写对应的应用名称、主页网址、应用说明、授权回调地址 来注册申请
3. 选择刚刚创建的应用，生成Client secrets ，点击【update application】更新配置

### APP信息

#### Client ID

```
a8b010fff08c891ec002
```

#### Client secrets

```
e616dc88262f314f37dd63a06392fcfa23ebfeea
03a2437f768839cb45a61901c504fa6a9817f2a6
```

访问链接：https://github.com/login/oauth/authorize?client_id=XXX&state=XXX&redirect_uri=XXX; 进行授权登录



低代码前端框架平台

https://baidu.github.io/amis/zh-CN/docs/index

## 参考资料

> http://www.ruanyifeng.com/blog/2019/04/github-oauth.html
>
> https://blog.csdn.net/qq_38225558/article/details/85258837
>
> https://blog.51cto.com/u_13294304/4810670
