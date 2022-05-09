/* Include Libraries */
#include <ESP8266WiFi.h> 
#include <PubSubClient.h>
#include <Servo.h>

// constants won't change. They're used here to set pin numbers:
const int MG995_PIN = 1;
const int RIGHT_ENDSTOP_PIN = 2;     // right endstop gpio pin
const int LEFT_ENDSTOP_PIN = 3;     // left endstop gpio pin
const int FUEL_VALVE_PIN = 4;  // vuel valve gpio pin
const int GEN_STATE_PIN = 5;  // Gen state pin

// variables will change:
int RIGHT_ENDSTOP_STATE = 0;         // variable for reading the endstop status
int LEFT_ENDSTOP_STATE = 0;         // variable for reading the endstop status
int CLOCK_WISE = 0; // Turn servo clockwise
int ANTI_CLOCKWISE = 180; // Turn Servo anticlocks
int FUEL_VALVE_RELAY_STATE = 0;

// create servo object to control a servo
Servo MG995;

// Use onboard LED for convenience 
#define LED (2)
// Maximum received message length 
#define MAX_MSG_LEN (128)

// Wifi configuration
const char* ssid = "ID10T";
const char* password = "F0rtr355!";

// MQTT Configuration
// if you have a hostname set for the MQTT server, you can use it here
//const char *serverHostname = "M1.local";
// otherwise you can use an IP address like this
const IPAddress serverIPAddress(172, 16, 0, 4);  // MQQT server ip
// the topic we want to use
const char *topic = "generator/controller";

WiFiClient espClient;
PubSubClient client(espClient);


void setup() 
{
  // put your setup code here, to run once:
  // Configure serial port for debugging
  Serial.begin(115200);
<<<<<<< HEAD

  // LED pin as output
  pinMode(LED, OUTPUT);      
  digitalWrite(LED, HIGH);

  // initialize the endstop pin as an input:
  pinMode(LEFT_ENDSTOP_PIN, INPUT);

=======

  // LED pin as output
  pinMode(LED, OUTPUT);      
  digitalWrite(LED, HIGH);

  // initialize the endstop pin as an input:
  pinMode(LEFT_ENDSTOP_PIN, INPUT);

>>>>>>> 559e279da8f71209b3effc3c916066c3efddd402
  // attaches the servo on GIO to the servo object
  MG995.attach(MG995_PIN);

  // Initialise wifi connection - this will wait until connected
  connectWifi();
  // connect to MQTT server  
  client.setServer(serverIPAddress, 1883);
  client.setCallback(callback);

}

void loop() 
{
  // put your main code here, to run repeatedly:
  if (!client.connected()) 
  {
      connectMQTT();
  }
  
    // this is ESSENTIAL!
    client.loop();
    // idle
    delay(500);
}

// connect to wifi
void connectWifi() 
{
  delay(10);
  // Connecting to a WiFi network
  Serial.printf("\nConnecting to %s\n", ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) 
  {
    delay(250);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.print("WiFi connected on IP address ");
  Serial.println(WiFi.localIP());
}

// connect to MQTT server
void connectMQTT() 
{
  // Wait until we're connected
  while (!client.connected()) 
  {
    // Create a random client ID
    String clientId = "ESP8266-";
    clientId += String(random(0xffff), HEX);
    Serial.printf("MQTT connecting as client %s...\n", clientId.c_str());
    // Attempt to connect
    if (client.connect(clientId.c_str())) 
    {
      Serial.println("MQTT connected");
      // Once connected, publish an announcement...
      client.publish(topic, "hello from ESP8266");
      // ... and resubscribe
      client.subscribe(topic);
    } else 
    {
      Serial.printf("MQTT failed, state %s, retrying...\n", client.state());
      // Wait before retrying
      delay(2500);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) 
{
  // copy payload to a static string
  static char message[MAX_MSG_LEN+1];
  if (length > MAX_MSG_LEN) 
  {
    length = MAX_MSG_LEN;
  }
  
  strncpy(message, (char *)payload, length);
  message[length] = '\0';
  
  Serial.printf("topic %s, message received: %s\n", topic, message);
  // get the gen state
  int gen_state = getGenState();
  
  // decode message
  if (strcmp(message, "low batt") == 0) 
  {
    setLedState(false);
    if (gen_state == LOW)
    {
      // Start the gen process
      startGen();
    }
    
  }
  else if (strcmp(message, "low batt") == 1)
  {
    // check if gen is stopped and check servo position
    stopGen();
  }
}

void setLedState(boolean state) 
{
  // LED logic is inverted, low means on
  digitalWrite(LED, !state);
}

void startGen()
{
  // Start the Gen process
  // get the gen state
  int gen_state = getGenState();
  // check if servo is in home pos
  // read the state of the right endstop value:
  RIGHT_ENDSTOP_STATE = digitalRead(RIGHT_ENDSTOP_PIN);

  if (gen_state == LOW)
  {
    // check if the right endstop is pressed. If it is, the endstop State is HIGH:
    if (RIGHT_ENDSTOP_STATE != HIGH) 
    {
      // if servo is not HIGH turn Servo clockwise:
      MG995.write(CLOCK_WISE); // rotate servo untill endstop state is HIGH
    }

    // Enable relay for Fuel
    digitalWrite(FUEL_VALVE_PIN, HIGH);

    // Start the ignition
    // turn key to start pos
    // if gen state does not change try again to start the gen only try twice
    
  }
  
}
<<<<<<< HEAD

void stopGen()
{
  // Start the gen stop process

  // get the gen state
  int gen_state = getGenState();

=======

void stopGen()
{
  // Start the gen stop process

  // get the gen state
  int gen_state = getGenState();

>>>>>>> 559e279da8f71209b3effc3c916066c3efddd402
  if (gen_state == HIGH)
  {
    // Disable relay for Fuel
    digitalWrite(FUEL_VALVE_PIN, LOW);

    // turn key to off pos and then back to on
    
    // Move choke back to home pos
    // read the state of the right endstop value:
    LEFT_ENDSTOP_STATE = digitalRead(LEFT_ENDSTOP_PIN);

    // check if the right endstop is pressed. If it is, the endstop State is HIGH:
    if (LEFT_ENDSTOP_STATE != HIGH) 
    {
      // if servo is not HIGH turn Servo clockwise:
      MG995.write(ANTI_CLOCKWISE); // rotate servo untill endstop state is HIGH
    }
  }
  
<<<<<<< HEAD
=======
}

int getGenState()
{
  // get the gen state
  int genstate = digitalRead(GEN_STATE_PIN);
  
  return genstate; 
>>>>>>> 559e279da8f71209b3effc3c916066c3efddd402
}

int getGenState()
{
  // get the gen state
  int genstate = digitalRead(GEN_STATE_PIN);
  
  return genstate; 
}