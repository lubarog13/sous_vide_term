#include <LiquidCrystal_I2C.h>
#include <GyverDS18.h>
#include <ezButton.h>
#include <BluetoothSerial.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
#include <OneWire.h> // DS18B20 
//ESP 32 version
// Переменные для хранения температуры
float currentTemperature = 20.0;
float targetTemperature = 20.0;
float temperatureOffset = 0.5;
#define TEMPERATURE_MIN 0
#define TEMPERATURE_MAX 100
#define TEMPERATURE_STEP 0.5
#define TEMPERATURE_OFFSET_STEP 0.5
#define TEMPERATURE_OFFSET_MIN 0
#define TEMPERATURE_OFFSET_MAX 99
#define MOT_PIN1 32
#define MOT_PIN2 33
#define TIMER_BTN_PIN 14
#define ENC_CLK_PIN 27   // interrupt INT0
#define ENC_DT_PIN 26
#define ENC_SW_PIN 25
#define INC_BTN 12
#define DEC_BTN 13
#define DS18B20_PIN 4
#define PIN_RELAY 19
#define BUZZER 5
#define LED_NORMAL_PIN 32
#define LED_ALARM_PIN 33
#define LED_TIMER_RUNNING_PIN 18
#define TEMP_UPDATE_TIME 5000
#define TMR_DEB 100
#define TMR_ENC_DEB 500
#define TIMER_MINUTES_MAX 1440
#define TIMER_MINUTES_MIN 0

BluetoothSerial ESP_BT; 

#define OFFSET_STEP 5
#define DIRECTION_CW  0   // clockwise direction
#define DIRECTION_CCW 1  

int timeMinutes = 0;
bool shakerEnabled = false;
bool shakerRunning = false;
bool CLK_state = false;
int pDTState = 0;
int pSWState = 0;
int swState =0;
bool cState = false;
bool timerRunning = false;
bool timerFinishedBeeped = false;
uint32_t timerStartedAtMs = 0;
int timerStartMinutes = 0;
long lastUpdateTime = 0;
String data = "";
int direction = DIRECTION_CW;
uint32_t debounceTime = 0;
ezButton incBtn(INC_BTN);
ezButton decBtn(DEC_BTN);


GyverDS18Single ds(DS18B20_PIN);  // пин
ezButton button(ENC_CLK_PIN);
ezButton timerBtn(TIMER_BTN_PIN);
void printPadded(int val, uint8_t fieldWidth, String prefix = " ") {
  char buf[12];
  snprintf(buf, sizeof(buf), "%ld", (long)val);
  uint8_t len = strlen(buf);
  while (len < (uint8_t)fieldWidth) {
    lcd.print(prefix);
    len++;
  }
  lcd.print(buf);
}

void printPadded(float val, uint8_t fieldWidth, String prefix = " ") {
  char buf[16];
  dtostrf((double)val, 0, 1, buf);
  char* p = buf;
  while (*p == ' ') {
    p++;
  }
  uint8_t len = strlen(p);
  while (len < (uint8_t)fieldWidth) {
    lcd.print(prefix);
    len++;
  }
  lcd.print(p);
}

void printTimerHHMM(int totalMinutes) {
  int hours = totalMinutes / 60;
  int minutes = totalMinutes % 60;
  printPadded(hours, 2, "0");
  lcd.print(':');
  printPadded(minutes, 2, "0");
}

