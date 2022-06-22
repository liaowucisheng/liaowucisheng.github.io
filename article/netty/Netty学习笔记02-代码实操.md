# Netty学习笔记02-代码实操

## Netty-TCP实例

### 服务端

```java
@Slf4j
public class TCPServer {
    /**
     * 启动
     */
    public void start(int port) throws Exception {
        /*
        new NioEventLoopGroup() 含有子线程默认为CPU核数*2，传入数字即为指定线程数，0即获取CPU数，再乘2创建线程
        super(nThreads == 0 ? DEFAULT_EVENT_LOOP_THREADS : nThreads, executor, args);
        static {
            DEFAULT_EVENT_LOOP_THREADS = Math.max(1, SystemPropertyUtil.getInt(
                "io.netty.eventLoopThreads", NettyRuntime.availableProcessors() * 2));
        }
         */
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();

        try {
            ServerBootstrap serverBootstrap = new ServerBootstrap();
            serverBootstrap.group(bossGroup, workerGroup)   // 设置EventLoopGroup，处理ServerChannel和Channel的所有事件和 IO
                    .channel(NioServerSocketChannel.class)  // 在调用bind()时创建Channel实例
                    .childHandler(                          // 设置用于为Channel的请求提供服务的ChannelHandler
                            new TCPServerInitializer());    // 管道pipeline里添加 ChannelHandler

            ChannelFuture channelFuture = serverBootstrap.bind(port).sync();    // 从指点端口启动
            channelFuture.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new TCPServer().start(8845);
    }
}
```

```java
/**
 * 管道 pipeline 里添加 ChannelHandler 用于业务实现
 */
public class TCPServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipeline = ch.pipeline();
        pipeline.addLast(new TCPServerChannelHandler());   // 管道 pipeline 里添加 ChannelHandler 用于业务实现
    }
}
```

```java
@Slf4j
public class TCPServerChannelHandler extends ChannelInboundHandlerAdapter {
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        ByteBuf in = (ByteBuf) msg;
        log.info("接收到客户端{}的数据: {}", ctx.channel().remoteAddress(), in.toString(CharsetUtil.UTF_8));
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
        //将未决消息冲刷到远程节点，并且关闭该 Channel
        ctx.writeAndFlush(Unpooled.copiedBuffer("你好，我是服务端" + Thread.currentThread().getName(), CharsetUtil.UTF_8))
                .addListener(ChannelFutureListener.CLOSE);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        log.error("异常信息：{}", cause.getMessage());
        ctx.close();
    }
}
```

### 客户端

```java
public class TCPClient {
    public void start(String inetAddress, int inetPort) throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();

        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(group).channel(NioSocketChannel.class)
                    .handler(new TCPClientInitializer()); // 自定义一个初始化类

            ChannelFuture channelFuture = bootstrap.connect(inetAddress, inetPort).sync();

            channelFuture.channel().closeFuture().sync();

        } finally {
            group.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new TCPClient().start("127.0.0.1", 8845);
    }
}
```

```java
public class TCPClientInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipeline = ch.pipeline();
        pipeline.addLast(new TCPClientChannelHandler());
    }
}
```

```java
@Slf4j
public class TCPClientChannelHandler extends SimpleChannelInboundHandler<ByteBuf> {
    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        // 当被通知 Channel是活跃的时候，发送一条消息
        log.info("{}正在向服务端发送消息", Thread.currentThread().getName());
        ctx.writeAndFlush(Unpooled
                .copiedBuffer("这是客户端" + Thread.currentThread().getName() + "发送的消息", CharsetUtil.UTF_8));
    }

    @Override
    public void channelRead0(ChannelHandlerContext ctx, ByteBuf in) {
        // 记录已接收消息的转储
        log.info("客户端接收到服务端发送的消息是: " + in.toString(CharsetUtil.UTF_8));
    }

    @Override
    // 在发生异常时，记录错误并关闭Channel
    public void exceptionCaught(ChannelHandlerContext ctx,
                                Throwable cause) {
        log.error(cause.getMessage());
        ctx.close();
    }
}
```

## taskQueue&scheduledTaskQueue

每个NioEventLoop线程都会执行任务队列里的所有任务

任务队列所有任务在同一线程

