# 针对小而多的字符串解析最优解QLExpress

## 背景

最近在做字符串解析的需求，针对多个不同的参数的多个不同的表达式的解析，为追求性能，针对Groovy、QLExpress、Aciator，做了简单的性能测试

## 编码测试

为了简化开发，方便日志输出，项目引入Lombok、test等依赖

```xml
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>1.18.22</version>
    <scope>compile</scope>
</dependency>
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>slf4j-simple</artifactId>
    <version>1.7.25</version>
    <scope>compile</scope>
</dependency>
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter-api</artifactId>
    <version>5.8.2</version>
    <scope>test</scope>
</dependency>
```

### Groovy

常用的Java调用Groovy脚本的方式有三四种，这里使用GroovyShell

- GroovyScriptEngine是监控到groovy文件发生变化之后，才重新加载文件解析，而需求是多个不同表达式，需要不断的执行 IO 操作，经测试后存在字符串表达式已经变化，写到文件里后，加载解析时提示还有数据没绑定，经排查后发现Java代码修改文件后，需要几毫秒的时间物理存储上才会被修改，有时会存在加载解析的groovy文件依旧是未修改文件的情况。

- GroovyClassLoder 存在同样的 IO 瓶颈， GroovyClassLoder  对于参数的绑定也很不友好

- InvokerHelper 效率与 GroovyShell 差不多

#### 依赖

```xml
<dependency>
    <groupId>org.codehaus.groovy</groupId>
    <artifactId>groovy</artifactId>
    <version>3.0.10</version>
</dependency>
```

#### 代码

绑定上下文，解析脚本

```java
public static Object calculateByGroovyShell(String express, Map<String, Object> context) {
    Binding initBinding = new Binding();
    // 设置参数
    context.forEach(initBinding::setVariable);
    GroovyShell shell = new GroovyShell(initBinding);

    Object eval = null;
    try {
        // 根据当前绑定评估一些脚本并返回结果
        eval = shell.evaluate(express);
    } catch (Exception e) {
        log.info("The error is: {}", e.getMessage());
    } finally {
        // 清缓存
        shell.getClassLoader().clearCache();
    }
    return eval;
}
```

#### 测试

封装数据后解析多次，日志输入多次运行消耗的时间

```java
@Test
void calculateByGroovyShell() {
    HashMap<String, Object> context = new HashMap<>();
    List<String> expressList = new ArrayList<>();
    {
        expressList.add("text1.split(\":\")[1] + \".sblbdsj123\";");
        expressList.add("text2.split(\":\")[1] + \".sblbdsj123\";");
        expressList.add("text3.split(\"\\\\|\")[1] + \".\" + (text3.split(\"\\\\|\")[0].split(\":\"))[1].substring(0, 3) + \".MAC\";");
        expressList.add("text4.split(\"\\\\|\")[1] + \".\" + (text4.split(\"\\\\|\")[0].split(\"\\\\.\"))[1].substring(0, 4) + \".MAC\";");
        expressList.add("Integer.parseInt(text5.split(\":\")[1]) * 5");
        expressList.add("Integer.parseInt(text6.split(\":\")[1]) + 5");
        expressList.add("l/3");
        expressList.add("((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"");
        expressList.add("(d+e/3)+(d*e)");
        expressList.add("if([1, 2, 3, 4, 5].contains(f)){ return true; } else { return false }");
        context.put("text1", "sblbdsj1231:abc");
        context.put("text2", "sblbdsj1231:thisIsNil");
        context.put("text3", "u1:WIN1|linux");
        context.put("text4", "y1s1.YYDS1|superStar");
        context.put("text5", "a:123");
        context.put("text6", "a:1024");
        context.put("l", 6);
        context.put("a", 1);
        context.put("b", 2);
        context.put("c", -3);
        context.put("e", 12);
        context.put("d", 10);
        context.put("f", 4);
    }
    long starTime = System.currentTimeMillis();
    for (int i = 0; i < 1000; i++) {
        for (String s : expressList) {
            Calculator.calculateByGroovyShell(s, context);
        }
    }
    long endTime = new Date().getTime();
    long timeTaken = endTime - starTime;
    log.info("GroovyShell运行时间为：{}ms", timeTaken);
}
```

### QLExpress