void handleEncoder() {

  // read the current state of the rotary encoder's CLK pin
  swState = digitalRead(ENC_SW_PIN);
  static uint32_t tmr = 0;
  if (!button.getState()) {
  Serial.println("swState: " + String(swState));
  Serial.println("pSWState: " + String(pSWState));

  }
  // If the state of CLK is changed, then pulse occurred
  // React to only the rising edge (from LOW to HIGH) to avoid double count
  
  if (swState != pSWState) {
    // if the DT state is HIGH
    // the encoder is rotating in counter-clockwise direction => decrease the counter
    tmr = millis();
    int delta = 0;
    // if (digitalRead(ENC_DT_PIN) != swState ) {
    //   delta = OFFSET_STEP;
    //   direction = DIRECTION_CCW;
    // } else {
    //   // the encoder is rotating in clockwise direction => increase the counter
    //   delta = -OFFSET_STEP;
    //   direction = DIRECTION_CW;
    // }
    
    if (button.getState() && digitalRead(ENC_DT_PIN) == swState) {
      delta = OFFSET_STEP / 2 + millis()%2;
    } else if (!button.getState() && digitalRead(ENC_DT_PIN) != swState) {
      delta = -OFFSET_STEP;
    }
    Serial.print("Rotary Encoder:: direction: ");
    if (direction == DIRECTION_CW)
      Serial.print("Clockwise");
    else
      Serial.print("Counter-clockwise");

    Serial.print(" - count: ");
    if (!timerRunning) {
      timeMinutes += delta;
      if (timeMinutes < TIMER_MINUTES_MIN) {
        timeMinutes = TIMER_MINUTES_MAX;
      }
      if (timeMinutes > TIMER_MINUTES_MAX) {
        timeMinutes = TIMER_MINUTES_MIN;
      }
    }
    Serial.println(timeMinutes);
  }

  // save last CLK state
  pSWState = swState;
}

void runTimer() {
  if (!timerRunning) {
    digitalWrite(LED_TIMER_RUNNING_PIN, LOW);
    digitalWrite(LED_ALARM_PIN, LOW);
    digitalWrite(LED_NORMAL_PIN, LOW);
    return;
  }
  digitalWrite(LED_TIMER_RUNNING_PIN, HIGH);
  uint32_t elapsedMinutes = (millis() - timerStartedAtMs) / 60000;
  int remaining = timerStartMinutes - (int)elapsedMinutes;

  if (remaining <= 0) {
    timeMinutes = 0;
    timerRunning = false;
    shakerRunning = false;
    // digitalWrite(PIN_RELAY, LOW);
    digitalWrite(LED_NORMAL_PIN, LOW);
    digitalWrite(LED_ALARM_PIN, LOW);
    if (!timerFinishedBeeped) {
      noTone(BUZZER);
      tone(BUZZER, 1000, 500);
      timerFinishedBeeped = true;
    }
  } else {
    timeMinutes = remaining;
  }
}

void toggleTimerFromButton() {
  if (!timerRunning) {
    if (timeMinutes <= 0) {
      return;
    }
    timerStartMinutes = timeMinutes;
    timerStartedAtMs = millis();
    timerRunning = true;
    // timerFinishedBeeped = false;
    // noTone(BUZZER);
    // tone(BUZZER, 1000, 500);
    // Serial.println("Tr:1");
  } else {
    timerRunning = false;
    timerFinishedBeeped = false;
    shakerRunning = false;
    noTone(BUZZER);
    Serial.println("Tr:0");
  }
}

void handleProgramChange(const String& data) {
  if (data.startsWith("P:")) {
    String program = data.substring(2);
    // Note: Arduino String does not have split method or array-return. We'll manually parse.
    int idx1 = program.indexOf(';');
    int idx2 = program.indexOf(';', idx1 + 1);
    int idx3 = program.indexOf(';', idx2 + 1);

    if (idx1 < 0 || idx2 < 0 || idx3 < 0) {
      return;
    }

    String strTargetTemp = program.substring(0, idx1);
    String strTempOffset = program.substring(idx1 + 1, idx2);
    String strTimeMins = program.substring(idx2 + 1, idx3);
    String strShaker = program.substring(idx3 + 1);
    targetTemperature = strTargetTemp.toFloat();
    temperatureOffset = strTempOffset.toFloat();
    timeMinutes = strTimeMins.toInt();
    shakerEnabled = strShaker.toInt() == 1;
    shakerRunning = false;
    timerRunning = false;
    timerFinishedBeeped = false;
  }
}

