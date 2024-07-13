#include <WiFi.h>
#include <WiFiManager.h>
#include <Preferences.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME680.h>
#include <WiFiClient.h>
#include <PubSubClient.h>

// WiFiManager对象
WiFiManager wifiManager;

// 创建Preferences对象
Preferences preferences;

// 定义LED引脚
const int ledPin = 2;

// 定义BME680传感器对象
Adafruit_BME680 bme;

// 定义WiFi客户端和MQTT客户端
WiFiClient espClient;
PubSubClient client(espClient);

// MQTT配置
const char* mqttServer = "35.178.35.159";
const int mqttPort = 1884;
const char* mqttUser = "tianming_liu";
const char* mqttPassword = "@BQQMGV3de#nDkZ";

// 定义全局变量来保存邮箱地址和密码
char email[40];
char password[40];

// 函数：设置LED闪烁模式
void setLEDMode(bool connected) {
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

// 回调函数：处理MQTT消息
void callback(char* topic, byte* payload, unsigned int length) {
  payload[length] = '\0';
  String message = String((char*)payload);

  if (String(topic) == "ESP32/Status" && message == "on") {
    // 获取传感器读数
    if (bme.performReading()) {
      String data = "{";
      data += "\"temperature\": " + String(bme.temperature) + ",";
      data += "\"humidity\": " + String(bme.humidity) + ",";
      data += "\"pressure\": " + String(bme.pressure / 100.0) + ",";
      data += "\"gas\": " + String(bme.gas_resistance / 1000.0);
      data += "}";

      // 使用邮箱作为主题发布数据
      String topic = String(email)+ "/ESP_Data";
      client.publish(topic.c_str(), data.c_str());
    } else {
      Serial.println("Failed to perform reading :(");
    }
  }
}

// 函数：连接到MQTT服务器
void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqttUser, mqttPassword)) {
      Serial.println("connected");
      client.subscribe("ESP32/Status");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void setup() {
  // 初始化串口监视器
  Serial.begin(115200);

  // 初始化LED引脚
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW); // 确保LED初始化为关闭状态

  // 初始化Preferences
  preferences.begin("my-app", false);

  // 从Preferences中读取邮箱地址和密码
  String savedEmail = preferences.getString("email", "not set");
  savedEmail.toCharArray(email, 40);
  String savedPassword = preferences.getString("password", "not set");
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
  strcpy(password, custom_password.getValue());
  preferences.putString("email", email);
  preferences.putString("password", password);

  // 初始化BME680传感器并指定I2C引脚
  if (!bme.begin(0x77, &Wire)) {
    Serial.println("Could not find a valid BME680 sensor, check wiring!");
    while (1);
  }
  bme.setTemperatureOversampling(BME680_OS_8X);
  bme.setHumidityOversampling(BME680_OS_2X);
  bme.setPressureOversampling(BME680_OS_4X);
  bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
  bme.setGasHeater(320, 150); // 320°C for 150 ms

  // 设置MQTT服务器和回调函数
  client.setServer(mqttServer, mqttPort);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
}
