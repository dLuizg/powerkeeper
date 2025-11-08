#include <WiFi.h>
#include "EmonLib.h"

EnergyMonitor SCT013;

// ---------- CONFIGURAÇÕES ----------
const char* ssid = "Luiz";
const char* password = "f845eeab";

const int pinSCT = 35;    // Pino ADC do sensor SCT013
#define BOTAO 14          // Botão para alternar tensão

// Pinos dos LEDs
#define LED_220V 25
#define LED_110V 26
#define LED_OFF 27

// Controle de tensão simulada (110 / 220 / 0)
int tensao = 110;
int estadoBotaoAnterior = HIGH;
int contadorTensao = 0;

// Intervalo de leitura / exibição (ms)
unsigned long intervaloLeitura = 1000;
unsigned long ultimoLeitura = 0;

// Medições
double Irms = 0.0;

// Controle do LED vermelho temporizado (modo OFF)
unsigned long tempoDesligamentoVermelho = 0;
bool vermelhoDesligando = false;

// ---------- PROTÓTIPOS ----------
void alternarTensao();
void atualizarLEDs();
void conectarWiFi();

// ---------- SETUP ----------
void setup() {
  Serial.begin(115200);

  // Configura sensor SCT013 com fator de calibração - ajuste conforme seu sensor/resistor.
  SCT013.current(pinSCT, 1.45);

  // Botão e LEDs
  pinMode(BOTAO, INPUT_PULLUP);
  pinMode(LED_220V, OUTPUT);
  pinMode(LED_110V, OUTPUT);
  pinMode(LED_OFF, OUTPUT);
  atualizarLEDs();

  // Conecta na rede Wi-Fi (sem servidor)
  conectarWiFi();
}

// ---------- LOOP ----------
void loop() {
  unsigned long agora = millis();

  // Trata botão e LEDs
  alternarTensao();

  // Desliga o LED vermelho se passou o tempo de segurança
  if (vermelhoDesligando && (agora - tempoDesligamentoVermelho >= 10000UL)) {
    digitalWrite(LED_OFF, LOW);
    vermelhoDesligando = false;
    Serial.println("LED OFF desligado após 10 segundos");
  }

  // Leitura periódica do sensor
  if (agora - ultimoLeitura >= intervaloLeitura) {
    ultimoLeitura = agora;

    // Lê corrente RMS (número de amostras: 2048 — ajuste se necessário)
    Irms = SCT013.calcIrms(2048);

    // Filtra ruídos muito baixos
    if (Irms < 0.16) Irms = 0.0;

    // Exibição simples — só tensão e corrente
    Serial.printf("Tensao: %d V  |  Corrente (Irms): %.3f A\n", tensao, Irms);
  }

  // (Sem server.handleClient — não há WebServer ativo)
}

// ---------- FUNÇÕES ----------

void alternarTensao() {
  int estadoBotaoAtual = digitalRead(BOTAO);

  // Detecta borda de pressão (HIGH -> LOW)
  if (estadoBotaoAnterior == HIGH && estadoBotaoAtual == LOW) {
    contadorTensao++;
    if (contadorTensao > 2) contadorTensao = 0;

    switch (contadorTensao) {
      case 0: tensao = 110; break;
      case 1: tensao = 220; break;
      case 2: tensao = 0; break; // modo desligado (OFF)
    }

    atualizarLEDs();

    Serial.print("Botao pressionado. Nova tensao: ");
    Serial.print(tensao);
    Serial.println(" V");

    if (tensao == 0) {
      vermelhoDesligando = true;
      tempoDesligamentoVermelho = millis();
      Serial.println("LED OFF acionado — permanecerá aceso por 10s");
    } else {
      vermelhoDesligando = false;
    }

    // Debounce simples — mantém comportamento parecido com versão anterior
    delay(300);
  }

  estadoBotaoAnterior = estadoBotaoAtual;
}

void atualizarLEDs() {
  digitalWrite(LED_220V, LOW);
  digitalWrite(LED_110V, LOW);
  digitalWrite(LED_OFF, LOW);

  switch (tensao) {
    case 110:
      digitalWrite(LED_110V, HIGH);
      break;
    case 220:
      digitalWrite(LED_220V, HIGH);
      break;
    case 0:
      digitalWrite(LED_OFF, HIGH);
      break;
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
    Serial.println("\nFalha ao conectar WiFi (modo protótipo).");
    // Mantemos o protótipo funcional mesmo sem WiFi; reconexão pode ser feita por restart externo.
  }
}