在TCPServerChannelHandler.java里添加

```java
@Slf4j
public class TCPServerChannelHandler extends ChannelInboundHandlerAdapter {
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // 1. 执行耗时较久时，可选择异步方法
        //Thread.sleep(10 * 1000);
        //log.info("耗时很长的方法");
        // 2. task Queue 异步执行task，但这些任务都是在同一线程里的，所以有先后执行顺序。 可通过execute可以向任务队列里存放多个任务
        ctx.channel().eventLoop().execute(new Runnable() {
            @Override
            public void run() {
                try {
                    Thread.sleep(10 * 1000);
                    log.info("execute异步任务执行成功");
                } catch (InterruptedException e) {
                    log.error(e.getMessage());
                }
            }
        });
        // 3. schedule 用户自定义定时任务。与 execute 同线程
        ctx.channel().eventLoop().schedule(new Runnable() {
            @Override
            public void run() {
                try {
                    Thread.sleep(10 * 1000);
                    log.info("schedule定时任务执行成功");
                } catch (InterruptedException e) {
                    log.error(e.getMessage());
                }
            }
        }, 10, TimeUnit.SECONDS);
        // TCP demo 初始简单代码示例
        ByteBuf in = (ByteBuf) msg;
        log.info("接收到客户端{}的数据: {}", ctx.channel().remoteAddress(), in.toString(CharsetUtil.UTF_8));
    }
	...
}
```

## 异步模型与FutureListener机制

- 异步的概念和同步相对。当一个异步过程调用发出后，调用者不能立刻得到结果。实际处理这个调用的组件在完成后，通过状态、通知和回调来通知调用者。
- Netty 中的 I/O 操作是异步的，包括 Bind、Write、Connect 等操作会简单的返回一个 ChannelFuture。
- 调用者并不能立刻获得结果，而是通过 Future-Listener 机制，用户可以方便的主动获取或者通过通知机制获得 IO 操作结果
- Netty 的异步模型是建立在 future 和 callback 的之上的。
  **callback 就是回调。**
  **重点说 Future**，它的核心思想 是：假设一个方法 fun，计算过程可能非常耗时，等待 fun 返回显然不合适。那么可以在调用 fun 的时候，立马返回一个 Future，后续可以通过 Future 去监控方法 fun 的处理过程(即 ： Future-Listener 机制)

TCPServer.java

```java
@Slf4j
public class TCPServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap serverBootstrap = new ServerBootstrap();
            serverBootstrap.group(bossGroup, workerGroup)   // 设置EventLoopGroup，处理ServerChannel和Channel的所有事件和 IO
                    .channel(NioServerSocketChannel.class)  // 在调用bind()时创建Channel实例
                    .option(ChannelOption.SO_KEEPALIVE, true) // 保持连接
                    .childHandler(                          // 设置用于为Channel的请求提供服务的ChannelHandler
                            new TCPServerInitializer());    // 管道pipeline里添加 ChannelHandler

            ChannelFuture channelFuture = serverBootstrap.bind(port).sync();    // 从指点端口启动

            // Future-Listener机制
            channelFuture.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    if (channelFuture.isSuccess()) {
                        log.info("监听{}端口成功", port);
                    } else {
                        log.info("监听{}端口失败", port);
                    }
                }
            });
		...
        } finally {
            ...
        }
    }
	...
}
```

## Netty-HTTP实例

相比较TCP例子，在Handler里传递的对象是HttpObject类，Netty支持的其它协议，基本就是传递参数的不同，如

将访问的数据转化为HttpRequest类，之后进行操作

### 服务端

```java
public class HttpServer {
    public static void main(String[] args) {
        new HttpServer().start(8846);
    }

    /**
     * 指定端口启动HTTP服务
     *
     * @param port 服务启动端口
     */
    public void start(int port) {
        NioEventLoopGroup bossGroup = new NioEventLoopGroup();
        NioEventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap serverBootstrap = new ServerBootstrap();
            serverBootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .childHandler(new HtpServerInitializer());
            ChannelFuture channelFuture = serverBootstrap.bind(port).sync();
            channelFuture.channel().closeFuture().sync();
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            try {
                bossGroup.shutdownGracefully().sync();
                workerGroup.shutdownGracefully().sync();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
```

