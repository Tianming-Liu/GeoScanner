#ifndef MQTTMANAGER_H
#define MQTTMANAGER_H

#include <Arduino.h>

class MQTTManager {
public:
    void init();
    void handle();
    void uploadSensorData(const String& data);
private:
    void callback(char* topic, byte* payload, unsigned int length);
    void reconnect();
};

#endif // MQTTMANAGER_H
