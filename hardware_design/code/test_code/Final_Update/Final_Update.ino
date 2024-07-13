#include "WiFiManager.h"
#include "CameraManager.h"
#include "SensorManager.h"
#include "MQTTManager.h"
#include "config.h"

// 全局对象
WiFiManager wifiManager;
CameraManager cameraManager;
SensorManager sensorManager;
MQTTManager mqttManager;

void setup() {
    Serial.begin(115200);

    // 初始化WiFi
    wifiManager.init();

    // 初始化摄像头
    cameraManager.init();

    // 初始化传感器
    sensorManager.init();

    // 初始化MQTT
    mqttManager.init();
}

void loop() {
    // 处理MQTT连接
    mqttManager.handle();

    // 每隔2秒上传数据
    static unsigned long lastUploadTime = 0;
    unsigned long currentMillis = millis();
    if (currentMillis - lastUploadTime >= 2000) {
        lastUploadTime = currentMillis;

        // 上传环境数据
        String sensorData = sensorManager.getSensorData();
        mqttManager.uploadSensorData(sensorData);

        // 上传图片
        cameraManager.uploadImage();
    }
}
