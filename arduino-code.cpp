#include <IRremote.hpp>

#define IR_PIN 11

// Команды с твоего ИК-пульта (NEC)
#define BTN_1_CMD 0x0C
#define BTN_2_CMD 0x18
#define BTN_3_CMD 0x5E
#define BTN_4_CMD 0x08
#define BTN_5_CMD 0x1C
#define BTN_6_CMD 0x5A

// Пины LED
int ledPins[9] = {2, 3, 4, 5, 6, 7, 8, 9, 10};
bool ledState[9] = {false};

String inputString = "";
bool stringComplete = false;

// ------------------------
// Инициализация
// ------------------------
void setup() {
  Serial.begin(9600);     // HC-05
  IrReceiver.begin(IR_PIN, ENABLE_LED_FEEDBACK);

  for (int i = 0; i < 9; i++) {
    pinMode(ledPins[i], OUTPUT);
    digitalWrite(ledPins[i], LOW);
  }
}

// ------------------------
// Переключение LED
// ------------------------
void toggleLed(int index) {
  ledState[index] = !ledState[index];
  digitalWrite(ledPins[index], ledState[index]);
}

void setLed(int index, bool state) {
  ledState[index] = state;
  digitalWrite(ledPins[index], state);
}

// ------------------------
// Парсер команд Bluetooth
// Формат: LED:<id>:<action>
// <id> — номер 1–9
// <action> — ON, OFF, TOGGLE
// ------------------------
void processCommand(String cmd) {
  cmd.trim();
  if (!cmd.startsWith("LED:")) return;

  // LED:3:TOGGLE
  int first = cmd.indexOf(':');
  int second = cmd.indexOf(':', first + 1);

  int ledId = cmd.substring(first + 1, second).toInt();
  String action = cmd.substring(second + 1);

  if (ledId < 1 || ledId > 9) return;

  int index = ledId - 1;

  if (action == "TOGGLE") {
    toggleLed(index);
  } else if (action == "ON") {
    setLed(index, true);
  } else if (action == "OFF") {
    setLed(index, false);
  }

  Serial.print("ACK:");
  Serial.print(ledId);
  Serial.print(":");
  Serial.println(action);
}

// ------------------------
// Основной цикл
// ------------------------
void loop() {
  
  // ======== IR управление ========
  if (IrReceiver.decode()) {

    if (!(IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT)) {
      uint8_t cmd = IrReceiver.decodedIRData.command;

      switch (cmd) {
        case BTN_1_CMD: toggleLed(0); toggleLed(1); break; // LED 2 и 3
        case BTN_2_CMD: toggleLed(2); toggleLed(3); break; // LED 4 и 5
        case BTN_3_CMD: toggleLed(4); toggleLed(5); break; // LED 6 и 7
        case BTN_4_CMD: toggleLed(6); break;              // LED 8
        case BTN_5_CMD: toggleLed(7); break;              // LED 9
        case BTN_6_CMD: toggleLed(8); break;              // LED 10
      }
    }

    IrReceiver.resume();
  }

  // ======== Bluetooth управление ========
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n') {
      stringComplete = true;
      break;
    }
    inputString += c;
  }

  if (stringComplete) {
    processCommand(inputString);
    inputString = "";
    stringComplete = false;
  }
}
