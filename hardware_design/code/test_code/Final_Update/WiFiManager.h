#ifndef WIFIMANAGER_H
#define WIFIMANAGER_H

#include <Preferences.h>
#include <WiFiManager.h>
#include <Arduino.h>

class WiFiManager {
public:
    void init();
    void setLEDMode(bool connected);
};

#endif // WIFIMANAGER_H
