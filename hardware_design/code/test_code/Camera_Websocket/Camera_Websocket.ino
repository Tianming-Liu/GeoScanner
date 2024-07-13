#include <WiFi.h>
#include <WiFiManager.h>
#include <Preferences.h>
#include <WiFiClient.h>
#include <PubSubClient.h>
#include <WebSocketsServer.h>
#include <ESPAsyncWebServer.h>
#include "esp_camera.h"
#include "base64.h"

// WiFiManager对象
WiFiManager wifiManager;

// 创建Preferences对象
Preferences preferences;

// 定义LED引脚
const int ledPin = 2;

// 定义WiFi客户端和MQTT客户端
WiFiClient espClient;
PubSubClient client(espClient);

// WebSocket服务器
WebSocketsServer webSocket(81);
AsyncWebServer server(80);

// MQTT配置
const char* mqttServer = "35.178.35.159";
const int mqttPort = 1884;
const char* mqttUser = "tianming_liu";
const char* mqttPassword = "@BQQMGV3de#nDkZ";

// 定义全局变量来保存邮箱地址和密码
char email[40];
char password[40];

// 摄像头引脚配置
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

void callback(char* topic, byte* payload, unsigned int length) {
  // MQTT回调函数
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqttUser, mqttPassword)) {
      Serial.println("connected");
      // 订阅必要的主题
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA;
  config.jpeg_quality = 10;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }
}

void sendImageToWebSocket() {
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    return;
  }

  String encodedImage = base64::encode(fb->buf, fb->len);
  webSocket.broadcastTXT(encodedImage);
  esp_camera_fb_return(fb);
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      Serial.printf("[%u] Disconnected!\n", num);
      break;
    case WStype_CONNECTED:
      Serial.printf("[%u] Connected!\n", num);
      break;
    case WStype_TEXT:
      Serial.printf("[%u] Text: %s\n", num, payload);
      break;
    case WStype_BIN:
      Serial.printf("[%u] Binary data received\n", num);
      break;
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

    // 清除之前保存的WiFi配置
    wifiManager.resetSettings();

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

        // 连接上热点后，将IP地址发布到MQTT服务器
        String ipTopic = String(email) + "/ESP32/IP";
        String ipAddress = WiFi.localIP().toString();
        client.publish(ipTopic.c_str(), ipAddress.c_str());
    }

    // 保存邮箱地址和密码
    strcpy(email, custom_email.getValue());
    strcpy(password, custom_password.getValue());
    preferences.putString("email", email);
    preferences.putString("password", password);

    // 初始化摄像头
    initCamera();

    // 设置MQTT服务器和回调函数
    client.setServer(mqttServer, mqttPort);
    client.setCallback(callback);

    // 初始化WebSocket服务器
    webSocket.begin();
    webSocket.onEvent(webSocketEvent);

    // 初始化HTTP服务器
    server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
        String html = "<html><body><img src=\"\" id=\"image\"/></body>";
        html += "<script>var ws=new WebSocket('ws://' + window.location.hostname + ':81/');";
        html += "ws.onmessage=function(event){document.getElementById('image').src='data:image/jpg;base64,'+event.data;};</script>";
        html += "</html>";
        request->send(200, "text/html", html);
    });

    server.on("/image", HTTP_GET, [](AsyncWebServerRequest *request){
        camera_fb_t *fb = NULL;
        fb = esp_camera_fb_get();

        if (fb) {
            String encodedImage = base64::encode(fb->buf, fb->len);
            webSocket.broadcastTXT(encodedImage);
            esp_camera_fb_return(fb);
        }

        request->send(200, "text/plain", "OK");
    });

    server.begin();
}

void loop() {
    if (!client.connected()) {
        reconnect();
    }
    client.loop();
    webSocket.loop();

    // 每隔5秒发送一次图像数据
    static unsigned long lastImageSent = 0;
    if (millis() - lastImageSent > 2000) {
        lastImageSent = millis();
        sendImageToWebSocket();
    }
}