```java
public class HtpServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipeline = ch.pipeline();
        pipeline.addLast("coder&decoder", new HttpServerCodec());
        pipeline.addLast("MyHttpHandler", new HttpServerChannelHandler());
    }
}
```

```java
@Slf4j
public class HttpServerChannelHandler extends SimpleChannelInboundHandler<HttpObject> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, HttpObject msg) throws Exception {
        log.info("客户端地址: {}\n客户端channel: {}\n客户端pipeline: {}\n当前ctx的Handler: {}",
                ctx.channel().remoteAddress(), ctx.channel(), ctx.pipeline(), ctx.handler());
        if (msg instanceof HttpRequest) {
            log.info("ctx类型: {}, msg类型: {}", ctx.getClass(), msg.getClass());
            HttpRequest httpRequest = (HttpRequest) msg;
            URI uri = new URI(httpRequest.uri());
            if ("/favicon.ico".equals(uri.getPath())) {
                log.info("请求了 favicon.ico，不响应");
                return;
            }
            // 回复消息给客户端
            ByteBuf content = Unpooled.copiedBuffer(("你好，这里是服务器: " + Thread.currentThread().getName()), CharsetUtil.UTF_8);
            // 设置协议
            FullHttpResponse httpResponse = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK, content);
            // 头
            httpResponse.headers().set(HttpHeaderNames.CONTENT_TYPE, "text/plain");
            httpResponse.headers().set(HttpHeaderNames.CONTENT_LENGTH, content.readableBytes());
            ctx.writeAndFlush(httpResponse);
        }
    }
}
```

## 核心模块组件(推荐看Netty in action)

### Bootstrap、ServerBootstrap

Bootstrap 意思是引导，一个 Netty 应用通常由一个 Bootstrap 开始，主要作用是配置整个 Netty 程序，串联各个组件，Netty 中 Bootstrap 类是客户端程序的启动引导类，ServerBootstrap 是服务端启动引导类
常见的方法有

> public ServerBootstrap group(EventLoopGroup parentGroup, EventLoopGroup childGroup)，该方法用于服务器端， 用来设置两个 EventLoop
> public B group(EventLoopGroup group) ，该方法用于客户端，用来设置一个 EventLoop
> public B channel(Class<? extends C> channelClass)，该方法用来设置一个服务器端的通道实现
> public B option(ChannelOption option, T value)，用来给 ServerChannel 添加配置
> public ServerBootstrap childOption(ChannelOption childOption, T value)，用来给接收到的通道添加配置
> public ServerBootstrap childHandler(ChannelHandler childHandler)，该方法用来设置业务处理类（自定义的 handler）
> public ChannelFuture bind(int inetPort) ，该方法用于服务器端，用来设置占用的端口号
> public ChannelFuture connect(String inetHost, int inetPort) ，该方法用于客户端，用来连接服务器端

### Future、ChannelFuture

Netty 中所有的 IO 操作都是异步的，不能立刻得知消息是否被正确处理。但是可以过一会等它执行完成或者直接注册一个监听，具体的实现就是通过 Future 和 ChannelFutures，他们可以注册一个监听，当操作执行成功或失败时监听会自动触发注册的监听事件.

常见的方法有

> Channel channel()，返回当前正在进行 IO 操作的通道
> ChannelFuture sync()，等待异步操作执行完毕

### Channel

- Netty 网络通信的组件，能够用于执行网络 I/O 操作。
- 通过 Channel 可获得当前网络连接的通道的状态
- 通过 Channel 可获得网络连接的配置参数 （例如接收缓冲区大小）
- Channel 提供异步的网络 I/O 操作(如建立连接，读写，绑定端口)，异步调用意味着任何 I/O 调用都将立即返 回，并且不保证在调用结束时所请求的 I/O 操作已完成
- 调用立即返回一个 ChannelFuture 实例，通过注册监听器到 ChannelFuture 上，可以 I/O 操作成功、失败或取 消时回调通知调用方
- 支持关联 I/O 操作与对应的处理程序
- 不同协议、不同的阻塞类型的连接都有不同的 Channel 类型与之对应，常用的 Channel 类型:

