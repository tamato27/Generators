/************************  Include Libraries  *******************/
#include <WiFi.h>
#include <WiFiClient.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Update.h>

#include <ArduinoOTA.h>
#include <PubSubClient.h>

#include <ESP32Servo.h>


/************  Constants won't change. They're used here to set pin numbers  *******************/
// PWM Pins
#define Servo_PWM 2               // Servo Command INPUT Pin (PWM)
// Input Pins
const int GEN_STATE_PIN = 4;      // Gen state INPUT Pin
const int FUEL_VALVE_PIN = 21;     // Fuel valve INPUT Pin  
const int ENDSTOP_LEFT_PIN = 18;  // Left endstop INPUT Pin OpenChoke
const int ENDSTOP_RIGHT_PIN = 32; // Right endstop INPUT Pin CloseChoke
// Output Pins
const int MG995_POWER_PIN = 13;    // Servo power OUTPUT Pin
const int KEY_OFF_PIN = 25;       // Key OFF position OUTPUT Pin
const int KEY_ON_PIN = 26;        // Key ON position  OUTPUT Pin
const int KEY_START_PIN = 27;     // Key START position OUTPUT Pin

/************************  Starter no of retries to use  *******************/
const int RETRY = 1;

/************************  Create Servo object to control a servo  *******************/
Servo MG995;

/************************  variables will change  *******************/
int ENDSTOP_LEFT_STATE = 0;     // variable for reading the endstop status
int ENDSTOP_RIGHT_STATE = 0;    // variable for reading the endstop status
int TURN_CLOCKWISE = 0;         // Turn servo clockwise
int TURN_ANTI_CLOCKWISE = 180;  // Turn Servo anticlocks 
int SERVO_STOP = 90;            // Stop Servo

/************************ Wifi Details/Settings  *******************/
const char* host = "gen-esp32";       // Hostname
const char* ssid = "PlumeMain";       // WiFI Name
const char* password = "F0rtr355!!";  // WiFi Password
IPAddress local_IP(192,168,88,116);   // Local Wifi IP
IPAddress gateway(192,168,88,1);      // Router IP
IPAddress subnet(255,255,255,0);      // Subnet
IPAddress primaryDNS(192,168,88,1);        // DNS
IPAddress secondaryDNS(8,8,8,8);

/************************ MQTT Settings  *******************/
const char* mqtt_USER = "mqtt-user";
const char* mqtt_PASS = "mqtt-password";
const char* mqttTopic = "/GEN/";      // MQTT topic
IPAddress broker(192,168,88,240);   // Address of the MQTT broker
#define CLIENT_ID "GenEsp"          // Client ID to send to the broker 

/************************ Gen Functions  *******************/
void startGen()
{
  /* Start the Gen process */
  int counter = 0;

  // Open Fuel Valve
  Serial.println("Opening Fuel valve");
  digitalWrite(FUEL_VALVE_PIN, LOW);        // Switch Realay to N/O to turn on 12V

  // Open the choke
  Serial.println("Opening the choke....");
  openChoke();

  Serial.println("Key OFF Position on");
  digitalWrite(KEY_OFF_PIN, LOW);          // Relay On
  
  Serial.println("Key ON Position on");
  digitalWrite(KEY_ON_PIN, LOW);          // Relay On

  delay(2000);
  // If Gen is off
  if (digitalRead(GEN_STATE_PIN) == HIGH) {
    while (digitalRead(GEN_STATE_PIN) == HIGH && counter < RETRY) {  // While Gen is off try to start gen twice
      Serial.println("Key START Position on for 2 seconds");
      digitalWrite(KEY_START_PIN, LOW);       // Relay On
      delay(1000);                            // hold for 2 seconds
      digitalWrite(KEY_START_PIN, HIGH);      // Relay Off
      Serial.println("Key START Position off");
      delay(1000);
      counter ++;
    }

    delay(2000);
    // If Gen is on
    if (digitalRead(GEN_STATE_PIN) == LOW) {
      closeChoke();
      Serial.println("The Generator is running"); 
    }
    //else if gen did not start 
    else {
        // Safety Turn all off
        Serial.print("Closing Fuel valve - off: ");
        digitalWrite(FUEL_VALVE_PIN, HIGH);        // Switch Realay to N/C to turn off 12V

        Serial.println("Key OFF Position off");
        digitalWrite(KEY_OFF_PIN, HIGH);          // Relay Off
  
        Serial.println("Key ON Position off");
        digitalWrite(KEY_ON_PIN, HIGH);          // Relay Off
        closeChoke();
        Serial.println("Generator could not start pls check.");
      }
  } 
  
}

/************************ Gen Functions  *******************/
void stopGen()
{
  /* Start the gen stop process */

  if (digitalRead(GEN_STATE_PIN) == LOW)    // Gen is running
  {
     Serial.print("Closing Fuel valve - off: ");
     digitalWrite(FUEL_VALVE_PIN, HIGH);        // Switch Realay to N/C to turn off 12V

     Serial.println("Key OFF Position off");
     digitalWrite(KEY_OFF_PIN, HIGH);          // Relay Off
  
     Serial.println("Key ON Position off");
     digitalWrite(KEY_ON_PIN, HIGH);          // Relay Off
     //closeChoke();
    
  } else
    {
      Serial.print("Closing Fuel valve - off: ");
      digitalWrite(FUEL_VALVE_PIN, HIGH);        // Switch Realay to N/C to turn off 12V

      Serial.println("Key OFF Position off");
      digitalWrite(KEY_OFF_PIN, HIGH);          // Relay Off
  
      Serial.println("Key ON Position off");
      digitalWrite(KEY_ON_PIN, HIGH);          // Relay Off
      //closeChoke();
    }
}

