#include <WiFi.h>
#include "EmonLib.h"
#include <Firebase_ESP_Client.h>  // --- NOVO ---

EnergyMonitor SCT013;

// ---------- CONFIGURAÇÕES ----------
const char* ssid = "Augusto";
const char* password = "internet100";

const int pinSCT = 35;  // Pino ADC do sensor SCT013
#define BOTAO 14        // Botão para alternar tensão

// Pinos dos LEDs
#define LED_220V 25
#define LED_110V 26
#define LED_OFF 27

// ---------- CONFIGURAÇÕES DO FIREBASE (PREENCHA AQUI) ----------
/*
  Instruções:
  1. Instale a biblioteca "Firebase-ESP-Client" pelo Gerenciador de Bibliotecas.
  2. Obtenha a URL no seu Realtime Database (Ex: https://meu-projeto-default-rtdb.firebaseio.com)
  3. Obtenha o Segredo do Banco de Dados (Legacy) em Configurações do Projeto > Contas de Serviço.
*/
#define FIREBASE_HOST "https://powerkeeper-33345-default-rtdb.firebaseio.com/"  // --- NOVO --- (URL do Realtime Database)
#define FIREBASE_AUTH "PjoVHPjmYMxYnlD6ikJY5gd75s00md1z1ISsvMit"                // --- NOVO --- (Segredo Legacy)

// ---------- OBJETOS GLOBAIS FIREBASE ----------
FirebaseData fbdo;      // --- NOVO --- Objeto de transação de dados
FirebaseAuth auth;      // --- NOVO --- Objeto de autenticação
FirebaseConfig config;  // --- NOVO --- Objeto de configuração

// Controle de tensão simulada (110 / 220 / 0)
int tensao = 110;
int estadoBotaoAnterior = HIGH;
int contadorTensao = 0;

// Intervalo de leitura / exibição (ms)
unsigned long intervaloLeitura = 1000;
unsigned long ultimoLeitura = 0;

// --- NOVO --- Intervalo de envio para o Firebase (ms)
unsigned long intervaloFirebase = 5000;  // Envia a cada 10 segundos
unsigned long ultimoFirebase = 0;

// Medições
double Irms = 0.0;

// Controle do LED vermelho temporizado (modo OFF)
unsigned long tempoDesligamentoVermelho = 0;
bool vermelhoDesligando = false;

// ---------- PROTÓTIPOS ----------
void alternarTensao();
void atualizarLEDs();
void conectarWiFi();
void configurarFirebase();   // --- NOVO ---
void enviarDadosFirebase();  // --- NOVO ---

// ---------- SETUP ----------
void setup() {
  Serial.begin(115200);

  // Configura sensor SCT013
  SCT013.current(pinSCT, 1.45);

  // Botão e LEDs
  pinMode(BOTAO, INPUT_PULLUP);
  pinMode(LED_220V, OUTPUT);
  pinMode(LED_110V, OUTPUT);
  pinMode(LED_OFF, OUTPUT);
  atualizarLEDs();

  // Conecta na rede Wi-Fi
  conectarWiFi();

  // --- NOVO --- Configura e inicia o Firebase (APÓS conectar o WiFi)
  if (WiFi.status() == WL_CONNECTED) {
    configurarFirebase();
  }
}

// ---------- LOOP ----------
void loop() {
  unsigned long agora = millis();
  // --- NOVO --- Intervalo de envio para o Firebase (ms)

  // Trata botão e LEDs
  alternarTensao();

  // Desliga o LED vermelho
  if (vermelhoDesligando && (agora - tempoDesligamentoVermelho >= 10000UL)) {
    digitalWrite(LED_OFF, LOW);
    vermelhoDesligando = false;
    Serial.println("LED OFF desligado após 10 segundos");
  }

  // Leitura periódica do sensor
  if (agora - ultimoLeitura >= intervaloLeitura) {
    ultimoLeitura = agora;

    // Lê corrente RMS
    Irms = SCT013.calcIrms(2048);
    if (Irms < 0.16) Irms = 0.0;

    Serial.printf("Tensao: %d V  |  Corrente (Irms): %.3f A\n", tensao, Irms);
  }

  // --- NOVO --- Envio periódico para o Firebase
  if (agora - ultimoFirebase >= intervaloFirebase) {
    ultimoFirebase = agora;

    // Só tenta enviar se o WiFi estiver conectado e o Firebase pronto
    if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
      enviarDadosFirebase();
    } else if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Tentando enviar, mas WiFi esta desconectado.");
      // Tenta reconectar se cair (opcional)
      // WiFi.reconnect();
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
      Serial.println("LED OFF acionado — permanecerá aceso por 10s");
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
  }
}

// ---------- FUNÇÕES NOVAS (FIREBASE) ----------

void configurarFirebase() {
  Serial.println("Configurando Firebase...");

  // Define o Host (URL do database)
  config.host = FIREBASE_HOST;

  // Define a autenticação (usando o Segredo Legacy)
  config.signer.tokens.legacy_token = FIREBASE_AUTH;

  // Inicia o Firebase com a configuração e autenticação
  Firebase.begin(&config, &auth);

  // Helper para reconectar o WiFi automaticamente se cair
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase iniciado.");
}

/*
  Esta função envia os dados para o nó "/status_atual" do seu Realtime Database.
  Ela irá SOBRESCREVER os dados antigos com os novos valores de tensão e corrente.
*/
/*
  FUNÇÃO ATUALIZADA - Agora registra um histórico (log)
*/
void enviarDadosFirebase() {
  // Mensagem de log um pouco diferente para clareza
  Serial.print("Registrando leitura no Firebase... ");

  // É uma boa prática usar um nome de caminho que indique um log/histórico
  String path = "/historico_leituras";

  FirebaseJson json;
  json.set("tensao", tensao);
  json.set("corrente", Irms);
  // O timestamp ".sv" é PERFEITO para um log, pois registra
  // exatamente quando o dado chegou no servidor Firebase.
  json.set("timestamp", ".sv");

  // --- MUDANÇA PRINCIPAL ---
  // Trocamos setJSON por pushJSON.
  // pushJSON cria um novo item com um ID único dentro de "/historico_leituras"
  if (Firebase.RTDB.pushJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("Sucesso! Leitura registrada.");
  } else {
    Serial.println("Falha ao registrar.");
    Serial.println("Razao: " + fbdo.errorReason());
  }
}