> NioSocketChannel，异步的客户端 TCP Socket 连接。
> NioServerSocketChannel，异步的服务器端 TCP Socket 连接。
> NioDatagramChannel，异步的 UDP 连接。
> NioSctpChannel，异步的客户端 Sctp 连接。
> NioSctpServerChannel，异步的 Sctp 服务器端连接，这些通道涵盖了 UDP 和 TCP 网络 IO 以及文件 IO。

### Selector

- Netty 基于 Selector 对象实现 I/O 多路复用，通过 Selector 一个线程可以监听多个连接的 Channel 事件。
- 当向一个 Selector 中注册 Channel 后，Selector 内部的机制就可以自动不断地查询(Select) 这些注册的 Channel 是否有已就绪的 I/O 事件（例如可读，可写，网络连接完成等），这样程序就可以很简单地使用一个 线程高效地管理多个 Channel

###  ChannelHandler 及其实现类

- ChannelHandler 是一个接口，处理 I/O 事件或拦截 I/O 操作，并将其转发到其 ChannelPipeline(业务处理链) 中的下一个处理程序。 
- ChannelHandler 本身并没有提供很多方法，因为这个接口有许多的方法需要实现，方便使用期间，可以继承它 的子类
- ChannelHandler 及其实现类一览图(后)