void handleTimerCommands(const String& data) {
  if (data.startsWith("M:")) {
    int value = data.substring(2).toInt();
    if (value < 0) value = 0;
    timeMinutes = value;
    timerRunning = false;
    timerFinishedBeeped = false;
  } else if (data == "START") {
    if (!timerRunning && timeMinutes > 0) {
      timerStartMinutes = timeMinutes;
      timerStartedAtMs = millis();
      timerRunning = true;
      timerFinishedBeeped = false;
      noTone(BUZZER);
      tone(BUZZER, 500, 500);
    }
  } else if (data == "STOP") {
    timerRunning = false;
    timerFinishedBeeped = false;
    shakerRunning = false;
    // digitalWrite(PIN_RELAY, LOW);
    noTone(BUZZER);
  }
}

void checkTemperature() {

  if (!ds.tick())
  {
    lastUpdateTime = millis();
    static bool prevState = false;
    currentTemperature = ds.getTemp(); // Ensure currentTemperature is set as float value
    sendTemperatureToSerial();
    if (!timerRunning) { return; }
    if (currentTemperature >= targetTemperature - temperatureOffset && currentTemperature <= targetTemperature + temperatureOffset) {
      digitalWrite(LED_NORMAL_PIN, HIGH);
      digitalWrite(LED_ALARM_PIN, LOW);
      if (!prevState && timerRunning) {
        noTone(BUZZER);
        tone(BUZZER, 500, 500);
        prevState = true;
      }
      // digitalWrite(PIN_RELAY, LOW);
    } else {
      digitalWrite(LED_NORMAL_PIN, LOW);
      digitalWrite(LED_ALARM_PIN, HIGH);
      if (prevState && timerRunning) {
        noTone(BUZZER);
        tone(BUZZER, 1000);
        prevState = false;
      }
      if (currentTemperature < targetTemperature + temperatureOffset) {
        // digitalWrite(PIN_RELAY, HIGH); // Включаем реле
      } else {
        // digitalWrite(PIN_RELAY, LOW); // Выключаем реле
      }
    }
  }
}

void sendTemperatureToSerial() {
  Serial.println("Sending temperature to serial:" + String(ESP_BT.available()));
  // if (ESP_BT.available()) {
    ESP_BT.println("Tr:" + String(timerRunning));
    ESP_BT.println("Ct:" + String(currentTemperature));
    ESP_BT.println("O:" + String(temperatureOffset));
    ESP_BT.println("Tt:" + String(targetTemperature));
    ESP_BT.println("M:" + String(timeMinutes));
    ESP_BT.println("S:" + String(shakerEnabled));
  // }
}

void setup() {
  Serial.begin(9600);
  ESP_BT.begin("SmartThermostat"); //Name of your Bluetooth Signal (имя нашего Bluetooth соединения)
  Serial.println("Bluetooth Device is Ready to Pair");
  // put your setup code here, to run once:

   lcd.init();
   lcd.backlight();
   lcd.clear();
      // Serial.println("S1:" + String(shakerEnabled));
      pinMode(LED_NORMAL_PIN, OUTPUT);

      pinMode(ENC_CLK_PIN, INPUT_PULLUP);
      pinMode(ENC_DT_PIN, INPUT_PULLUP);
      pinMode(ENC_SW_PIN, INPUT_PULLUP);
      pDTState = digitalRead(ENC_DT_PIN);
      pSWState = digitalRead(ENC_SW_PIN);
      button.setDebounceTime(100);  // set debounce time to 50 milliseconds
    
      // read the initial state of the rotary encoder's CLK pin
      cState = digitalRead(ENC_CLK_PIN);
  pinMode(INC_BTN, INPUT_PULLUP);
  pinMode(DEC_BTN, INPUT_PULLUP);
  pinMode(TIMER_BTN_PIN, INPUT_PULLUP);
  // incBtn.setDebounceTime(100);
  // decBtn.setDebounceTime(100);
  pinMode(BUZZER, OUTPUT);
   pinMode(LED_ALARM_PIN, OUTPUT);
  // pinMode(PIN_RELAY, OUTPUT);
  // pinMode(MOT_PIN1, OUTPUT);
  // pinMode(MOT_PIN2, OUTPUT);
   pinMode(LED_TIMER_RUNNING_PIN, OUTPUT);
  ds.setResolution(12);
  ds.setPeriod(TEMP_UPDATE_TIME);

}

