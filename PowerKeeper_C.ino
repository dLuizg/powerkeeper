#include <WiFi.h>
#include "EmonLib.h"
#include <Firebase_ESP_Client.h>
#include <time.h>  // --- NOVO ---

EnergyMonitor SCT013;

// ---------- CONFIGURAÇÕES ----------
const char* ssid = "Augusto";
const char* password = "internet100";

// ID fixo do dispositivo
const int idDispositivo = 1;  // --- NOVO ---

// Contador de leituras (leitura 1, leitura 2...)
unsigned long contadorLeitura = 1;  // --- NOVO ---

const int pinSCT = 35;  // Pino ADC do sensor SCT013
#define BOTAO 14        // Botão para alternar tensão

// Pinos dos LEDs
#define LED_220V 25
#define LED_110V 26
#define LED_OFF 27

// ---------- CONFIGURAÇÕES DO FIREBASE ----------
#define FIREBASE_HOST "https://powerkeeper-33345-default-rtdb.firebaseio.com/"
#define FIREBASE_AUTH "PjoVHPjmYMxYnlD6ikJY5gd75s00md1z1ISsvMit"

// ---------- OBJETOS GLOBAIS FIREBASE ----------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Controle de tensão simulada (110 / 220 / 0)
int tensao = 110;
int estadoBotaoAnterior = HIGH;
int contadorTensao = 0;

// Intervalos
unsigned long intervaloLeitura = 1000;
unsigned long ultimoLeitura = 0;

unsigned long intervaloFirebase = 5000;
unsigned long ultimoFirebase = 0;

// Medições
double Irms = 0.0;

// Controle do LED vermelho temporizado
unsigned long tempoDesligamentoVermelho = 0;
bool vermelhoDesligando = false;

// ---------- PROTÓTIPOS ----------
void alternarTensao();
void atualizarLEDs();
void conectarWiFi();
void configurarFirebase();
void enviarDadosFirebase();
String gerarTimestampFormatado();  // --- NOVO ---

// ---------- FUNÇÃO NOVA PARA FORMATAR TIMESTAMP ----------
String gerarTimestampFormatado() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);

  char buffer[25];
  sprintf(buffer, "%02d/%02d/%04d %02d:%02d:%02d",
          t->tm_mday,
          t->tm_mon + 1,
          t->tm_year + 1900,
          t->tm_hour,
          t->tm_min,
          t->tm_sec);

  return String(buffer);
}

// ---------- SETUP ----------
void setup() {
  Serial.begin(115200);

  // Configura sensor
  SCT013.current(pinSCT, 1.45);

  // Botão e LEDs
  pinMode(BOTAO, INPUT_PULLUP);
  pinMode(LED_220V, OUTPUT);
  pinMode(LED_110V, OUTPUT);
  pinMode(LED_OFF, OUTPUT);
  atualizarLEDs();

  // Conecta WiFi
  conectarWiFi();

  // Ajusta relógio NTP para timestamp real
  configTime(-3 * 3600, 0, "pool.ntp.org", "time.nist.gov");  // --- NOVO ---

  // Configura Firebase
  if (WiFi.status() == WL_CONNECTED) {
    configurarFirebase();
  }
}

// ---------- LOOP ----------
void loop() {
  unsigned long agora = millis();

  // Botão
  alternarTensao();

  // Desliga LED vermelho
  if (vermelhoDesligando && (agora - tempoDesligamentoVermelho >= 10000UL)) {
    digitalWrite(LED_OFF, LOW);
    vermelhoDesligando = false;
    Serial.println("LED OFF desligado após 10 segundos");
  }

  // Leitura do sensor
  if (agora - ultimoLeitura >= intervaloLeitura) {
    ultimoLeitura = agora;

    Irms = SCT013.calcIrms(2048);
    if (Irms < 0.16) Irms = 0.0;

    Serial.printf("Tensao: %d V  |  Corrente (Irms): %.3f A\n", tensao, Irms);
  }

  // Envio para Firebase
  if (agora - ultimoFirebase >= intervaloFirebase) {
    ultimoFirebase = agora;

    if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
      enviarDadosFirebase();
    } else if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Tentando enviar, mas WiFi desconectado.");
    }
  }
}

// ---------- FUNÇÕES ----------
void alternarTensao() {
  int estadoBotaoAtual = digitalRead(BOTAO);

  if (estadoBotaoAnterior == HIGH && estadoBotaoAtual == LOW) {
    contadorTensao++;
    if (contadorTensao > 2) contadorTensao = 0;

    switch (contadorTensao) {
      case 0: tensao = 110; break;
      case 1: tensao = 220; break;
      case 2: tensao = 0; break;
    }

    atualizarLEDs();

    Serial.print("Botao pressionado. Nova tensao: ");
    Serial.print(tensao);
    Serial.println(" V");

    if (tensao == 0) {
      vermelhoDesligando = true;
      tempoDesligamentoVermelho = millis();
      Serial.println("LED OFF - aceso por 10s");
    } else {
      vermelhoDesligando = false;
    }

    delay(300);
  }

  estadoBotaoAnterior = estadoBotaoAtual;
}

void atualizarLEDs() {
  digitalWrite(LED_220V, LOW);
  digitalWrite(LED_110V, LOW);
  digitalWrite(LED_OFF, LOW);

  switch (tensao) {
    case 110: digitalWrite(LED_110V, HIGH); break;
    case 220: digitalWrite(LED_220V, HIGH); break;
    case 0:   digitalWrite(LED_OFF, HIGH); break;
  }
}

void conectarWiFi() {
  Serial.print("Conectando no WiFi ");
  Serial.print(ssid);
  WiFi.begin(ssid, password);

  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 10000UL) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi conectado");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFalha ao conectar (protótipo).");
  }
}

void configurarFirebase() {
  Serial.println("Configurando Firebase...");

  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase iniciado.");
}

void enviarDadosFirebase() {
  Serial.print("Registrando leitura no Firebase... ");

  // Formato desejado: leitura 1, leitura 2, leitura 3...
  String path = "/leituras/leitura " + String(contadorLeitura++);

  FirebaseJson json;
  json.set("tensao", tensao);
  json.set("corrente", Irms);
  json.set("idDispositivo", idDispositivo);
  json.set("token", "synatec2025");  // Regra de segurança
  json.set("timestamp", gerarTimestampFormatado());  // TIMESTAMP REAL

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("Sucesso!");
  } else {
    Serial.println("Falha.");
    Serial.println("Razao: " + fbdo.errorReason());
  }
}
