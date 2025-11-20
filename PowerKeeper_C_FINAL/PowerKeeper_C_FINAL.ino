#include <WiFi.h>
#include "EmonLib.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

// ---------------------- CONFIGURAÇÕES ----------------------
EnergyMonitor SCT013;

const char* ssid = "Augusto";
const char* password = "internet100";

const int idDispositivo = 1;
const int pinSCT = 35;

#define BOTAO 14
#define LED_220V 25
#define LED_127V 26
#define LED_OFF 27

// ---------------------- FIREBASE ----------------------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

#define FIREBASE_HOST "https://powerkeeper-synatec-default-rtdb.firebaseio.com/"
#define FIREBASE_AUTH "gNcMVY25PGjzd1If4GX7OZiLENZsnxehj1JYmaRv"

// ----------------------  VARIÁVEIS ----------------------
int tensao = 127;
int estadoBotaoAnterior = HIGH;
int contadorModo = 0;

unsigned long ultimoLeitura = 0;
unsigned long ultimoFirebase = 0;

double Irms = 0.0;
double energia_Wh = 0.0;
double consumoAtual_kWh = 0.0;

unsigned long long ultimoTempoMicro = 0;
unsigned long contadorLeitura = 1;

bool ledVermelhoTimer = false;
unsigned long timerVermelho = 0;

int diaAtual = -1;
String ultimaDataFechada = "";

// ---------------------- PROTÓTIPOS ----------------------
String gerarTimestampISO();
String getDataHoje();
void conectarWiFi();
void alternarTensao();
void atualizarLEDs();
void atualizarEnergia();
void enviarDadosFirebase();
void verificarViradaDia();
void fechamentoDiario(double consumo);
void fechamentoRetroativo();

// ---------------------- TIMESTAMP ----------------------

String gerarTimestampISO() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);
  char buffer[25];

  sprintf(buffer, "%04d-%02d-%02d %02d:%02d:%02d",
          t->tm_year + 1900,
          t->tm_mon + 1,
          t->tm_mday,
          t->tm_hour,
          t->tm_min,
          t->tm_sec);

  return String(buffer);
}

String getDataHoje() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);
  char buffer[12];

  sprintf(buffer, "%04d-%02d-%02d",
          t->tm_year + 1900,
          t->tm_mon + 1,
          t->tm_mday);

  return String(buffer);
}

// ---------------------- SETUP ----------------------

void setup() {
  Serial.begin(115200);
  delay(100);

  SCT013.current(pinSCT, 1.45);

  pinMode(BOTAO, INPUT_PULLUP);
  pinMode(LED_220V, OUTPUT);
  pinMode(LED_127V, OUTPUT);
  pinMode(LED_OFF, OUTPUT);

  atualizarLEDs();

  conectarWiFi();

  configTime(-3 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  delay(1500);

  time_t now = time(nullptr);
  struct tm* t = localtime(&now);
  diaAtual = t->tm_mday;

  ultimoTempoMicro = micros();

  if (WiFi.status() == WL_CONNECTED) {
    config.database_url = FIREBASE_HOST;
    config.signer.tokens.legacy_token = FIREBASE_AUTH;

    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);

    Serial.println("Firebase conectado!");

    fechamentoRetroativo();
  }
}

void conectarWiFi() {
  Serial.println("\nConectando ao Wi-Fi...");
  WiFi.begin(ssid, password);

  int tentativas = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    tentativas++;

    if (tentativas > 60) {  // 30 segundos
      Serial.println("\nFalha ao conectar. Reiniciando ESP...");
      ESP.restart();
    }
  }

  Serial.println("\nWi-Fi conectado!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

// ---------------------- LOOP ----------------------

void loop() {
  unsigned long agora = millis();

  alternarTensao();
  verificarViradaDia();

  if (ledVermelhoTimer && agora - timerVermelho >= 10000) {
    digitalWrite(LED_OFF, LOW);
    ledVermelhoTimer = false;
  }

  if (agora - ultimoLeitura >= 1000) {
    ultimoLeitura = agora;
    atualizarEnergia();
  }

  if (agora - ultimoFirebase >= 5000) {
    ultimoFirebase = agora;

    if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
      enviarDadosFirebase();
    }
  }
}

// ---------------------- FUNÇÕES DE LÓGICA ----------------------

