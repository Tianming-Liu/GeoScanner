#ifndef _config_H__
#define _config_H__

#include <Arduino.h>

// WiFi 配置
extern char email[40];
extern char password[40];

// MQTT 配置
const char* mqttServer = "35.178.35.159";
const int mqttPort = 1884;
const char* mqttUser = "tianming_liu";
const char* mqttPassword = "@BQQMGV3de#nDkZ";

// AWS 服务器配置
const char* awsServer = "http://<your-aws-server>/upload"; // 替换为你的AWS服务器地址

// BME680 传感器 I2C 地址
const int BME680_I2C_ADDRESS = 0x77;

// 摄像头引脚定义
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1
#define XCLK_GPIO_NUM    21
#define SIOD_GPIO_NUM    26
#define SIOC_GPIO_NUM    27

#define Y9_GPIO_NUM      35
#define Y8_GPIO_NUM      34
#define Y7_GPIO_NUM      39
#define Y6_GPIO_NUM      36
#define Y5_GPIO_NUM      19
#define Y4_GPIO_NUM      18
#define Y3_GPIO_NUM       5
#define Y2_GPIO_NUM       4
#define VSYNC_GPIO_NUM   25
#define HREF_GPIO_NUM    23
#define PCLK_GPIO_NUM    22

#endif
