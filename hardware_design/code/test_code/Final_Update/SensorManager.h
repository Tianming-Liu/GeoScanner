#ifndef SENSORMANAGER_H
#define SENSORMANAGER_H

#include <Adafruit_Sensor.h>
#include <Adafruit_BME680.h>
#include <Arduino.h>

class SensorManager {
public:
    void init();
    String getSensorData();
private:
    Adafruit_BME680 bme;
};

#endif // SENSORMANAGER_H
