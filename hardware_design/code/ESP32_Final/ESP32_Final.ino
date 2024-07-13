#include <WiFi.h>
#include <WebSocketsServer.h>
#include <esp_camera.h>
#include <esp_timer.h>
#include <img_converters.h>
#include <fb_gfx.h>
#include <soc/soc.h>
#include <soc/rtc_cntl_reg.h>
#include <driver/gpio.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME680.h>
#include <AsyncTCP.h>
#include <Preferences.h>
#include <WiFiManager.h>
#include <ESPmDNS.h>

// Configuration for Camera
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

camera_fb_t * fb = NULL;
size_t _jpg_buf_len = 0;
uint8_t * _jpg_buf = NULL;
uint8_t state = 0;

WebSocketsServer webSocket = WebSocketsServer(81); // WebSocket server on port 81

// I2C pins for BME680 to avoid conflicts
#define BME_SDA 32
#define BME_SCL 33

Adafruit_BME680 bme; // I2C

bool startTransmission = false;

bool cameraInitialized = false;
bool bme680Initialized = false;

// Define LED pins
#define POWER_LED_PIN 12
#define WEBSOCKET_LED_PIN 13

Preferences preferences;

void init_bme680() {
  Serial.println("Initializing BME680 sensor...");

  // Initialize I2C with new pins
  Wire.begin(BME_SDA, BME_SCL);

  // Adding delay to ensure the sensor is ready
  delay(1000);

  if (!bme.begin(0x77, &Wire)) {  // Ensure BME680 is set to use I2C address 0x77
    Serial.println("Could not find a valid BME680 sensor, check wiring!");
    bme680Initialized = false;
  } else {
    bme.setTemperatureOversampling(BME680_OS_8X);
    bme.setHumidityOversampling(BME680_OS_2X);
    bme.setPressureOversampling(BME680_OS_4X);
    bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
    bme.setGasHeater(320, 150); // 320*C for 150 ms

    bme680Initialized = true;
    Serial.println("BME680 sensor initialized.");
  }
}

esp_err_t init_camera() {
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
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // Parameters for image quality and size
  config.frame_size = FRAMESIZE_QVGA; // FRAMESIZE_ + QVGA|CIF|VGA|SVGA|XGA|SXGA|UXGA
  config.jpeg_quality = 20; //10-63 lower number means higher quality
  config.fb_count = 2;

  // Camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x", err);
    cameraInitialized = false;
    return err;
  }
  sensor_t * s = esp_camera_sensor_get();
  s->set_framesize(s, FRAMESIZE_VGA);
  cameraInitialized = true;
  Serial.println("Camera init OK");
  return ESP_OK;
};

void send_bme680_data() {
  if (!bme.performReading()) {
    Serial.println("Failed to perform reading :(");
    return;
  }

  // Convert BME680 data into binary formation
  struct {
    float temperature;
    float humidity;
    float pressure;
    float gas_resistance;
  } bme680_data;

  bme680_data.temperature = bme.temperature;
  bme680_data.humidity = bme.humidity;
  bme680_data.pressure = bme.pressure / 100.0;
  bme680_data.gas_resistance = bme.gas_resistance / 1000.0;

  webSocket.broadcastBIN((const uint8_t*) &bme680_data, sizeof(bme680_data));
  Serial.println("BME680 data sent");
}

void send_camera_data() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    esp_camera_fb_return(fb);
    return;
  }

  webSocket.broadcastBIN((const uint8_t*) fb->buf, fb->len);
  Serial.println("Image sent");
  esp_camera_fb_return(fb);
}

void send_sensor_status() {
  if (cameraInitialized && bme680Initialized) {
    webSocket.broadcastTXT("Both sensors initialized.");
  } else if (!cameraInitialized && !bme680Initialized) {
    webSocket.broadcastTXT("Neither sensor initialized.");
  } else if (!cameraInitialized) {
    webSocket.broadcastTXT("Camera not initialized.");
  } else if (!bme680Initialized) {
    webSocket.broadcastTXT("BME680 not initialized.");
  }
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  Serial.setDebugOutput(true);

  // Initialize LEDs
  pinMode(POWER_LED_PIN, OUTPUT);
  pinMode(WEBSOCKET_LED_PIN, OUTPUT);

  // Turn on the power LED
  digitalWrite(POWER_LED_PIN, HIGH);

  init_camera();
  init_bme680();

  preferences.begin("wifi", false);

  // Create WiFiManager object
  WiFiManager wifiManager;

  // Set callback for entering AP mode
  wifiManager.setAPCallback([](WiFiManager *myWiFiManager) {
    Serial.println("Entered AP mode");
    digitalWrite(WEBSOCKET_LED_PIN, LOW); // Turn off WebSocket LED in AP mode
  });

  // Attempt to connect to saved WiFi credentials, or enter AP mode if not available
  if (!wifiManager.autoConnect("ESP32-Config")) {
    Serial.println("Failed to connect and hit timeout");
    ESP.restart();
  } else {
    Serial.println("Connected to WiFi");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  }

  // Set up mDNS
  if (!MDNS.begin("esp32")) {  // Set mDNS name to get rid of dynanmic ip address
    Serial.println("Error setting up MDNS responder!");
    while (1) {
      delay(1000);
    }
  }
  Serial.println("mDNS responder started");

  webSocket.begin();
  webSocket.onEvent([](uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
    if (type == WStype_CONNECTED) {
      Serial.printf("[%u] Connected!\n", num);
      digitalWrite(WEBSOCKET_LED_PIN, HIGH); // Turn on WebSocket LED
      send_sensor_status(); // Send Sensor Status
    } else if (type == WStype_DISCONNECTED) {
      Serial.printf("[%u] Disconnected!\n", num);
      digitalWrite(WEBSOCKET_LED_PIN, LOW); // Turn off WebSocket LED
    } else if (type == WStype_TEXT) {
      String text = String((char *)payload);
      if (text == "start") {
        startTransmission = true;
        Serial.println("Start transmission command received.");
      } else if (text == "stop") {
        startTransmission = false;
        Serial.println("Stop transmission command received.");
      }
    }
  });
}

void loop() {
  webSocket.loop();

  if (startTransmission) {
    // Send BME680 Data
    send_bme680_data();

    // Send Image Data
    send_camera_data();

    delay(750);  // Data Upload Interval
  }
}
