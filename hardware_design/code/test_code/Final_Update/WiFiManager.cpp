#include "WiFiManager.h"
#include "config.h"

Preferences preferences;

// LED模式设置函数
void WiFiManager::setLEDMode(bool connected) {
    static unsigned long previousMillis = 0; // 记录上一次更新时间
    unsigned long currentMillis = millis();  // 当前时间

    if (connected) {
        digitalWrite(ledPin, HIGH); // 已连接（常亮）
    } else {
        if (currentMillis - previousMillis >= 500) { // 每秒闪烁一次
            previousMillis = currentMillis;
            digitalWrite(ledPin, !digitalRead(ledPin)); // 取反当前LED状态
        }
    }
}

// 初始化WiFiManager
void WiFiManager::init() {
    preferences.begin("my-app", false);
    // 从Preferences中读取邮箱地址和密码
    String savedEmail = preferences.getString("email", "not set");
    String savedPassword = preferences.getString("password", "not set");

    savedEmail.toCharArray(email, 40);
    savedPassword.toCharArray(password, 40);

    Serial.println("Saved email: " + savedEmail);
    Serial.println("Saved password: " + savedPassword);

    // 自定义参数（邮箱和密码）
    WiFiManagerParameter custom_email("email", "Email", email, 40);
    WiFiManagerParameter custom_password("password", "Password", password, 40);

    // 添加自定义参数到WiFiManager
    wifiManager.addParameter(&custom_email);
    wifiManager.addParameter(&custom_password);

    // 设置保存参数的回调函数
    wifiManager.setSaveConfigCallback([]() {
        Serial.println("Saving Email and Password...");
        preferences.putString("email", email);
        preferences.putString("password", password);
        Serial.println("Email and Password saved.");
    });

    // 设置LED为闪烁模式
    setLEDMode(false);

    // 设置配置Portal时的回调函数，以便在配置模式时保持闪烁
    wifiManager.setAPCallback([](WiFiManager *myWiFiManager) {
        Serial.println("Entered AP mode");
    });

    // 尝试自动连接到已保存的WiFi网络，如果连接失败，则进入AP配置模式
    if (!wifiManager.autoConnect("ESP32-Config")) {
        Serial.println("Failed to connect and hit timeout");
        setLEDMode(false); // 进入AP模式时也设置为闪烁模式
    } else {
        // 如果连接成功，设置LED为常亮模式
        setLEDMode(true);
        Serial.println("Connected to Wi-Fi!");
        Serial.print("IP Address: ");
        Serial.println(WiFi.localIP());
    }

    // 保存邮箱地址和密码
    strcpy(email, custom_email.getValue());