void loop() {
  button.loop();
    handleEncoder();
  //  digitalWrite(LED_NORMAL_PIN, HIGH);
  //  digitalWrite(LED_ALARM_PIN, HIGH);
  //  digitalWrite(LED_TIMER_RUNNING_PIN, HIGH);
  
   lcd.setCursor(0, 0);
   lcd.print("TT:");
   printPadded(targetTemperature, 4);
   lcd.print(" Of:");
   printPadded(temperatureOffset, 3);
   lcd.setCursor(0, 1);
   lcd.print("TC:");
   printPadded(currentTemperature, 4);
   lcd.print(" ");

   printTimerHHMM(timeMinutes);
   String data = "";
  if (ESP_BT.available()) {
    data = ESP_BT.readStringUntil('\n');
    if (data.startsWith("Tt:")) {
      targetTemperature = data.substring(3).toFloat();
    }
    if (data.startsWith("O:")) {
      temperatureOffset = data.substring(2).toFloat();
    }
    if (data.startsWith("S:")) {
      shakerEnabled = data.substring(2).toInt() == 1;
    }
    handleTimerCommands(data);
    handleProgramChange(data);
  }
  static bool piState = false, pdState = false, pOffsetIncState = false, pOffsetDecState = false;
  static uint32_t tmr1, tmr2, tmr3, tmr4;
  // bool iState = digitalRead(INC_BTN);
  // bool dState = digitalRead(DEC_BTN);
  // Serial.println("iState: " + String(iState));
  // Serial.println("dState: " + String(dState));
  // if (iState != piState && millis() - tmr1 >= TMR_DEB) {
  //     piState = iState;
  //     tmr1 = millis();
  //       targetTemperature += TEMPERATURE_STEP;
  //  if (targetTemperature > TEMPERATURE_MAX) {
  //   targetTemperature = TEMPERATURE_MIN;
  //  }
  // }

  // if (dState != pdState && millis() - tmr2 >= TMR_DEB) {
  //    pdState = dState;
  //    tmr2 = millis();
  //      targetTemperature -= TEMPERATURE_STEP; 
  //     if (targetTemperature < TEMPERATURE_MIN) {
  //        targetTemperature = TEMPERATURE_MAX;
  //    }
  // }

  incBtn.loop();
  decBtn.loop();
  timerBtn.loop();
  int btnState = incBtn.isPressed();
  if (btnState) {
    targetTemperature += TEMPERATURE_STEP;
    Serial.println("incBtn pressed");

  }
  btnState = decBtn.isPressed();
  if (btnState) {
    targetTemperature -= TEMPERATURE_STEP;
    Serial.println("decBtn pressed");
  }
  btnState = timerBtn.isPressed();
  if (btnState) {
    toggleTimerFromButton();
    Serial.println("timerBtn pressed");
  }
  // if (shakerEnabled && !shakerRunning) {
  //   shakerRunning = true;
  //   digitalWrite(MOT_PIN1, HIGH);
  //   digitalWrite(MOT_PIN2, HIGH);
  // }
  // if (!shakerEnabled && shakerRunning) {
  //   shakerRunning = false;
  //   digitalWrite(MOT_PIN1, LOW);
  //   digitalWrite(MOT_PIN2, LOW);
  // }

  runTimer();
  checkTemperature();
}