void alternarTensao() {
  int estado = digitalRead(BOTAO);

  if (estadoBotaoAnterior == HIGH && estado == LOW) {
    contadorModo++;
    if (contadorModo > 2) contadorModo = 0;

    if (contadorModo == 0) tensao = 127;
    if (contadorModo == 1) tensao = 220;
    if (contadorModo == 2) tensao = 0;

    atualizarLEDs();

    if (tensao == 0) {
      ledVermelhoTimer = true;
      timerVermelho = millis();
    } else {
      ledVermelhoTimer = false;
      digitalWrite(LED_OFF, LOW);
    }

    Serial.printf("Tensão alterada para: %d V\n", tensao);
    delay(250);
  }

  estadoBotaoAnterior = estado;
}

void atualizarLEDs() {
  digitalWrite(LED_220V, LOW);
  digitalWrite(LED_127V, LOW);
  digitalWrite(LED_OFF, LOW);

  if (tensao == 127) digitalWrite(LED_127V, HIGH);
  else if (tensao == 220) digitalWrite(LED_220V, HIGH);
  else digitalWrite(LED_OFF, HIGH);
}

void atualizarEnergia() {
  unsigned long long agoraMicro = micros();
  unsigned long long delta = agoraMicro - ultimoTempoMicro;
  ultimoTempoMicro = agoraMicro;

  Irms = SCT013.calcIrms(2048);
  if (Irms < 0.16) Irms = 0;

  double potencia = Irms * tensao;

  if (potencia > 0) {
    energia_Wh += (potencia * (delta / 3600000000.0));
    consumoAtual_kWh = energia_Wh / 1000.0;
  }

  Serial.printf("Tensao: %d V | Irms: %.3f A | P: %.2f W | Hoje: %.6f kWh\n",
                tensao, Irms, potencia, consumoAtual_kWh);
}

// ---------------------- ENVIO PARA O FIREBASE ----------------------

void enviarDadosFirebase() {
  FirebaseJson json;

  json.set("tensao", tensao);
  json.set("corrente", Irms);
  json.set("potencia", Irms * tensao);
  json.set("consumoAtual_kWh", consumoAtual_kWh);
  json.set("idDispositivo", idDispositivo);
  json.set("timestamp", gerarTimestampISO());

  String path = "/leituras/leitura_" + String(contadorLeitura++);

  Serial.println("Enviando para: " + path);

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("OK!");
  } else {
    Serial.println("ERRO: " + fbdo.errorReason());
  }

  Firebase.RTDB.setJSON(&fbdo, "/ultima_leitura", &json);
}

// ---------------------- FECHAMENTO DIÁRIO ----------------------

void verificarViradaDia() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);

  if (t->tm_mday != diaAtual) {
    fechamentoDiario(consumoAtual_kWh);

    consumoAtual_kWh = 0;
    energia_Wh = 0;

    diaAtual = t->tm_mday;

    Serial.println("---- NOVO DIA ----");
  }
}

void fechamentoDiario(double consumo) {
  time_t agora = time(nullptr);
  struct tm ontem = *localtime(&agora);
  ontem.tm_mday -= 1;
  mktime(&ontem);

  char dataBuf[12];
  sprintf(dataBuf, "%04d-%02d-%02d",
          ontem.tm_year + 1900,
          ontem.tm_mon + 1,
          ontem.tm_mday);

  String dataOntem = dataBuf;

  if (dataOntem == ultimaDataFechada) return;

  FirebaseJson json;
  json.set("consumo_kWh", consumo);
  json.set("idDispositivo", idDispositivo);
  json.set("timestamp", gerarTimestampISO());

  String path = "/consumos_diarios/" + dataOntem;

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    ultimaDataFechada = dataOntem;
    Firebase.RTDB.setString(&fbdo, "/ultimo_fechamento/data", dataOntem);
  }
}

void fechamentoRetroativo() {
  if (Firebase.RTDB.getString(&fbdo, "/ultimo_fechamento/data")) {
    ultimaDataFechada = fbdo.stringData();
  }

  time_t agora = time(nullptr);
  struct tm ontem = *localtime(&agora);
  ontem.tm_mday -= 1;
  mktime(&ontem);

  char buf[12];
  sprintf(buf, "%04d-%02d-%02d",
          ontem.tm_year + 1900,
          ontem.tm_mon + 1,
          ontem.tm_mday);

  if (String(buf) != ultimaDataFechada) {
    fechamentoDiario(consumoAtual_kWh);
  }
}
