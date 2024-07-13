#include "MQTTManager.h"

#include <PubSubClient.h>
#include <Arduino.h>
#include "config.h"

WiFiClient espClient;
PubSubClient client(espClient);

void MQTTManager::init() {
    client.setServer(mqttServer, mqttPort);
    client.setCallback([this](char* topic, byte* payload, unsigned int length) {
        this->callback(topic, payload, length);
    });
}

void MQTTManager::handle() {
    if (!client.connected()) {
        reconnect();
    }
    client.loop();
}

void MQTTManager::uploadSensorData(const String& data) {
    String topic = String(email) + "/ESP_Data";
    client.publish(topic.c_str(), data.c_str());
}

void MQTTManager::callback(char* topic, byte* payload, unsigned int length) {
    // 如果需要处理接收到的MQTT消息，可以在这里实现
}

void MQTTManager::reconnect() {
    while (!client.connected()) {
        Serial.print("Attempting MQTT connection...");
        if (client.connect("ESP32Client", mqttUser, mqttPassword)) {
            Serial.println("connected");
            client.subscribe((String(email) + "/Status").c_str());
        } else {
            Serial.print("failed, rc=");
            Serial.print(client.state());
            Serial.println(" try again in 5 seconds");
            delay(5000);
        }
    }
}