![](https://img-blog.csdnimg.cn/8e1994a1ab9d46d6b97484dad6d58f24.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBATXJKc29uLeaetuaehOW4iA==,size_20,color_FFFFFF,t_70,g_se,x_16)

> • ChannelInboundHandler 用于处理入站（事件运动方向：服务端 -> 客户端） I/O 事件
> • ChannelOutboundHandler 用于 处理出站（事件运动方向：客户端 -> 服务端） I/O 操作
> —适配器
> • ChannelInboundHandlerAdapter 用于处理入站 I/O 事件。
> • ChannelOutboundHandlerAdapt er 用于处理出站 I/O 操作。
> • ChannelDuplexHandler 用于处理入站和出站事件。

- 我们经常需要自定义一 个 Handler 类去继承 ChannelInboundHandlerA dapter，然后通过重写相应方法实现业务逻辑

常用的方法

```java
public class ChannelInboundHandlerAdapter extends ChannelHandlerAdapter implements ChannelInboundHandler { 
	// 通道注册事件
	public void channelRegistered(ChannelHandlerContext ctx) throws Exception {
        ctx.fireChannelRegistered();
    }
	// 通道注销事件
    public void channelUnregistered(ChannelHandlerContext ctx) throws Exception {
        ctx.fireChannelUnregistered();
    }
	// 通道就绪事件 
	public void channelActive(ChannelHandlerContext ctx) throws Exception { 
		ctx.fireChannelActive(); 
	}
	// 通道读取数据事件 
	public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception { 
		ctx.fireChannelRead(msg); 
	}
	// 通道读取数据完毕事件
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
        ctx.fireChannelReadComplete();
    }
    // 通道发生异常事件
	public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        ctx.fireExceptionCaught(cause);
    }
}
```

### Pipeline 和 ChannelPipeline

ChannelPipeline 是一个重点：

- ChannelPipeline 是一个 Handler 的集合，它负责处理和拦截 inbound 或者 outbound 的事件和操作，相当于 一个贯穿 Netty 的链。(也可以这样理解：ChannelPipeline 是保存 ChannelHandler 的 List，用于处理或拦截 Channel 的入站事件和出站操作)

- ChannelPipeline 实现了一种高级形式的拦截过滤器模式，使用户可以完全控制事件的处理方式，以及 Channel 中各个的 ChannelHandler 如何相互交互

- 在 Netty 中每个 Channel 都有且仅有一个 ChannelPipeline 与之对应，它们的组成关系如下

![](https://img-blog.csdnimg.cn/b4e5cd38ecba4324974228219dd24672.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBATXJKc29uLeaetuaehOW4iA==,size_20,color_FFFFFF,t_70,g_se,x_16)

> - 一个 Channel 包含了一个 ChannelPipeline，而 ChannelPipeline 中又维护了一个由 ChannelHandlerContext 组成的双向链表，并且每个 ChannelHandlerContext 中又关联着一个 ChannelHandler
> - 入站事件和出站事件在一个双向链表中，入站事件会从链表 head 往后传递到最后一个入站的 handler， 出站事件会从链表 tail 往前传递到最前一个出站的 handler，两种类型的 handler 互不干扰
>
> ChannelPipeline addFirst(ChannelHandler… handlers)，把一个业务处理类（handler）添加到链中的第一个位置
> ChannelPipeline addLast(ChannelHandler… handlers)，把一个业务处理类（handler）添加到链中的最后一个位置

### ChannelHandlerContext

- 保存 Channel 相关的所有上下文信息，同时关联一个 ChannelHandler 对象

- 即 ChannelHandlerContext 中 包 含 一 个 具 体 的 事 件 处 理 器 ChannelHandler ， 同 时 ChannelHandlerContext 中也绑定了对应的 pipeline 和 Channel 的信息，方便对 ChannelHandler 进行调用.

  >  ChannelFuture close()，关闭通道
  >  ChannelOutboundInvoker flush()，刷新
  >  ChannelFuture writeAndFlush(Object msg) ， 将 数 据 写 到 ChannelPipeline 中 当 前
  >  ChannelHandler 的下一个 ChannelHandler 开始处理（出站）

### ChannelOption

- Netty 在创建 Channel 实例后,一般都需要设置 ChannelOption 参数。

- ChannelOption 参数如下:

  > ChannelOption.SO_BACKLOG :
  > 对应 TCP/IP 协议 listen 函数中的 backlog 参数，用来初始化服务器可连接队列大小。服务端处理客户端连接请求是顺序处理的，所以同一时间只能处理一个客户端连接。多个客户 端来的时候，服务端将不能处理的客户端连接请求放在队列中等待处理，backlog 参数指定了队列的大小。
  > ChannelOption.SO_KEEPALIVE :
  > 一直保持连接活动状态

### EventLoopGroup 和其实现类 NioEventLoopGroup

- EventLoopGroup 是一组 EventLoop 的抽象，Netty 为了更好的利用多核 CPU 资源，一般会有多个 EventLoop 同时工作，每个 EventLoop 维护着一个 Selector 实例。
- EventLoopGroup 提供 next 接口，可以从组里面按照一定规则获取其中一个 EventLoop 来处理任务。在 Netty 服 务 器 端 编 程 中 ， 我 们 一 般 都 需 要 提 供 两 个 EventLoopGroup ， 例 如 ： BossEventLoopGroup 和 WorkerEventLoopGroup。
- 通常一个服务端口即一个 ServerSocketChannel 对应一个 Selector 和一个 EventLoop 线程。BossEventLoop 负责 接收客户端的连接并将 SocketChannel 交给 WorkerEventLoopGroup 来进行 IO 处理，如下图所示

![](https://img-blog.csdnimg.cn/8cb07fba47864a148292cbb4c0233fb8.png?x-oss-process=image/watermark,type_d3F5LXplbmhlaQ,shadow_50,text_Q1NETiBATXJKc29uLeaetuaehOW4iA==,size_11,color_FFFFFF,t_70,g_se,x_16)

> BossEventLoopGroup 通常是一个单线程的 EventLoop，EventLoop 维护着一个注册了ServerSocketChannel 的 Selector 实例，BossEventLoop 不断轮询 Selector 将连接事件分离出来
> 通常是 OP_ACCEPT 事件，然后将接收到的 SocketChannel 交给 WorkerEventLoopGroup
> WorkerEventLoopGroup 会由 next 选择 其中一个 EventLoop来将这个 SocketChannel 注册到其维护的 Selector 并对其后续的 IO 事件进行处理 ，一个 EventLoop 可以处理多个 Channel
>
> public NioEventLoopGroup()，构造方法
> public Future<?> shutdownGracefully()，断开连接，关闭线程

## ByteBuf

ByteBuf 维护了两个不同的索引：一个用于读取，一个用于写入。当你从 ByteBuf 读取时， 它的 readerIndex 将会被递增已经被读取的字节数。同样地，当你写入 ByteBuf 时，它的 writerIndex 也会被递增。

```JAVA
public class NettyByteBuf01 {
    public static void main(String[] args) {
        // 创建一个ByteBuf
        // 说明
        // 1. 创建 对象，该对象包含一个数组arr , 是一个byte[10]
        // 2. 在netty 的buffer中，不需要使用flip 进行反转
        //    底层维护了 readerindex 和 writerIndex
        // 3. 通过 readerindex 和  writerIndex 和  capacity， 将buffer分成三个区域
        //  0---readerindex 已经读取的区域
        //  readerindex---writerIndex ， 可读的区域
        //  writerIndex -- capacity, 可写的区域
        ByteBuf byteBuf = Unpooled.buffer(10);
        for (int i = 0; i < byteBuf.capacity(); i++) {
            byteBuf.writeByte(i);   // 在当前writerIndex处设置指定字节，并将此缓冲区中的writerIndex增加1
            System.out.println(byteBuf.writerIndex());
        }
        for (int i = 0; i < byteBuf.capacity(); i++) {
            System.out.println(byteBuf.getByte(i));
            System.out.println(byteBuf.readerIndex());
        }
        for (int i = 0; i < byteBuf.capacity(); i++) {
            System.out.println(byteBuf.readByte());
            System.out.println(byteBuf.readerIndex());
        }
    }
}
```

```JAVA
public class NettyByteBuf02 {
    public static void main(String[] args) {
        // 创建ByteBuf
        ByteBuf byteBuf = Unpooled.copiedBuffer("hello,world!", Charset.forName("utf-8"));
        // 使用相关的方法
        if (byteBuf.hasArray()) { // true
            byte[] content = byteBuf.array();
            // 将 content 转成字符串
            System.out.println(new String(content, Charset.forName("utf-8")));
            System.out.println("byteBuf=" + byteBuf);
            System.out.println(byteBuf.arrayOffset()); // 0
            System.out.println(byteBuf.readerIndex()); // 0
            System.out.println(byteBuf.writerIndex()); // 12
            System.out.println(byteBuf.capacity()); // 64
            // System.out.println(byteBuf.readByte()); //
            System.out.println(byteBuf.getByte(0)); // 104
            int len = byteBuf.readableBytes(); // 12 可读的字节数，即已被写了的
            System.out.println("len=" + len);
            // 使用for取出各个字节
            for (int i = 0; i < len; i++) {
                System.out.println((char) byteBuf.getByte(i));
                // 按照某个范围读取
                System.out.println(byteBuf.getCharSequence(0, 4, Charset.forName("utf-8")));
                System.out.println(byteBuf.getCharSequence(4, 6, Charset.forName("utf-8")));
            }
        }
    }
}

```

## Netty群聊

### 服务端

```java
package server;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GroupServer {
    private Integer port;

    public GroupServer(Integer port){
        this.port = port;
    }

    public void run(){
        NioEventLoopGroup bossGroup = new NioEventLoopGroup(1);
        NioEventLoopGroup workerGroup = new NioEventLoopGroup();

        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            ChannelFuture channelFuture = bootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .option(ChannelOption.SO_BACKLOG, 128)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childHandler(new GroupServerInitializer())
                    .bind(port).sync();

            ChannelFuture sync = channelFuture.channel().closeFuture().sync();

            sync.addListener(future -> {
                if (future.isSuccess()) {
                    log.info("服务器绑定{}端口成功", port);
                }
            });


        } catch (InterruptedException e) {
            e.printStackTrace();
        }finally {
            try {
                bossGroup.shutdownGracefully().sync();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            try {
                workerGroup.shutdownGracefully().sync();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    public static void main(String[] args) {
        new GroupServer(10086).run();
    }
}
```

```java
package server;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;
import io.netty.handler.codec.http.HttpServerCodec;
import io.netty.handler.codec.string.StringDecoder;
import io.netty.handler.codec.string.StringEncoder;

public class GroupServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ch.pipeline()
                .addLast("decoder", new StringDecoder()) // 解码
                .addLast("encoder", new StringEncoder()) // 编码
                .addLast("GroupServerChannelHandler", new GroupServerChannelHandler());   // 业务处理
    }
}
```

```java
package server;

import io.netty.channel.Channel;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.channel.group.ChannelGroup;
import io.netty.channel.group.DefaultChannelGroup;
import io.netty.util.concurrent.GlobalEventExecutor;
import lombok.extern.slf4j.Slf4j;

import java.text.SimpleDateFormat;
import java.util.Date;

@Slf4j
public class GroupServerChannelHandler extends SimpleChannelInboundHandler<String> {
    // 定义一个channel组，管理所有 channel    GlobalEventExecutor.INSTANCE 单例，全局的事件执行器
    private static ChannelGroup channelGroup = new DefaultChannelGroup(GlobalEventExecutor.INSTANCE);
    private SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

    /**
     * 建立连接
     *
     * @param ctx
     * @throws Exception
     */
    @Override
    public void handlerAdded(ChannelHandlerContext ctx) throws Exception {
        // 将该客户加入聊天的信息推送给其它在线的客户端
        // 该方法会将 channelGroup 中所有的channel 遍历，并发送消息，我们不需要自己遍历
        Channel channel = ctx.channel();
        channelGroup.writeAndFlush("【客户端】" + channel.remoteAddress() + " 加入聊天" + sdf.format(new Date()));
        channelGroup.add(channel);
        log.info("channelGroup 在线人数：{}", channelGroup.size());
    }

    /**
     * 在线
     *
     * @param ctx
     * @throws Exception
     */
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        log.info("[客户端]{}上线了", ctx.channel().remoteAddress());
    }


    /**
     * 掉线
     *
     * @param ctx
     * @throws Exception
     */
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        log.info("[客户端]{}离线了", ctx.channel().remoteAddress());
    }


    /**
     * 断开连接
     *
     * @param ctx
     * @throws Exception
     */
    @Override
    public void handlerRemoved(ChannelHandlerContext ctx) throws Exception {
        channelGroup.writeAndFlush("[客户端]" + ctx.channel().remoteAddress() + "断开连接");
        log.info("channelGroup 在线人数：{}", channelGroup.size());
    }

    /**
     * 读取数据
     *
     * @param ctx
     * @param msg
     * @throws Exception
     */
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, String msg) throws Exception {
        Channel channel = ctx.channel();
        channelGroup.forEach(ch -> {
            // 不是自己的时候
            if (ch != channel) {
                ch.writeAndFlush("[客户]" + channel.remoteAddress() + " 发送了：" + msg + "\n");
            }
        });
    }

    /**
     * 异常捕获
     *
     * @param ctx
     * @param cause
     * @throws Exception
     */
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        ctx.close();    // 关闭连接
    }
}
```

### 客户端

```java
package client;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioSocketChannel;
import lombok.extern.slf4j.Slf4j;

import java.util.Scanner;

@Slf4j
public class GroupClient {
    private String host;
    private Integer port;

    public GroupClient(String host, Integer port) {
        this.host = host;
        this.port = port;
    }

    public void run() {
        NioEventLoopGroup group = new NioEventLoopGroup();
        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(group)
                    .channel(NioSocketChannel.class)
                    .option(ChannelOption.SO_BACKLOG, 128)
                    .handler(new GroupClientInitializer());
            ChannelFuture channelFuture = bootstrap.connect(host, port).sync();
            Channel channel = channelFuture.channel();
            log.info("----------[客户端]{}登录成功------------", channel.localAddress());
            Scanner scanner = new Scanner(System.in);
            while (true) {
                String msg = scanner.nextLine();
                channel.writeAndFlush(msg);
            }
        } catch (Exception e) {
            log.error(e.getMessage());
        } finally {
            group.shutdownGracefully();
        }
    }

    public static void main(String[] args) {
        new GroupClient("127.0.0.1", 10086).run();
    }
}
```

```java
package client;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelPipeline;
import io.netty.channel.socket.SocketChannel;
import io.netty.handler.codec.string.StringDecoder;
import io.netty.handler.codec.string.StringEncoder;

public class GroupClientInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        //得到pipeline
        ChannelPipeline pipeline = ch.pipeline();
        //加入相关handler
        pipeline.addLast("decoder", new StringDecoder());
        pipeline.addLast("encoder", new StringEncoder());
        //加入自定义的handler
        pipeline.addLast(new GroupClientChannelHandler());

    }
}
```

```java
package client;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GroupClientChannelHandler extends SimpleChannelInboundHandler<String> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, String msg) throws Exception {
        log.info(msg.trim());
    }
}
```

