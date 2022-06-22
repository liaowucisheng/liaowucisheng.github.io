```xml 
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>MyUtils</artifactId>
        <groupId>org.example</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <artifactId>work-times</artifactId>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>fastjson</artifactId>
            <version>1.2.76</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/commons-io/commons-io -->
        <dependency>
            <groupId>commons-io</groupId>
            <artifactId>commons-io</artifactId>
            <version>2.11.0</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/org.projectlombok/lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.24</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>

    </dependencies>
</project>

```java
package common.pojo;

import com.alibaba.fastjson.annotation.JSONField;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Date;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Punch {
    /*
        "dt": "2022-04-01",
        "empId": "325306",
        "deptName": "综合交付部",
        "emp_code": "0000325306",
        "checktime": "2022-04-01 08:00:00",
        "locsetname": null,
        "empCode": "0000325306",
        "empName": "郑峻杰",
        "type": "1"
     */
    @JSONField(format = "yyyy-MM-dd HH:mm:ss SSS",name="dt")
    private Date dt;
    @JSONField(serialize = false)
    private Integer empId;
    @JSONField(name = "deptName")
    private String deptName;
     @JSONField(name = "emp_code")
    private String emp_code;
    @JSONField(format = "yyyy-MM-dd HH:mm:ss",name="checktime")
    private Date checktime;
     @JSONField(name = "locsetname")
    private String locsetname;
     @JSONField(name = "empCode")
    private String empCode;
     @JSONField(name = "empName")
    private String empName;
     @JSONField(name = "type")
    private Integer type;

}

```java
package common.utils;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import common.pojo.Punch;
import org.apache.commons.io.FileUtils;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.List;

public class TotalWorkTimes {


    public static void total(String filePath) {
        try {

            File file = new File(filePath);

            String jsonStr = FileUtils.readFileToString(file);//前面两行是读取文件
            JSONObject jsonObject = JSON.parseObject(jsonStr);

            /*
             获取JSON文件里的items标签里的内容，里面是本月打卡数据
             */
            List<Punch> list = JSON.parseArray(JSON.toJSONString(jsonObject.getJSONObject("result")
                    .getJSONObject("data")
                    .getJSONObject("page")
                    .getJSONArray("items")), Punch.class);
            SimpleDateFormat df = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");

            String hour;
            String minute;
            String sec;

            // 早上上班秒数总和
            int totalSec = 0;

            for (int i = 0; i < list.size(); i++) {
                // 打卡时间转换成指定格式
                String format = df.format(list.get(i).getChecktime());
                hour = format.substring(11, 13);
                minute = format.substring(14, 16);
                sec = format.substring(17, 19);

                if (i % 2 == 0) {   // 上班打卡
                    // 时间在八点之前，要变成八点
                    if (Integer.parseInt(hour) < 8) {
                        hour = "08";
                        minute = "00";
                        sec = "00";
                    }
                    // 超过九点算迟到，不足半小时的按半小时计算
                    if (Integer.parseInt(hour) >= 9) {
                        if (Integer.parseInt(minute) < 30) {
                            minute = "30";
                            sec = "00";
                        } else {
                            int newHour = Integer.parseInt(hour) + 1;
                            StringBuilder builder = new StringBuilder(newHour + "");
                            if (builder.length() < 2) {
                                builder.insert(0, '0');
                            }
                            hour = new String(builder);
                            minute = "00";
                            sec = "00";
                        }
                    }

                    System.out.println("上班时间：" + hour + ":" + minute + ":" + sec);
                    // 早上有来上班
                    if (Integer.parseInt(hour) < 12) {
                        totalSec += 12 * 60 * 60 - (Integer.parseInt(hour) * 60 * 60 + Integer.parseInt(minute) * 60 + Integer.parseInt(sec));
                    }


                } else {    // 下班打卡
                    // 五点半下班
                    if (Integer.parseInt(hour) == 17) {
                        if (Integer.parseInt(minute) > 30) {
                            minute = "30";
                            sec = "00";
                        }
                        // 一点半到五点半 共计4小时
                        totalSec += 4 * 60 * 60;
                    } else {
                        //    六点及以后才打卡下班，中间有半小时没算工时，所以算两点上班，方便计算
                        totalSec += (Integer.parseInt(hour) * 60 * 60 + Integer.parseInt(minute) * 60 + Integer.parseInt(sec)) -
                                (14 * 60 * 60);
                    }
                    System.out.println("下班时间：" + hour + ":" + minute + ":" + sec);
                }

            }
            System.out.println("共计秒数：" + totalSec);
            int hours = totalSec / (60 * 60);
            int minutes = (totalSec % (60 * 60)) / 60;
            int seconds = totalSec % 60;
            System.out.println("本月共计工作时长：" + hours + "小时，" + minutes + "分钟，" + seconds + "秒.");
        } catch (Exception e) {
            System.err.println("每日工时统计有问题，请确定今日考勤正常");
            e.printStackTrace();
        }
    }

    public static void main(String[] args) throws IOException {
        TotalWorkTimes.total("D:\\Java_code\\MyUtils\\work-times\\src\\main\\resources\\0527.json");
    }
}