阿里家的框架，遵循[Apache-2.0 license](https://github.com/alibaba/QLExpress/blob/master/LICENSE)，使用自定义的QL弱语言脚本

#### 依赖

```xml
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>QLExpress</artifactId>
    <version>3.3.0</version>
</dependency>
```

#### 代码

```java
// QLExpress 语法分析和计算的入口
private static final ExpressRunner EXPRESS_RUNNER = new ExpressRunner(true, false);
public static Object calculateByQLExpress(String express, DefaultContext<String, Object> context) {
    // 开启高精度，关闭输出所有的跟踪信息
    Object eval = null;
    try {
        eval = EXPRESS_RUNNER.execute(express, context, null, true, false);
    } catch (Exception e) {
        log.info("The error is: {}", e.getMessage());
    } finally {
        EXPRESS_RUNNER.clearExpressCache();
    }
    return eval;
}
```

#### 测试

```java
@Test
void calculateByQLExpress() {
    DefaultContext<String, Object> context = new DefaultContext<>();
    List<String> expressList = new ArrayList<>();
    {
        expressList.add("text1.split(\":\")[1] + \".sblbdsj123\";");
        expressList.add("text2.split(\":\")[1] + \".sblbdsj123\";");
        expressList.add("text3.split(\"\\\\|\")[1] + \".\" + (text3.split(\"\\\\|\")[0].split(\":\"))[1].substring(0, 3) + \".MAC\";");
        expressList.add("text4.split(\"\\\\|\")[1] + \".\" + (text4.split(\"\\\\|\")[0].split(\"\\\\.\"))[1].substring(0, 4) + \".MAC\";");
        expressList.add("Integer.parseInt(text5.split(\":\")[1]) * 5");
        expressList.add("Integer.parseInt(text6.split(\":\")[1]) + 5");
        expressList.add("l/3");
        expressList.add("((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"");
        expressList.add("(d+e/3)+(d*e)");
        expressList.add("if(f in (1, 2, 3, 4, 5)){ return true; } else { return false }");
        context.put("text1", "sblbdsj1231:abc");
        context.put("text2", "sblbdsj1231:thisIsNil");
        context.put("text3", "u1:WIN1|linux");
        context.put("text4", "y1s1.YYDS1|superStar");
        context.put("text5", "a:123");
        context.put("text6", "a:1024");
        context.put("l", 6);
        context.put("a", 1);
        context.put("b", 2);
        context.put("c", -3);
        context.put("e", 12);
        context.put("d", 10);
        context.put("f", 4);
    }
    long starTime = System.currentTimeMillis();
    for (int i = 0; i < 10000; i++) {
        for (String s : expressList) {
            Calculator.calculateByQLExpress(s, context);
        }
    }
    long endTime = new Date().getTime();
    long timeTaken = endTime - starTime;
    log.info("QLExpress运行时间为：{}ms", timeTaken);
}
```

### Aviator

[项目主页](https://github.com/killme2008/aviatorscript)

#### 依赖

```xml
<dependency>
    <groupId>com.googlecode.aviator</groupId>
    <artifactId>aviator</artifactId>
    <version>5.3.1</version>
</dependency>
```

#### 代码

```java
public static Object calculateByAviator(String express, HashMap<String, Object> context) {
    Object eval = null;
    try {
        eval = AviatorEvaluator.execute(express, context); // 执行文本表达式而不缓存
    } catch (Exception e) {
        log.info("The error is: {}", e.getMessage());
    } finally {
        AviatorEvaluator.clearExpressionCache(); // 清除所有缓存的编译表达式,此处可不加，测试时没发现有影响运行时间
    }
    return eval;
}
```

#### 测试

```java
@Test
void calculateByAviator() {
    HashMap<String, Object> context = new HashMap<>();
    List<String> expressList = new ArrayList<>();   // 存放执行的表达式
    // expressList 与 context 数据封装
    {
        expressList.add("string.split(text1, ':')[1] + '.sblbdsj123'");
        expressList.add("string.split(text2, ':')[1] + '.sblbdsj123'");
        expressList.add("string.split(text3, '\\\\|')[1] + '.' + string.substring(string.split(string.split(text3, '\\\\|')[0], ':')[1], 0, 3) + '.MAC'");
        expressList.add("string.split(text4, '\\\\|')[1] + '.' + string.substring(string.split(string.split(text4, '\\\\|')[0], '\\\\.')[1], 0, 4) + '.MAC'");
        expressList.add("long(string.split(text5, ':')[1]) * 5");
        expressList.add("long(string.split(text6, ':')[1]) + 5");
        expressList.add("l/3");
        expressList.add("((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"");
        expressList.add("(d+e/3)+(d*e)");
        expressList.add("include(seq.array(int, 1, 2, 3, 4, 5), f) ? true : false ");
        context.put("text1", "sblbdsj1231:abc");
        context.put("text2", "sblbdsj1231:thisIsNil");
        context.put("text3", "u1:WIN1|linux");
        context.put("text4", "y1s1.YYDS1|superStar"); // superStar.YYDS.MAC
        context.put("text5", "a:123");
        context.put("text6", "a:1024");
        context.put("l", 6);
        context.put("a", 1);
        context.put("b", 2);
        context.put("c", 3);
        context.put("d", 10);
        context.put("e", 12);
        context.put("f", 4);
    }
    long starTime = System.currentTimeMillis();
    for (int i = 0; i < 1000; i++) {
        for (String s : expressList) {
            Calculator.calculateByAviator(s, context);
        }
    }
    long endTime = new Date().getTime();
    long timeTaken = endTime - starTime;
    log.info("Aviator运行时间为：{}ms", timeTaken);
}
```

## 对比

### 语法对比

QLExpress与Groovy的语法基本一致，支持 java.lang 包以及 java.util包下的大部分类与方法

Aviator的语法在数值运算上与前两者一致，但大多操作需要用到自有语法与函数

| 表达式                       | 结果                 | QLExpress                                                    | Groovy                                                       | aviator                                                      |
| ---------------------------- | -------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| text="sblbdsj1231:abc"       | abc.sblbdsj123       | `text.split(\":\")[1] + \".sblbdsj123\";`                    | `text.split(\":\")[1] + \".sblbdsj123\";`                    | `string.split(text, ':')[1] + '.sblbdsj123'`                 |
| text="sblbdsj1231:thisIsNil" | thisIsNil.sblbdsj123 | `text.split(\":\")[1] + \".sblbdsj123\";`                    | `text.split(\":\")[1] + \".sblbdsj123\";`                    | `string.split(text, ':')[1] + '.sblbdsj123'`                 |
| text="u1:WIN1                | linux.WIN.MAC        | linux"`text.split("\\|")[1] + "." + (text.split("\\|")[0].split(":"))[1].substring(0, 3) + ".MAC";` | `text.split("\\|")[1] + "." + (text.split("\\|")[0].split(":"))[1].substring(0, 3) + ".MAC";` | `string.split(text, '\\|')[1] + '.' + string.substring(string.split(string.split(text, '\\|')[0], ':')[1], 0, 3) + '.MAC'` |
| text="y1s1.YYDS1             | superStar.YYDS.MAC   | superStar"`text.split("\\|")[1] + "." + (text.split("\\|")[0].split("\\."))[1].substring(0, 4) + ".MAC";` | `text.split("\\|")[1] + "." + (text.split("\\|")[0].split("\\."))[1].substring(0, 4) + ".MAC";` | `string.split(text, '\\|')[1] + '.' + string.substring(string.split(string.split(text, '\\|')[0], '\\.')[1], 0, 4) + '.MAC'` |
| text="a:123"                 | 615                  | `Integer.parseInt(text.split(\":\")[1]) * 5`                 | `Integer.parseInt(text.split(\":\")[1]) * 5`                 | `long(string.split(text, ':')[1]) * 5`                       |
| text="a:1024"                | 1029                 | `Integer.parseInt(text.split(\":\")[1]) + 5`                 | `Integer.parseInt(text.split(\":\")[1]) + 5`                 | `long(string.split(text, ':')[1]) + 5`                       |
| l=6                          | 2                    | `l/3`                                                        | `l/3`                                                        | `l/3`                                                        |
| a=1, b=2, c=-3               | 1 or 0               | `((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"`                   | `((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"`                   | `((a+b)*(a+b)-4*a*c) > 0 ? 2 : \"1 or 0\"`                   |
| d=10, e=12                   | 134                  | `(d+e/3)+(d*e)`                                              | `(d+e/3)+(d*e)`                                              | `(d+e/3)+(d*e)`                                              |
| f=4                          | true                 | `if(f in (1, 2, 3, 4, 5)){ return true; } else { return false }` | `if([1, 2, 3, 4, 5].contains(f)){ return true; } else { return false }` | `include(seq.array(int, 1, 2, 3, 4, 5), f) ? true : false`   |

### 运行时间对比

GroovyShell 的 evaluate(String scriptText) 的开销较大，导致每回绑定上下文执行脚本解析耗时都很多，不适合这种表达式以及参数不断变化的应用场景

|           | 10 000  | 5 000    | 1 000   | 100    | 1      |
| --------- | ------- | -------- | ------- | ------ | ------ |
| QLExpress | 12044ms | 6958ms   | 2365ms  | 862ms  | 186ms  |
| Groovy    |         | 321061ms | 67387ms | 9792ms | 1961ms |
| Aviator   | 26471ms | 13876ms  | 3728ms  | 914ms  | 422ms  |

## 结论

运行速度上：QLExpress > Aviator  >> Groovy

对比起来，QLExpress 解析字符串表达式的性能最好，且表达式近似Java，可用Java的Java.lang以及java.util包的类进行操作，语法学习成本低

具体的语法，可参考[QLExpress官方文档](https://github.com/alibaba/QLExpress/blob/master/README.md)，写的较为详细，清晰明了，我也转载在W3上，[方便在W3查看](http://3ms.huawei.com/km/blogs/details/12314057?l=zh-cn)

