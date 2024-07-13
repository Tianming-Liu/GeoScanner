#include <WiFi.h>
#include "esp_camera.h"

// WiFi Config
const char *ssid = "wifi_ssid";
const char *password = "wifi_password";

// AWS Server Config
const char* awsServer = "35.178.35.159";
const int awsPort = 5001;

// LED Pin
const int ledPin = 2;

// WiFi Client
WiFiClient client;

// Camera Config
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

const int maxcache = 10000;

// Init Camera
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
    config.frame_size = FRAMESIZE_VGA;
    config.pixel_format = PIXFORMAT_JPEG;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    config.jpeg_quality = 8;
    config.fb_count = 1;

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed with error 0x%x", err);
        return;
    }
}

// Upload image to AWS server
void uploadImage() {
    camera_fb_t * fb = esp_camera_fb_get();
    if (!fb) {
        Serial.println("Camera capture failed");
        return;
    }

    if (!client.connect(awsServer, awsPort)) {
        Serial.println("Connection to AWS server failed");
        return;
    }

    client.println("POST /upload HTTP/1.1");
    client.println("Host: 35.178.35.159");
    client.println("Content-Type: application/octet-stream");
    client.println("Connection: keep-alive");

    // Send image via chunks
    uint8_t * buf = fb->buf;
    int leng = fb->len;
    int timess = leng / maxcache;
    int extra = leng % maxcache;
    Serial.print("Total image length: ");
    Serial.println(fb->len);

    for (int j = 0; j < timess; j++) {
        if (j == 0) {
            client.print("Frame Begin");
        }
        client.write(buf, maxcache);
        buf += maxcache;
        Serial.print("Chunk ");
        Serial.print(j + 1);
        Serial.print(" of ");
        Serial.print(timess);
        Serial.println(" sent");
    }
    client.write(buf, extra);
    client.print("Frame Over");

    Serial.print("Last chunk length: ");
    Serial.println(extra);

    Serial.print("Image uploaded, length: ");
    Serial.println(fb->len);

    esp_camera_fb_return(fb);

    while (client.connected() || client.available()) {
        if (client.available()) {
            String line = client.readStringUntil('\n');
            Serial.println(line);
        }
    }
}

void setup() {
    // Initialize Serial
    Serial.begin(115200);

    // Initialize LED
    pinMode(ledPin, OUTPUT);
    digitalWrite(ledPin, LOW);

    // Connect to WiFi
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("WiFi connected");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    digitalWrite(ledPin, HIGH); // High means connected

    initCamera();
}

void loop() {
    // Upload image every 2 seconds
    static unsigned long lastUploadTime = 0;
    unsigned long currentMillis = millis();
    if (currentMillis - lastUploadTime >= 2000) {
        lastUploadTime = currentMillis;
        uploadImage();
    }
}
