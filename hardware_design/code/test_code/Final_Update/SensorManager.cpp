#include "SensorManager.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

void SensorManager::init() {
    if (!bme.begin(0x77)) {
        Serial.println("Could not find a valid BME680 sensor, check wiring!");
        while (1);
    }
    bme.setTemperatureOversampling(BME680_OS_8X);
    bme.setHumidityOversampling(BME680_OS_2X);
    bme.setPressureOversampling(BME680_OS_4X);
    bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
    bme.setGasHeater(320, 150); // 320°C for 150 ms
}

String SensorManager::getSensorData() {
    if (!bme.performReading()) {
        Serial.println("Failed to perform reading :(");
        return "";
    }

    DynamicJsonDocument doc(1024);
    doc["temperature"] = bme.temperature;
    doc["humidity"] = bme.humidity;
    doc["pressure"] = bme.pressure / 100.0;
    doc["gas"] = bme.gas_resistance / 1000.0;

    String data;
    serializeJson(doc, data);
    return data;
}