/************************ Choke Functions  *******************/
void openChoke()
{
  /* Turns the sevo clockwise to open position */
  
  digitalWrite(MG995_POWER_PIN, LOW);  //Power the servo
  Serial.println("Powering on the servo, and turning untill endstop reached.");
  
  MG995.attach(Servo_PWM);    // Attach to servo pin (PWM)

  while (digitalRead(ENDSTOP_LEFT_PIN) == HIGH) {   // Endstop not activated
    MG995.write(TURN_ANTI_CLOCKWISE);
    //Serial.println("Opening - Turning servo");
  }

  MG995.write(SERVO_STOP);
  digitalWrite(MG995_POWER_PIN, HIGH);      // Power off servo
  Serial.println("Choke is open, Servo Powering off.");  
}

/************************ Choke Functions  *******************/
void closeChoke()
{
  /* Turns the servo anti clockwise to the closed position */

  digitalWrite(MG995_POWER_PIN, LOW);  // Power the servo
  Serial.println("Powering on the servo, and turning untill endstop reached.");
  MG995.attach(Servo_PWM);
  
  while (digitalRead(ENDSTOP_RIGHT_PIN) == HIGH) {    // Endstop not activated
    MG995.write(TURN_CLOCKWISE);
    //Serial.println("Closing - Turning servo");
  }

  MG995.write(SERVO_STOP);
  digitalWrite(MG995_POWER_PIN, HIGH);  // Turn Servo power off
  Serial.println("Choke is closed, Servo Powering off servo.");  
}

/************************  MQTT Callback Function to process messages *******************/
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  for (int i=0;i<length;i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();

  // Examine only the first character of the message
  if(payload[0] == 49) {               // Message "1" in ASCII (turn outputs ON)
    //digitalWrite(ledPin, HIGH);      // LED is active-low, so this turns it on
    //digitalWrite(relayPin, HIGH);
    startGen();                        // Call Start Gen Function
  } else if(payload[0] == 48) {        // Message "0" in ASCII (turn outputs OFF)
    //digitalWrite(ledPin, LOW);       // LED is active-low, so this turns it off
    //digitalWrite(relayPin, LOW);
    stopGen();  // Call Stop gen Function
  } else {
    Serial.println("Unknown value");
  }
 
}

WiFiClient wificlient;
PubSubClient client(wificlient);

/************ Attempt connection to MQTT broker and subscribe to command topic ************/
void reconnect() {
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    //if (client.connect(CLIENT_ID)) {
    if (client.connect(CLIENT_ID, mqtt_USER, mqtt_PASS)) {  
      Serial.println("connected");
      client.subscribe(mqttTopic);
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

/************************  Default Setup run once Function  *******************/
void setup(void) {
  Serial.begin(115200);

  /* Set up the outputs. LED is active-low */
  
  // Input Pins
  pinMode(GEN_STATE_PIN, INPUT_PULLUP);
  pinMode(ENDSTOP_LEFT_PIN, INPUT_PULLUP);
  pinMode(ENDSTOP_RIGHT_PIN, INPUT_PULLUP);

  // Output Pins
  pinMode(MG995_POWER_PIN, OUTPUT);
  pinMode(FUEL_VALVE_PIN, OUTPUT);
  pinMode(KEY_OFF_PIN, OUTPUT);
  pinMode(KEY_ON_PIN, OUTPUT);
  pinMode(KEY_START_PIN, OUTPUT);
    
  //During Start all Relays should TURN OFF
  digitalWrite(FUEL_VALVE_PIN, HIGH);
  digitalWrite(MG995_POWER_PIN, HIGH);
  digitalWrite(KEY_OFF_PIN, HIGH);
  digitalWrite(KEY_ON_PIN, HIGH);
  digitalWrite(KEY_START_PIN, HIGH);

  Serial.println("Booting");
  // Configures static IP address
  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("STA Failed to configure");
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.println("WiFi begun");
  
  while (WiFi.waitForConnectResult() != WL_CONNECTED) {
    Serial.println("Connection Failed! Rebooting...");
    delay(5000);
    ESP.restart();
  }
  Serial.println("Proceeding");

  // MQTT
  // Port defaults to 8266
  // ArduinoOTA.setPort(8266);

  // Hostname defaults to esp8266-[ChipID]
  // ArduinoOTA.setHostname("myesp8266");

  // No authentication by default
  ArduinoOTA.setPassword((const char *)"730");
 
  ArduinoOTA.onStart([]() {
    Serial.println("Start");
  });
  ArduinoOTA.onEnd([]() {
    Serial.println("\nEnd");
  });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("Error[%u]: ", error);
    if      (error == OTA_AUTH_ERROR   ) Serial.println("Auth Failed");
    else if (error == OTA_BEGIN_ERROR  ) Serial.println("Begin Failed");
    else if (error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
    else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
    else if (error == OTA_END_ERROR    ) Serial.println("End Failed");
  });
  ArduinoOTA.begin();
  Serial.println("Ready");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
 
  /* Prepare MQTT client */
  client.setServer(broker, 1883);
  client.setCallback(callback);
}

/************************  Main Loop Function  *******************/
void loop(void) {
  
  ArduinoOTA.handle();
  
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.print("Connecting to ");
    Serial.print(ssid);
    Serial.println("...");
 
    WiFi.begin(ssid, password);

    if (WiFi.waitForConnectResult() != WL_CONNECTED)
      return;
    Serial.println("WiFi connected");
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      reconnect();
    }
  }
 
  if (client.connected())
  {
    client.loop();
  }
}
