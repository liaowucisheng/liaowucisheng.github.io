# Java整合gRPC

代码仓库：https://codehub-y.huawei.com/zWX1160495/grpc-tutorial/

[TOC]

## gRPC

1. `gRPC`是由 `google`开发的一个高性能、通用的开源`RPC`框架，主要面向移动应用开发且基于`HTTP/2`协议标准而设计，同时支持大多数流行的编程语言。使用高效的[**Protocol Buffers**(protobuf)**协议**](https://en.wikipedia.org/wiki/Protocol_Buffers)进行RPC调用。

2. gRPC 基于 HTTP/2 标准设计，带来诸如双向流、流控、头部压缩、单 TCP 连接上的多复用请求等特。这些特性使得其在移动设备上表现更好，更省电和节省空间占用。

3. 各个进程之间可以通过gRPC相互调用，如下图：

![](img/grpc调用.svg)

protobuf比xml、json等文件格式更为高效，具体优缺点如下

![](img/protobuf优缺点.png)

### 说明

在下面的helloworld例子里helloworld.proto里的

```protobuf
 rpc SayHello (HelloRequest) returns (HelloReply) {}
```

这种简单的RPC请求响应方式其实只是gRPC定义的四种类型之一，官方《gRPC 官方文档中文版》有对这四种gRPC类型的描述：

- 简单 RPC：客户端使用存根(stub)发送请求到服务器并等待响应返回，就像平常的函数调用一样；
- 服务器端流式 RPC：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息；
- 客户端流式 RPC：客户端写入一个消息序列并将其发送到服务器，同样也是使用流。一旦客户端完成写入消息，它等待服务器完成读取返回它的响应；
- 双向流式 RPC：是双方使用读写流去发送一个消息序列。两个流独立操作，因此客户端和服务器 可以以任意喜欢的顺序读写：比如， 服务器可以在写入响应前等待接收所有的客户端消息，或者可以交替 的读取和写入消息，或者其他读写的组合。 每个流中的消息顺序被预留。

这四种类型的不同之处，在语法上，仅仅是传递参数或者返回类型前面有没有修饰 `stream` 关键字。后面将在spring boot里实现四种类型的数据传递。

## Java简单调用gRPC服务-helloworld

在这里，将演示简单的使用 [`grpc-java`](https://github.com/grpc/grpc-java) 实现gRPC调用，用以了解基本的Java调用gRPC流程，git仓库tag为`helloworld`，实现步骤如下：

- 创建一个helloworld模块
- 在main目录下新建proto目录，创建对应的`.proto`文件
- `pom.xml`引入相关依赖
- 生成代码
- 服务端代码
- 客户端代码

本小节最终项目代码结构如下

![image-20220517113923719](img/image-20220517113923719.png)

运行：启动gRPC服务端后，再启动gRPC客户端，即可看到客户端终端显示 `Greeting: Hello World`

### 新建helloworld.proto

![image-20220517101127567](img/image-20220517101127567.png)

编辑 helloworld/src/main/proto/helloworld.proto

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.huawei.tutorial.grpc.helloworld";	// 生成代码的类路径
option java_outer_classname = "HelloWorldProto";				// 生成的Proto文件名	
option objc_class_prefix = "HLW";

package helloworld;

// 问候服务定义
service Greeter {
  // 发送一个问候
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

// 包含用户名的请求消息
message HelloRequest {
  string name = 1;
}

// 包含问候语的响应消息
message HelloReply {
  string message = 1;
}
```

`java_package`是代码生成的包路径

`java_outer_classname`是生成代码后的类名

`message`定义数据传输结构体，里面的数据可以有多个，以` 数据类型 字段名 = 数字`的格式定义。数字不可重复，推荐范围1~15。

### 添加依赖以及代码生成插件

修改 helloworld/pom.xml

```xml
<!--  grpc依赖  -->
<dependencies>
    <dependency>
        <groupId>io.grpc</groupId>
        <artifactId>grpc-netty-shaded</artifactId>
        <version>1.42.2</version>
    </dependency>
    <dependency>
        <groupId>io.grpc</groupId>
        <artifactId>grpc-protobuf</artifactId>
        <version>1.42.2</version>
    </dependency>
    <dependency>
        <groupId>io.grpc</groupId>
        <artifactId>grpc-stub</artifactId>
        <version>1.42.2</version>
    </dependency>
</dependencies>
<!--  代码生成插件  -->
<build>
    <extensions>
        <extension>
            <groupId>kr.motd.maven</groupId>
            <artifactId>os-maven-plugin</artifactId>
            <version>1.7.0</version>
        </extension>
    </extensions>
    <plugins>
        <plugin>
            <groupId>org.xolstice.maven.plugins</groupId>
            <artifactId>protobuf-maven-plugin</artifactId>
            <version>0.6.1</version>
            <configuration>
                <protocArtifact>com.google.protobuf:protoc:3.20.1:exe:${os.detected.classifier}</protocArtifact>
                <pluginId>grpc-java</pluginId>
                <pluginArtifact>io.grpc:protoc-gen-grpc-java:1.46.0:exe:${os.detected.classifier}</pluginArtifact>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>compile</goal>
                        <goal>compile-custom</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

#### 异常：maven导入依赖报unable to find valid certification path to requested target[解决方法](https://blog.csdn.net/wzygis/article/details/119910920)

项目没有指定JDK以及maven运行参数，导致添加依赖失败

需要在IDEA里的`Setting`->`Build、Execution、Deployment`->`Build Tool`->`Maven`->`Runner`里设置

`VM Opions`为 `-Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true`

`JRE`为`1.8`，同时到项目结构设置里指定JDK版本为1.8

### 代码生成

IDEA右侧的maven工具里点击下图红框所示插件两个功能，生成代码

 helloworld -> Plugins -> protobuf -> protobuf:compile & protobuf:compile-custom

![image-20220517103822543](img/image-20220517103822543.png)

代码生成如下

![image-20220517104317020](img/image-20220517104317020.png)

将它们移动到main/java目录下

### gRPC服务器端代码

helloworld/src/main/java/com/huawei/tutorial/grpc/server/HelloWorldServer.java

```java
/**
 * HelloWorld grpc服务端
 */
public class HelloWorldServer {
    private static final Logger logger = Logger.getLogger(HelloWorldServer.class.getName());
    private Server server;

    private void start() throws IOException {
        int port = 50051;   // grpc服务端启动端口
        server = ServerBuilder.forPort(port)    // 创建新 ServerBuilder 的静态工厂
                .addService(new GreeterImpl())  // 将服务实现添加到处理程序注册表
                .build()
                .start();                      // 绑定并启动服务器。在此调用返回后，客户端可以开始连接到侦听套接字
        String startedMsg = "Server started, listening on " + port;
        logger.info(startedMsg);
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                logger.log(Level.WARNING, "*** shutting down gRPC server since JVM is shutting down");
                try {
                    HelloWorldServer.this.stop();
                } catch (InterruptedException e) {
                    e.printStackTrace(System.err);
                }
                logger.log(Level.WARNING, "*** server shut down");
            }
        });
    }

    private void stop() throws InterruptedException {
        if (server != null) {
            server.shutdown().awaitTermination(30, TimeUnit.SECONDS);
        }
    }

    /**
     * 等待服务器终止
     */
    private void blockUntilShutdown() throws InterruptedException {
        if (server != null) {
            server.awaitTermination();
        }
    }

    /**
     * 继承生成的 Grpc.ImplBase 类，重写对应的grpc请求方法
     * rpc SayHello (HelloRequest) returns (HelloReply) {}
     */
    static class GreeterImpl extends GreeterGrpc.GreeterImplBase {
        @Override
        public void sayHello(HelloRequest req, StreamObserver<HelloReply> responseObserver) {
            HelloReply reply = HelloReply.newBuilder()
                .setMessage("Hello " + req.getName()) // 设置参数，与 helloworld.proto的 `string message = 1`; 相对应
                .build();
            responseObserver.onNext(reply);
            responseObserver.onCompleted();
        }
    }
    
    /**
     * Main 从命令行启动服务器
     */
    public static void main(String[] args) throws IOException, InterruptedException {
        final HelloWorldServer server = new HelloWorldServer();
        server.start();
        server.blockUntilShutdown();
    }
}
```

### gRPC客户端代码

```java
/**
 * 简单的grpc客户端
 */
public class HelloWorldClient {
    private static final Logger logger = Logger.getLogger(HelloWorldClient.class.getName());

    private final GreeterGrpc.GreeterBlockingStub blockingStub;

    /**
     * 使用现有通道构造客户端以访问 HelloWorld 服务器
     */
    public HelloWorldClient(Channel channel) {
        // 这里的“Channel”是一个 Channel ，而不是一个 ManagedChannel，所以关闭它不是这段代码的责任。
        // 将 Channels 传递给代码使代码更容易测试，并且更容易重用 Channels。
        blockingStub = GreeterGrpc.newBlockingStub(channel);
    }

    /**
     * 访问grpc服务器
     */
    public void greet(String name) {
        HelloRequest request = HelloRequest.newBuilder().setName(name).build();
        HelloReply response;
        try {
            response = blockingStub.sayHello(request);
        } catch (StatusRuntimeException e) {
            logger.log(Level.WARNING, "RPC failed: {0}", e.getStatus());
            return;
        }
        String message = "Greeting: " + response.getMessage();
        logger.info(message);
    }

    /**
     * grpc 客户端，通过配置grpc服务端信息，访问grpc服务端
     */
    public static void main(String[] args) throws Exception {
        String user = "World";
        // 访问在本地计算机端口 50051 上运行的服务
        String target = "localhost:50051";

        // 创建到服务器的通信通道，称为通道。通道是线程安全且可重用的。
        // 在应用程序开始时创建通道并重用它们直到应用程序关闭是很常见的。
        ManagedChannel channel = ManagedChannelBuilder.forTarget(target)
                // 默认情况下，通道是安全的（通过 SSL/TLS）,在这里禁用 TLS 以避免需要证书。
                .usePlaintext()
                .build();
        try {
            HelloWorldClient client = new HelloWorldClient(channel);    // 使用现有通道构造客户端以访问 HelloWorld 服务器
            client.greet(user);
        } finally {
            // ManagedChannels 使用线程和 TCP 连接等资源。
            // 为防止泄漏这些资源，在不再使用通道时应将其关闭。
            // 如果它可以再次使用，让它继续运行
            channel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
        }
    }
}
```



## spring-boot整合gRPC简要介绍

目前没有谷歌官方的整合grpc的spring-boot框架，流行的`grpc-spring-boot-stater`有以下两个

- [yidongnan](https://github.com/yidongnan)/**[grpc-spring-boot-starter](https://github.com/yidongnan/grpc-spring-boot-starter)**
- [LogNet](https://github.com/LogNet)/**[grpc-spring-boot-starter](https://github.com/LogNet/grpc-spring-boot-starter)**

两个框架在底层实现上有相似之处，gRPC服务器端都是通过@GrpcService注解来简化开发

在这里采用[yidongnan](https://github.com/yidongnan)的**[grpc-spring-boot-starter](https://github.com/yidongnan/grpc-spring-boot-starter)**来实现spring-boot整合gRPC

为了代码结构更为清晰，结构上，定义proto文件生成Java代码作为一个模块，四种gRPC传输类型分为四个模块，都引用grpc-lib模块，子目录分别有服务器端及客户端两个模块。

为简化开发，在 [客户端流式 RPC](###客户端流式 RPC) 以及 [双向流式 RPC](###双向流式 RPC) 两个模块中，直接在父模块引入了所有依赖，它们的子模块都不需要引入其它依赖，与此同时，**客户端要配置 gRPC 监听端口**，因为grpc-spring-boot-starter默认自动配置的端口可能会被占用，导致服务启动失败。之所以引入grpc-spring-boot-starter，是因为一个微服务模块，一般不会仅仅充当服务器端或者客户端，要实现各个模块之间的调用，就需要同时具备gRPC服务器端以及客户端的功能。

## 简单 RPC

简单 RPC：客户端使用存根(stub)发送请求到服务器并等待响应返回，就像平常的函数调用一样；

git仓库tag为 `simple-rpc`

本小节操作流程如下图

![image-20220518171605234](img/image-20220518171605234.png)

### grpc-lib模块

- 定义`helloworld.proto`文件，与`helloworld/src/main/proto/helloworld.proto`内容一致

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.huawei.tutorial.grpc.helloworld";
option java_outer_classname = "HelloWorldProto";

package helloworld;

// 问候服务定义
service Greeter {
  // 发送一个问候
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

// 包含用户名的请求消息
message HelloRequest {
  string name = 1;
}

// 包含问候语的响应消息
message HelloReply {
  string message = 1;
}
```

- 修改grpc-lib的pom.xml文件导入的依赖以及插件，与helloworld模块的pom.xml一致

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.huawei.tutorial.grpc</groupId>
    <artifactId>grpc-lib</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <!--  grpc依赖  -->
    <dependencies>
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-netty-shaded</artifactId>
            <version>1.42.2</version>
        </dependency>
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-protobuf</artifactId>
            <version>1.42.2</version>
        </dependency>
        <dependency>
            <groupId>io.grpc</groupId>
            <artifactId>grpc-stub</artifactId>
            <version>1.42.2</version>
        </dependency>
    </dependencies>
    <!--  代码生成插件  -->
    <build>
        <extensions>
            <extension>
                <groupId>kr.motd.maven</groupId>
                <artifactId>os-maven-plugin</artifactId>
                <version>1.7.0</version>
            </extension>
        </extensions>
        <plugins>
            <plugin>
                <groupId>org.xolstice.maven.plugins</groupId>
                <artifactId>protobuf-maven-plugin</artifactId>
                <version>0.6.1</version>
                <configuration>
                    <protocArtifact>com.google.protobuf:protoc:3.20.1:exe:${os.detected.classifier}</protocArtifact>
                    <pluginId>grpc-java</pluginId>
                    <pluginArtifact>io.grpc:protoc-gen-grpc-java:1.46.0:exe:${os.detected.classifier}</pluginArtifact>
                </configuration>
                <executions>
                    <execution>
                        <goals>
                            <goal>compile</goal>
                            <goal>compile-custom</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <source>6</source>
                    <target>6</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

- 点击右侧maven，选择grpc-lib模块的插件工具，生成Java文件，将他们移动到main/java目录下

目录如下所示:

![image-20220517172151668](img/image-20220517172151668.png)

### simple-rpc模块

本模块作为服务器端与客户端的父模块，统一引入grpc-lib模块，用以调用.proto文件生成的代码，springboot依赖以启动服务

simple-rpc/pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.huawei.tutorial.grpc</groupId>
    <artifactId>simple-rpc</artifactId>
    <version>1.0-SNAPSHOT</version>
    <modules>
        <module>simple-rpc-server-side</module>
    </modules>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>com.huawei.tutorial.grpc</groupId>
            <artifactId>grpc-lib</artifactId>
            <version>1.0-SNAPSHOT</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
            <version>2.6.7</version>
        </dependency>
    </dependencies>
</project>
```

### simple-rpc-server-side模块

位于simple-rpc/simple-rpc-server-side，是`simple-rpc`的子服务器端模块

simple-rpc/simple-rpc-server-side/pom.xml  导入gRPC服务器端依赖以及spring boot依赖

```xml
<dependencies>
    <dependency>
        <groupId>net.devh</groupId>
        <artifactId>grpc-server-spring-boot-starter</artifactId>
        <version>2.13.1.RELEASE</version>
    </dependency>
</dependencies>
```

simple-rpc/simple-rpc-server-side/src/main/resources/application.yml  定义启动端口9000，gRPC监听端口9001

```yml
server:
  port: 9000
spring:
  application:
    name: simple-rpc-server-side
grpc:
  server:
    port: 9001
```

simple-rpc/simple-rpc-server-side/src/main/java/com/huawei/tutorial/grpc/server/GreeterServer.java  继承  \*Grpc.\*ImplBase，'*'表示服务定义的名称，在这里是Greeter，重写服务中定义的 rpc 方法，实现业务逻辑，这里是 sayHello

```java
/**
 * 简单grpc请求的服务端，
 */
@GrpcService
public class GreeterServer extends GreeterGrpc.GreeterImplBase {
    /**
     * 接受grpc客户端的请求，返回数据
     */
    @Override
    public void sayHello(HelloRequest request, StreamObserver<HelloReply> responseObserver) {
        HelloReply reply = HelloReply.newBuilder()
                .setMessage("Hello " + request.getName())
                .build();
        responseObserver.onNext(reply);
        responseObserver.onCompleted();
    }
}
```

simple-rpc/simple-rpc-server-side/src/main/java/com/huawei/tutorial/grpc/SimpleRPCServerSideApplication.java  简单的SpringBoot启动类

```java
@SpringBootApplication
public class SimpleRPCServerSideApplication {
    public static void main(final String[] args) {
        SpringApplication.run(SimpleRPCServerSideApplication.class, args);
    }
}
```

### simple-rpc-client-side模块

位于simple-rpc/simple-rpc-client-side，是`simple-rpc`的子客户端模块

simple-rpc/simple-rpc-client-side/pom.xml  导入grpc客户端依赖

```xml
<dependency>
    <groupId>net.devh</groupId>
    <artifactId>grpc-client-spring-boot-starter</artifactId>
    <version>2.13.1.RELEASE</version>
</dependency>
```

simple-rpc/simple-rpc-client-side/src/main/resources/application.yaml  定义启动端口，grpc服务器端信息

```yaml
server:
  port: 9002
spring:
  application:
    name: simple-rpc-client-side
grpc:
  client:
    simple-rpc-server-side:               # grpc服务器端名称，用于通过@Value注入
      address: 'static://127.0.0.1:9001'  # 地址为grpc服务器端IP，端口为grpc监听端口
      enableKeepAlive: true
      keepAliveWithoutCalls: true
      negotiationType: plaintext
```

simple-rpc/simple-rpc-client-side/src/main/java/com/huawei/tutorial/grpc/client/GreeterClient.java

```java
/**
 * gRPC Greeter服务的客户端
 */
@Service
public class GreeterClient {
    @GrpcClient("simple-rpc-server-side")
    private GreeterGrpc.GreeterBlockingStub blockingStub;

    /**
     * 与服务器端进行连接，返回服务器回传数据
     */
    public String sayHello(String name) {
        // 设置请求参数
        HelloRequest request = HelloRequest.newBuilder()
                .setName(name)
                .build();
        // 发送grpc请求，获取返回数据
        HelloReply reply = blockingStub.sayHello(request);
        return reply.getMessage();
    }
}
```

simple-rpc/simple-rpc-client-side/src/main/java/com/huawei/tutorial/grpc/controller/GreeterController.java

```java
/**
 * Greeter控制器，提供外部访问接口，调用gRPC服务器端，用于测试连接
 */
@RestController
public class GreeterController {
    @Autowired
    private GreeterClient greeterClient;

    /**
     * 提供外部调用接口，实现调用gRPC客户端GreeterClient，通过sayHello与服务器端数据传递
     */
    @RequestMapping("greeter")
    public String sayHello(@RequestParam("name") String name) {
        String message = greeterClient.sayHello(name);
        return message;
    }
}
```

simple-rpc/simple-rpc-client-side/src/main/java/com/huawei/tutorial/grpc/SimpleRPCClientSideApplication.java

```java
@SpringBootApplication
public class SimpleRPCClientSideApplication {
    public static void main(final String[] args) {
        SpringApplication.run(SimpleRPCClientSideApplication.class, args);
    }
}
```

### 验证

分别启动

simple-rpc/simple-rpc-server-side/src/main/java/com/huawei/tutorial/grpc/SimpleRPCServerSideApplication.java

simple-rpc/simple-rpc-client-side/src/main/java/com/huawei/tutorial/grpc/SimpleRPCClientSideApplication.java

浏览器访问：http://localhost:9002/greeter?name=world

gRPC服务器端将Hello与客户端发送的World拼接返回给客户端

![image-20220518101517079](img/image-20220518101517079.png)

## 服务器端流式 RPC

服务器端流式 RPC：客户端发送请求到服务器，拿到一个流去读取返回的消息序列。 客户端读取返回的流，直到里面没有任何消息；

git仓库tag为 `server-stream`

### grpc-lib

添加 shop.proto

grpc-lib/src/main/proto/shop.proto

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.huawei.tutorial.grpc.shop"; // 生成java代码的package
option java_outer_classname = "ShopProto"; // 类名

// gRPC服务，这是个在线商城的订单查询服务
service OrderQuery {
  // 服务端流式：订单列表接口，入参是买家信息，返回订单列表(用stream修饰返回值)
  rpc ListOrders (Buyer) returns (stream Order) {}
}

// 买家ID
message Buyer {
  int32 buyerId = 1;
}

// 返回结果的数据结构
message Order {
  // 订单ID
  int32 orderId = 1;
  // 商品ID
  int32 productId = 2;
  // 交易时间
  int64 orderTime = 3;
  // 买家备注
  string buyerRemark = 4;
}
```

点击右侧maven工具，自动生成类

![image-20220519105722156](img/image-20220519105722156.png)

将生成的类移动到对应路径

![image-20220519105829793](img/image-20220519105829793.png)

### server-stream 

为方便，直接引入 **grpc-spring-boot-starter**，包含了 grpc-server-spring-boot-starter 以及 grpc-client-spring-boot-starter

之后的 服务端相应流子模块就不需引入这两个模块了，在使用中，**一个模块常常既是gRPC服务器端，又是gRPC客户端**

server-stream/pom.xml  

```xml
<dependencies>
    <dependency>
        <groupId>com.huawei.tutorial.grpc</groupId>
        <artifactId>grpc-lib</artifactId>
        <version>1.0-SNAPSHOT</version>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
        <version>2.6.6</version>
    </dependency>
    <dependency>
        <groupId>net.devh</groupId>
        <artifactId>grpc-spring-boot-starter</artifactId>
        <version>2.13.1.RELEASE</version>
    </dependency>
</dependencies>
```

### server-stream-server-side

位于 server-stream/server-stream-server-side

server-stream/server-stream-server-side/src/main/resources/application.yml 配置服务启动端口，grpc监听端口

```yml
server:
  port: 9003
spring:
  application:
    name: server-stream-server-side
# gRPC有关的配置，这里配置服务端口号
grpc:
  server:
    port: 9004
```

server-stream/server-stream-server-side/src/main/java/com/huawei/tutorial/grpc/server/OrderQueryServer.java

相对于之前的简单RPC调用，服务端流也就是服务端**多次调用** responseObserver.onNext 方法返回数据给客户端

```java
/**
 * 订单查询 grpc 服务器端
 */
@GrpcService
public class OrderQueryServer extends OrderQueryGrpc.OrderQueryImplBase {
    /**
     * 返回用户订单列表
     */
    @Override
    public void listOrders(Buyer request, StreamObserver<Order> responseObserver) {
        // 持续输出到client
        for (Order order : mockOrders()) {
            // 多次调用onNext()方法
            responseObserver.onNext(order);
        }
        // 结束输出
        responseObserver.onCompleted();
    }

    /**
     * 模拟订单数据
     */
    private static List<Order> mockOrders() {
        List<Order> list = new ArrayList<>();
        // *.Builder 是 *类的数据结构构造类，可通过它设置对应的数据，调用*.Builder.build()方法返回 *类
        Order.Builder builder = Order.newBuilder();
        // 构造一个order结构对象，填充数据到list
        for (int i = 0; i < 10; i++) {
            list.add(builder
                    .setOrderId(i)
                    .setProductId(1000 + i)
                    .setOrderTime(System.currentTimeMillis() / 1000)
                    .setBuyerRemark(("remark-" + i))
                    .build());
        }
        return list;
    }
}
```

server-stream/server-stream-server-side/src/main/java/com/huawei/tutorial/grpc/ServerStreamServerSideApplication.java 启动类

```java
@SpringBootApplication
public class ServerStreamServerSideApplication {
    public static void main(String[] args) {
        SpringApplication.run(ServerStreamServerSideApplication.class, args);
    }
}
```

### server-stream-client-side

 引入 spring-boot-starter-web 为了提供外部接口被访问，以调用 gRPC 服务；lombok是为了简化实体类开发以及日志输出

server-stream/server-stream-client-side/pom.xml  

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>server-stream</artifactId>
        <groupId>com.huawei.tutorial.grpc</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <artifactId>server-stream-client-side</artifactId>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>2.6.6</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.22</version>
        </dependency>
    </dependencies>
</project>
```

server-stream/server-stream-client-side/src/main/resources/application.yaml

```yaml
server:
  port: 9003
spring:
  application:
    name: server-stream-client-side
grpc:
  client:
    server-stream-server-side:               # grpc服务器端名称，用于通过@Value注入
      address: 'static://127.0.0.1:9101'  # 地址为grpc服务器端IP，端口为grpc监听端口
      enableKeepAlive: true
      keepAliveWithoutCalls: true
      negotiationType: plaintext
  server:
    port: 9102      # 由于父工程引用了 grpc-spring-boot-starter，相当于同时是gRPC服务器端和客户端，需要配置一下监听端口
```

server-stream/server-stream-client-side/src/main/java/com/huawei/tutorial/grpc/vo/OrderVo.java  订单类Order的数据封装类

```java
@Data
@AllArgsConstructor
@NoArgsConstructor
public class OrderVo {
    private int orderId;
    private int productId;
    private String orderTime;
    private String buyerRemark;
}
```

gRPC客户端实现，实际业务逻辑一般更为复杂，根据自己需要实现

server-stream/server-stream-client-side/src/main/java/com/huawei/tutorial/grpc/client/OrderQueryClient.java

```java
@Slf4j
@Service
public class OrderQueryClient {
    @GrpcClient("server-stream-server-side")
    private OrderQueryGrpc.OrderQueryBlockingStub orderQueryBlockingStub;
    /**
     * 根据购买者id获取购买者所有订单数据
     * @param buyerId 购买者ID
     * @return 返回服务器端查询到的所有订单数据
     */
    public List<OrderVo> listOrders(Integer buyerId) {
        Buyer buyer = Buyer.newBuilder().setBuyerId(buyerId).build();
        Iterator<Order> orderIterator = null;
        // 存放封装的订单数据
        ArrayList<OrderVo> list = new ArrayList<>();
        // grpc连接可能存在异常，需要异常处理
        try {
            orderIterator = orderQueryBlockingStub.listOrders(buyer);
        } catch (StatusRuntimeException e) {
            log.error("grpc 服务器连接异常");
            return list;
        }
        while (orderIterator.hasNext()) {
            Order order = orderIterator.next();
            list.add(orderEncapsulation(order));
        }
        return list;
    }

    /**
     * 封装订单数据
     */
    private OrderVo orderEncapsulation(Order order){
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
        return new OrderVo(order.getOrderId(),
                order.getProductId(),
                // 使用DateTimeFormatter将时间戳转为字符串
                dtf.format(LocalDateTime.ofEpochSecond(order.getOrderTime(), 0, ZoneOffset.of("+8"))),
                order.getBuyerRemark());
    }
}
```

server-stream/server-stream-client-side/src/main/java/com/huawei/tutorial/grpc/controller/OrderController.java  外部调用gRPC客户端的接口，用于验证

```java
@RestController
public class OrderController {
    @Autowired
    private OrderQueryClient orderQueryClient;

    @RequestMapping("/listOrders")
    public List<OrderVo> listOrders(@RequestParam("buyerId") Integer buyerId) {
        return orderQueryClient.listOrders(buyerId);
    }
}
```

server-stream/server-stream-client-side/src/main/java/com/huawei/tutorial/grpc/ServerStreamClientSideApplication.java  平平无奇的启动类

```java
@SpringBootApplication
public class ServerStreamClientSideApplication {
    public static void main(String[] args) {
        SpringApplication.run(ServerStreamClientSideApplication.class, args);
    }
}
```

### 验证

分别启动

server-stream/server-stream-server-side/src/main/java/com/huawei/tutorial/grpc/ServerStreamServerSideApplication.java

server-stream/server-stream-client-side/src/main/java/com/huawei/tutorial/grpc/ServerStreamClientSideApplication.java

浏览器访问：http://localhost:9003/listOrders?buyerId=101

![image-20220519150551628](img/image-20220519150551628.png)

## 客户端流式 RPC

客户端写入一个消息序列并将其发送到服务器，同样也是使用流。一旦客户端完成写入消息，它等待服务器完成读取返回它的响应；

本节代码git仓库tag为 `client-stream`

实现重点是gRPC客户端的流发送部分

### grpc-lib

新增购物车的proto文件

grpc-lib/src/main/proto/cart.proto

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.huawei.tutorial.grpc.cart"; // 生成java代码的package
option java_outer_classname = "CartProto"; // 类名

// gRPC服务，这是个在线商城的购物车服务
service CartService {
  // 客户端流式：添加多个商品到购物车
  rpc AddToCart (stream ProductOrder) returns (AddCartReply) {}
}

// 提交购物车时的产品信息
message ProductOrder {
  // 商品ID
  int32 productId = 1;
  // 商品数量
  int32 number = 2;
}

// 提交购物车返回结果的数据结构
message AddCartReply {
  // 返回码
  int32 code = 1;
  // 描述信息
  string message = 2;
}
```

使用 maven grpc protobuf 插件生成代码后，移动到对应位置

### client-stream

新建客户端流模块，修改pom.xml

在这个模块里，引入了以下几个依赖，**子模块不需再修改pom.xml文件**

- grpc-lib

- grpc-spring-boot-starter
- spring-boot-starter
- spring-boot-starter-web
- lombok

client-stream/pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.huawei.tutorial.grpc</groupId>
    <artifactId>client-stream</artifactId>
    <packaging>pom</packaging>
    <version>1.0-SNAPSHOT</version>
    <modules>
        <module>client-stream-server-side</module>
        <module>client-stream-client-side</module>
    </modules>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>com.huawei.tutorial.grpc</groupId>
            <artifactId>grpc-lib</artifactId>
            <version>1.0-SNAPSHOT</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
            <version>2.6.6</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>2.6.6</version>
        </dependency>
        <dependency>
            <groupId>net.devh</groupId>
            <artifactId>grpc-spring-boot-starter</artifactId>
            <version>2.13.1.RELEASE</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.22</version>
        </dependency>
    </dependencies>
</project>
```

### client-stream-server-side

配置服务端口，应用名称，grpc服务器端监听端口

client-stream/client-stream-server-side/src/main/resources/application.yml

```yml
server:
  port: 9004
spring:
  application:
    name: client-stream-server-side
# gRPC有关的配置，这里配置服务端口号
grpc:
  server:
    port: 9103
```

gRPC购物车服务，实现流式添加购物车操作，接收客户端发送的流式gRPC请求，每一个都调用StreamObserver.onNext()处理

client-stream/client-stream-server-side/src/main/java/com/huawei/tutorial/grpc/server/CartServer.java

```java
@Slf4j
@GrpcService
public class CartServer extends CartServiceGrpc.CartServiceImplBase {

    /**
     * 添加到购物车，上层框架多次调用StreamObserver.onNext，实现接收客户端流
     *
     * @param responseObserver
     * @return
     */
    @Override
    public StreamObserver<ProductOrder> addToCart(StreamObserver<AddCartReply> responseObserver) {
        // 返回匿名类，给上层框架使用
        return new StreamObserver<ProductOrder>() {

            // 记录处理产品的总量
            private int totalCount = 0;

            @Override
            public void onNext(ProductOrder value) {
                log.info("正在处理商品[{}]，数量为[{}]", value.getProductId(), value.getNumber());
                // 增加总量
                totalCount += value.getNumber();
            }

            @Override
            public void onError(Throwable t) {
                log.error("添加购物车异常", t);
            }

            @Override
            public void onCompleted() {
                log.info("添加购物车完成，共计[{}]件商品", totalCount);
                responseObserver.onNext(AddCartReply.newBuilder()
                        .setCode(10000)
                        .setMessage(String.format("添加购物车完成，共计[%d]件商品", totalCount))
                        .build());
                responseObserver.onCompleted();
            }
        };
    }
}
```

平平无奇的启动类

client-stream/client-stream-server-side/src/main/java/com/huawei/tutorial/grpc/ClientStreamServerSideApplication.java 

```java
@SpringBootApplication
public class ClientStreamServerSideApplication {
    public static void main(String[] args) {
        SpringApplication.run(ClientStreamServerSideApplication.class, args);
    }
}
```

### client-stream-client-side

配置文件application.yml，设置自己的web端口号和服务端地址

client-stream/client-stream-client-side/src/main/resources/application.yml

```yml
server:
  port: 9005
spring:
  application:
    name: client-stream-client-side
# gRPC有关的配置，这里配置服务端口号
grpc:
  server:
    port: 9104
  client:
    # gRPC配置的名字，GrpcClient注解会用到
    client-stream-server-side:
      # gRPC服务端地址
      address: 'static://127.0.0.1:9103'
      enableKeepAlive: true
      keepAliveWithoutCalls: true
      negotiationType: plaintext
```

正常情况下我们都是用StreamObserver处理服务端响应，这里由于是异步响应，需要额外的方法从StreamObserver中取出业务数据，于是定一个新接口，继承自StreamObserver，新增getExtra方法可以返回String对象，详细的用法稍后会看到

client-stream/client-stream-client-side/src/main/java/com/huawei/tutorial/grpc/observer

```java
public interface ExtendResponseObserver<T> extends StreamObserver<T> {
    String getExtra();
}
```

多次调用requestObserver.onNext发送gRPC流式请求

client-stream/client-stream-client-side/src/main/java/com/huawei/tutorial/grpc/client/CartClient.java

```java
@Service
@Slf4j
public class CartClient {

    @GrpcClient("client-stream-server-side")
    private CartServiceGrpc.CartServiceStub cartServiceStub;

    public String addToCart(int count) {

        CountDownLatch countDownLatch = new CountDownLatch(1);

        // responseObserver的onNext和onCompleted会在另一个线程中被执行，
        // ExtendResponseObserver继承自StreamObserver
        ExtendResponseObserver<AddCartReply> responseObserver = new ExtendResponseObserver<AddCartReply>() {
            String extraStr;

            private int code;
            private String message;

            @Override
            public String getExtra() {
                return extraStr;
            }

            @Override
            public void onNext(AddCartReply value) {
                log.info("on next");
                code = value.getCode();
                message = value.getMessage();
            }

            @Override
            public void onError(Throwable t) {
                log.error("gRPC request error", t);
                extraStr = "gRPC error, " + t.getMessage();
                countDownLatch.countDown();
            }

            @Override
            public void onCompleted() {
                log.info("on complete");
                extraStr = String.format("返回码[%d]，返回信息:%s", code, message);
                countDownLatch.countDown();
            }
        };
        // 远程调用，此时数据还没有给到服务端
        StreamObserver<ProductOrder> requestObserver = cartServiceStub.addToCart(responseObserver);
        for (int i = 0; i < count; i++) {
            // 发送一笔数据到服务端
            requestObserver.onNext(build(101 + i, 1 + i));
        }
        // 客户端告诉服务端：数据已经发完了
        requestObserver.onCompleted();
        try {
            // 开始等待，如果服务端处理完成，那么responseObserver的onCompleted方法会在另一个线程被执行，
            // 那里会执行countDownLatch的countDown方法，一但countDown被执行，下面的await就执行完毕了，
            // await的超时时间设置为2秒
            countDownLatch.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            log.error("countDownLatch await error", e);
        }
        log.info("service finish");
        // 服务端返回的内容被放置在requestObserver中，从getExtra方法可以取得
        return responseObserver.getExtra();
    }

    /**
     * 创建ProductOrder对象
     *
     * @param productId
     * @param num
     * @return
     */
    private static ProductOrder build(int productId, int num) {
        return ProductOrder.newBuilder().setProductId(productId).setNumber(num).build();
    }
}
```

外部调用接口 

client-stream/client-stream-client-side/src/main/java/com/huawei/tutorial/grpc/controller/CartController.java

```java
@RestController
public class CartController {
    @Autowired
    private CartClient cartClient;

    @RequestMapping("/addToCart")
    public String addToCart(@RequestParam(value = "count", defaultValue = "1") int count) {
        return cartClient.addToCart(count);
    }
}
```

client-stream/client-stream-client-side/src/main/java/com/huawei/tutorial/grpc/ClientStreamClientSideApplication.java

```java
@SpringBootApplication
public class ClientStreamClientSideApplication {
    public static void main(String[] args) {
        SpringApplication.run(ClientStreamClientSideApplication.class, args);
    }
}
```

### 验证

http://localhost:9005/addToCart?count=15

![image-20220526142728179](img/image-20220526142728179.png)

客户端终端输出

![image-20220526143220061](img/image-20220526143220061.png)

服务器端终端输出

![image-20220526142814374](img/image-20220526142814374.png)

## 双向流式 RPC

结合前面那两个gRPC流式调用，

git仓库tag为`double-stream`

### grpc-lib

入参和返回值都要有stream修饰

grpc-lib/src/main/proto/stock.proto

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.huawei.tutorial.grpc.stock"; // 生成java代码的package
option java_outer_classname = "StockProto"; // 类名
// gRPC服务，库存服务
service StockService {
  // 双向流式：批量增加库存
  rpc BatchAdd (stream ProductInfo) returns (stream AddReply) {}
}

// 增加库存返回结果的数据结构
message AddReply {
  // 返回码
  int32 code = 1;
  // 描述信息
  string message = 2;
}

// 提交购物车时的产品信息
message ProductInfo {
  // 商品ID
  int32 productId = 1;
  // 商品数量
  int32 number = 2;
}
```

### double-stream

引入本模块所有的依赖，子模块不需再引用

double-stream/pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.huawei.tutorial.grpc</groupId>
    <artifactId>double-stream</artifactId>
    <packaging>pom</packaging>
    <version>1.0-SNAPSHOT</version>
    <modules>
        <module>double-stream-server-side</module>
        <module>double-stream-client-side</module>
    </modules>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>com.huawei.tutorial.grpc</groupId>
            <artifactId>grpc-lib</artifactId>
            <version>1.0-SNAPSHOT</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
            <version>2.6.6</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>2.6.6</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.22</version>
        </dependency>
        <dependency>
            <groupId>net.devh</groupId>
            <artifactId>grpc-spring-boot-starter</artifactId>
            <version>2.13.1.RELEASE</version>
        </dependency>
    </dependencies>
</project>
```

### double-stream-server-side

double-stream/double-stream-server-side/src/main/resources/application.yml

```yml
server:
  port: 9006
spring:
  application:
    name: double-stream-server-side
# gRPC有关的配置，这里配置服务端口号
grpc:
  server:
    port: 9105
```

接收到的每个gRPC请求都调用一遍StreamObserver.onNext方法

double-stream/double-stream-server-side/src/main/java/com/huawei/tutorial/grpc/server/StockServer.java

```java
@GrpcService
@Slf4j
public class StockServer extends StockServiceGrpc.StockServiceImplBase {
    /**
     * 批量增加库存
     *
     * @param responseObserver
     * @return
     */
    @Override
    public StreamObserver<ProductInfo> batchAdd(StreamObserver<AddReply> responseObserver) {
        return new StreamObserver<ProductInfo>() {
            // 入库数量
            private int totalCount = 0;
            private int succCount = 0;
            private int failCount = 0;

            @Override
            public void onNext(ProductInfo value) {
                log.info("正在处理商品[{}]，数量为[{}]", value.getProductId(), value.getNumber());

                // 增加总量
                totalCount += value.getNumber();

                int code;
                String message;

                // 假设单数出现仓库对应空间不足的问题
                if (0 == value.getNumber() % 2) {
                    code = 10000;
                    message = String.format("商品[%d]新增库存数[%d]成功", value.getProductId(), value.getNumber());
                    succCount += value.getNumber();
                } else {
                    code = 10001;
                    message = String.format("商品[%d]新增库存数[%d]失败", value.getProductId(), value.getNumber());
                    failCount += value.getNumber();
                }
                responseObserver.onNext(AddReply.newBuilder()
                        .setCode(code)
                        .setMessage(message)
                        .build());
            }

            @Override
            public void onError(Throwable throwable) {
                log.error("新增库存异常", throwable);
            }

            @Override
            public void onCompleted() {
                log.info("批量新增库存完成，客户端想新增[{}]件商品，其中成功[{}]件，失败[{}]件", totalCount, succCount, failCount);
                responseObserver.onCompleted();
            }
        };
    }
}
```

普普通通的启动类

double-stream/double-stream-server-side/src/main/java/com/huawei/tutorial/grpc/DoubleStreamServerSideApplication.java

```java
@SpringBootApplication
public class DoubleStreamServerSideApplication {
    public static void main(String[] args) {
        SpringApplication.run(DoubleStreamServerSideApplication.class, args);
    }
}
```

### double-stream-client-side

double-stream/double-stream-client-side/src/main/resources/application.yml

```yml
server:
  port: 9007
spring:
  application:
    name: double-stream-server-side
# gRPC有关的配置，配置服务器的端口号
grpc:
  server:
    port: 9106
  client:
    # gRPC配置的名字，GrpcClient注解会用到
    double-stream-server-side:
      # gRPC服务端地址
      address: 'static://127.0.0.1:9105'
      enableKeepAlive: true
      keepAliveWithoutCalls: true
      negotiationType: plaintext
```

double-stream/double-stream-client-side/src/main/java/com/huawei/tutorial/grpc/observer/ExtendResponseObserver.java

```java 
public interface ExtendResponseObserver<T> extends StreamObserver<T> {
    String getExtra();
}
```

double-stream/double-stream-client-side/src/main/java/com/huawei/tutorial/grpc/client/StockClient.java

```java
@Service
@Slf4j
public class StockClient {
    /**
     * 根据yml配置文件配置服务端信息
     */
    @GrpcClient("double-stream-server-side")
    private StockServiceGrpc.StockServiceStub stockServiceStub;

    /**
     * 批量增加库存
     * @param count
     * @return
     */
    public String batchAdd(int count) {
        CountDownLatch countDownLatch = new CountDownLatch(1);

        // responseObserver的onNext和onCompleted会在另一个线程中被执行，
        // ExtendResponseObserver继承自StreamObserver
        ExtendResponseObserver<AddReply> responseObserver = new ExtendResponseObserver<AddReply>() {

            // 用stringBuilder保存所有来自服务端的响应
            private StringBuilder stringBuilder = new StringBuilder();

            @Override
            public String getExtra() {
                return stringBuilder.toString();
            }

            /**
             * 客户端的流式请求期间，每一笔请求都会收到服务端的一个响应，
             * 对应每个响应，这里的onNext方法都会被执行一次，入参是响应内容
             * @param value
             */
            @Override
            public void onNext(AddReply value) {
                log.info("batch add on next");
                // 放入匿名类的成员变量中
                stringBuilder.append(String.format("返回码[%d]，返回信息:%s<br>", value.getCode(), value.getMessage()));
            }

            @Override
            public void onError(Throwable t) {
                log.error("batch add gRPC request error", t);
                stringBuilder.append("batch add gRPC error, " + t.getMessage());
                countDownLatch.countDown(); // 出现异常，线程结束
            }

            /**
             * 服务端确认响应完成后，这里的onCompleted方法会被调用
             */
            @Override
            public void onCompleted() {
                log.info("batch add on complete");
                // 执行了countDown方法后，前面执行countDownLatch.await方法的线程就不再wait了，
                // 会继续往下执行
                countDownLatch.countDown();
            }
        };

        // 远程调用，此时数据还没有给到服务端
        StreamObserver<ProductInfo> requestObserver = stockServiceStub.batchAdd(responseObserver);

        for (int i = 0; i < count; i++) {
            // 每次执行onNext都会发送一笔数据到服务端，
            // 服务端的onNext方法都会被执行一次
            requestObserver.onNext(build(101 + i, 1 + i));
        }

        // 客户端告诉服务端：数据已经发完了
        requestObserver.onCompleted();

        try {
            // 开始等待，如果服务端处理完成，那么responseObserver的onCompleted方法会在另一个线程被执行，
            // 那里会执行countDownLatch的countDown方法，一但countDown被执行，下面的await就执行完毕了，
            // await的超时时间设置为2秒
            countDownLatch.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            log.error("countDownLatch await error", e);
        }

        log.info("service finish");
        // 服务端返回的内容被放置在requestObserver中，从getExtra方法可以取得
        return responseObserver.getExtra();
    }

    /**
     * 创建ProductInfo对象
     *
     * @param productId 商品ID
     * @param num 入库数量
     * @return
     */
    private static ProductInfo build(int productId, int num) {
        return ProductInfo.newBuilder().setProductId(productId).setNumber(num).build();
    }

}
```

double-stream/double-stream-client-side/src/main/java/com/huawei/tutorial/grpc/controller/StockController.java

```java
@RestController
public class StockController {
    @Autowired
    private StockClient stockClient;

    @RequestMapping("batchAdd")
    public String batchAdd(@RequestParam("count") int count) {
        return stockClient.batchAdd(count);
    }
}
```

double-stream/double-stream-client-side/src/main/java/com/huawei/tutorial/grpc/DoubleStreamClientSide.java

```java
@SpringBootApplication
public class DoubleStreamClientSide {
    public static void main(String[] args) {
        SpringApplication.run(DoubleStreamClientSide.class, args);
    }
}
```

### 验证

http://localhost:9007/batchAdd?count=8

![image-20220526114841966](img/image-20220526114841966.png)

服务器端终端输出信息如下

![image-20220526115716034](img/image-20220526115716034.png)

## 参考资料

[yidongnan](https://github.com/yidongnan/grpc-spring-boot-starter)

[grpc-java](https://github.com/grpc/grpc-java)

[程序员欣宸](https://github.com/zq2599/blog_demos)

[java版gRPC实战之四：客户端流](https://xinchen.blog.csdn.net/article/details/116097756)

[LogNet](https://github.com/LogNet/grpc-spring-boot-starter)

