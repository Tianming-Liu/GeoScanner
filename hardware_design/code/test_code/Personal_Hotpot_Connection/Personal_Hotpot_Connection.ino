#include <WiFi.h>
#include <WiFiManager.h>
#include <Preferences.h>

// 创建Preferences对象
Preferences preferences;

// 定义LED引脚
const int ledPin = 2;

// 定义一个全局变量来保存邮箱地址
char email[40];

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

void setup() {
  // 初始化串口监视器
  Serial.begin(115200);

  // 初始化LED引脚
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW); // 确保LED初始化为关闭状态

  // 初始化Preferences
  preferences.begin("my-app", false);

  // 从Preferences中读取邮箱地址
  String savedEmail = preferences.getString("email", "not set");
  savedEmail.toCharArray(email, 40);
  Serial.println("Saved email: " + savedEmail);

  // 创建WiFiManager对象
  WiFiManager wifiManager;

  // 自定义参数（邮箱）
  WiFiManagerParameter custom_email("email", "Email", email, 40);

  // 添加自定义参数到WiFiManager
  wifiManager.addParameter(&custom_email);

  // 设置保存参数的回调函数
  wifiManager.setSaveConfigCallback([]() {
    Serial.println("Saving Email...");
    preferences.putString("email", email);
    Serial.println("Email saved: " + String(email));
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

  // 保存邮箱地址
  strcpy(email, custom_email.getValue());
  preferences.putString("email", email);
}

void loop() {
  // 检查WiFi连接状态并更新LED模式
  if (WiFi.status() != WL_CONNECTED) {
    setLEDMode(false); // 未连接或等待配置（闪烁）
  } else {
    setLEDMode(true); // 已连接（常亮）
  }

  delay(100); // 确保主循环不占用太多CPU时间
}
