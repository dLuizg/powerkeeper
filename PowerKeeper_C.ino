#include <WiFi.h>
#include "EmonLib.h"
#include <Firebase_ESP_Client.h>
#include <time.h>

EnergyMonitor SCT013;

// ---------- CONFIGURAÇÕES ----------
const char* ssid = "Augusto";
const char* password = "internet100";

// ID fixo do dispositivo
const int idDispositivo = 1;

// Contador de leituras (leitura 1, leitura 2...)
unsigned long contadorLeitura = 1;

const int pinSCT = 35;  // Pino ADC do sensor SCT013
#define BOTAO 14        // Botão para alternar tensão

// Pinos dos LEDs
#define LED_220V 25
#define LED_127V 26
#define LED_OFF 27

// ---------- CONFIGURAÇÕES DO FIREBASE ----------
#define FIREBASE_HOST "https://powerkeeper-synatec-default-rtdb.firebaseio.com/"
// (token removido conforme solicitado)
//#define FIREBASE_AUTH "PjoVHPjmYMxYnlD6ikJY5gd75s00md1z1ISsvMit"

// ---------- OBJETOS GLOBAIS FIREBASE ----------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Controle de tensão simulada (127 / 220 / 0)
int tensao = 127;
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

// ---------- CONSUMO DE ENERGIA ----------
double energia_Wh = 0.0;
double consumoAtual_kWh = 0.0;
double consumoOntem_kWh = 0.0;

unsigned long long ultimoTempoMicro = 0;

int diaAtual = -1;   // Dia do mês (1–31)

// ---------- PROTÓTIPOS ----------
void alternarTensao();
void atualizarLEDs();
void conectarWiFi();
void configurarFirebase();
void enviarDadosFirebase();
String gerarTimestampISO();               // timestamp ISO: "YYYY-MM-DD HH:MM:SS"
void verificarViradaDia();
void checarUltimaLeituraEFazerFechamento(); // solução 3: ler /ultima_leitura
String dataAtualISO();                     // retorna "YYYY-MM-DD"

// ---------- IMPLEMENTAÇÕES ----------

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

String dataAtualISO() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);

  char buffer[12];
  sprintf(buffer, "%04d-%02d-%02d",
          t->tm_year + 1900,
          t->tm_mon + 1,
          t->tm_mday);

  return String(buffer);
}

// ---------- SETUP ----------
void setup() {
  Serial.begin(115200);

  SCT013.current(pinSCT, 1.45);

  pinMode(BOTAO, INPUT_PULLUP);
  pinMode(LED_220V, OUTPUT);
  pinMode(LED_127V, OUTPUT);
  pinMode(LED_OFF, OUTPUT);
  atualizarLEDs();

  conectarWiFi();

  // Ajusta relógio NTP
  configTime(-3 * 3600, 0, "pool.ntp.org", "time.nist.gov");

  // Aguarda tempo NTP sincronizar (curto delay) — evita usar delay longo
  unsigned long start = millis();
  while (millis() - start < 2000) {
    // apenas espera 2s para o NTP buscar (se já sincronizado, retorna rápido)
    delay(10);
  }

  // Registrar dia atual
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);
  diaAtual = t->tm_mday;

  // Init para o cálculo de energia
  ultimoTempoMicro = micros();

  if (WiFi.status() == WL_CONNECTED) {
    configurarFirebase();
    // SOLUÇÃO 3: ao iniciar, checar /ultima_leitura e fechar o dia anterior se necessário
    checarUltimaLeituraEFazerFechamento();
  }
}

// ---------- LOOP ----------
void loop() {
  unsigned long agora = millis();

  verificarViradaDia(); // garante fechamento se dispositivo já estiver ligado na virada
  alternarTensao();

  if (vermelhoDesligando && (agora - tempoDesligamentoVermelho >= 10000UL)) {
    digitalWrite(LED_OFF, LOW);
    vermelhoDesligando = false;
  }

  // Leitura
  if (agora - ultimoLeitura >= intervaloLeitura) {
    ultimoLeitura = agora;

    Irms = SCT013.calcIrms(2048);
    if (Irms < 0.16) Irms = 0.0;

    // ------- CÁLCULO ENERGIA -------
    unsigned long long agoraMicro = micros();
    unsigned long long deltaTempo = agoraMicro - ultimoTempoMicro;
    ultimoTempoMicro = agoraMicro;

    double potencia = Irms * tensao; // W

    if (potencia > 0) {
      energia_Wh += (potencia * (deltaTempo / 3600000000.0)); // Wh
      consumoAtual_kWh = energia_Wh / 1000.0;                 // kWh
    }

    Serial.printf("Tensao: %d V | Irms: %.3f A | P: %.2f W | Consumo Hoje: %.6f kWh\n",
                  tensao, Irms, potencia, consumoAtual_kWh);
  }

  // Firebase
  if (agora - ultimoFirebase >= intervaloFirebase) {
    ultimoFirebase = agora;

    if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
      enviarDadosFirebase();
    } else if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Tentando enviar, mas WiFi desconectado.");
    }
  }
}

// ---------- DETECTAR NOVO DIA ----------
void verificarViradaDia() {
  time_t now = time(nullptr);
  struct tm* t = localtime(&now);

  if (t->tm_mday != diaAtual) {

    // Fechar dia anterior localmente: consumoOntem_kWh recebe consumo atual
    consumoOntem_kWh = consumoAtual_kWh;

    // Enviar consumo fechado do dia anterior (usa dataISO do diaAnterior)
    // calcular diaAnterior string
    // Obtemos a struct tm do "now" e subtraímos 1 dia.
    time_t agora = time(nullptr);
    struct tm tm_ante = *localtime(&agora);
    tm_ante.tm_mday -= 1;
    mktime(&tm_ante); // normaliza data

    char pathDate[12];
    sprintf(pathDate, "%04d-%02d-%02d",
            tm_ante.tm_year + 1900,
            tm_ante.tm_mon + 1,
            tm_ante.tm_mday);

    String path = "/consumos_diarios/" + String(pathDate);

    FirebaseJson json;
    json.set("consumo_kWh", consumoOntem_kWh);
    json.set("idDispositivo", idDispositivo);
    json.set("timestamp", gerarTimestampISO());

    if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
      Serial.println("Consumo diário (fechado) enviado: " + String(path));
    } else {
      Serial.println("Falha ao enviar consumo diário: " + fbdo.errorReason());
    }

    // Reset diário
    consumoAtual_kWh = 0.0;
    energia_Wh = 0.0;

    // Atualiza diaAtual para o dia corrente
    diaAtual = t->tm_mday;

    Serial.println("----- NOVO DIA ----- Consumo zerado.");
  }
}

// ---------- ALTERAR TENSÃO ----------
void alternarTensao() {
  int estadoBotaoAtual = digitalRead(BOTAO);

  if (estadoBotaoAnterior == HIGH && estadoBotaoAtual == LOW) {
    contadorTensao++;
    if (contadorTensao > 2) contadorTensao = 0;

    switch (contadorTensao) {
      case 0: tensao = 127; break;
      case 1: tensao = 220; break;
      case 2: tensao = 0; break;
    }

    atualizarLEDs();

    if (tensao == 0) {
      vermelhoDesligando = true;
      tempoDesligamentoVermelho = millis();
      Serial.println("LED OFF - aceso por 10s");
    } else {
      vermelhoDesligando = false;
    }

    Serial.print("Botao pressionado. Nova tensao: ");
    Serial.print(tensao);
    Serial.println(" V");

    delay(300);
  }

  estadoBotaoAnterior = estadoBotaoAtual;
}

// ---------- ATUALIZAR LEDs ----------
void atualizarLEDs() {
  digitalWrite(LED_220V, LOW);
  digitalWrite(LED_127V, LOW);
  digitalWrite(LED_OFF, LOW);

  switch (tensao) {
    case 127: digitalWrite(LED_127V, HIGH); break;
    case 220: digitalWrite(LED_220V, HIGH); break;
    case 0:   digitalWrite(LED_OFF, HIGH); break;
  }
}

// ---------- CONECTAR WiFi ----------
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

// ---------- CONFIGURAR FIREBASE ----------
void configurarFirebase() {
  Serial.println("Configurando Firebase...");

  config.host = FIREBASE_HOST;
  // sem token/credenciais (conforme instruído)
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase iniciado.");
}

// ---------- ENVIAR LEITURA ----------
void enviarDadosFirebase() {
  Serial.print("Registrando leitura no Firebase... ");

  // Formato desejado: leitura 1, leitura 2, leitura 3...
  String path = "/leituras/leitura " + String(contadorLeitura++);

  double potenciaW = Irms * tensao;

  FirebaseJson json;
  json.set("tensao", tensao);
  json.set("corrente", Irms);
  json.set("potencia", potenciaW);               // potÊncia instantânea (W)
  json.set("consumoAtual_kWh", consumoAtual_kWh);
  json.set("idDispositivo", idDispositivo);
  json.set("timestamp", gerarTimestampISO());    // TIMESTAMP ISO

  // Grava leitura enumerada
  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("Sucesso!");
  } else {
    Serial.println("Falha.");
    Serial.println("Razao: " + fbdo.errorReason());
  }

  // Também gravar um ponto conhecido com a ÚLTIMA LEITURA (facilita buscas e boot recovery)
  String ultimaPath = "/ultima_leitura";
  if (Firebase.RTDB.setJSON(&fbdo, ultimaPath.c_str(), &json)) {
    // sucesso
  } else {
    Serial.println("Falha ao atualizar /ultima_leitura: " + fbdo.errorReason());
  }
}

// ---------- CHECAR ÚLTIMA LEITURA NO FIREBASE E FECHAR DIA SE NECESSÁRIO ----------
void checarUltimaLeituraEFazerFechamento() {
  // Tenta ler /ultima_leitura
  if (!Firebase.RTDB.getJSON(&fbdo, "/ultima_leitura")) {
    Serial.println("Nenhuma /ultima_leitura disponível ou falha ao ler: " + fbdo.errorReason());
    return;
  }

  // Obter JSON retornado
  FirebaseJson json = fbdo.jsonObject();

  // Recupera o campo timestamp e consumoAtual_kWh (se existirem)
  FirebaseJsonData result;

  String ts = "";
  double ultimoConsumo = 0.0;
  int ultimoIdDisp = -1;

  if (json.get(result, "timestamp")) {
    if (result.type == FirebaseJson::JSON_STRING) ts = result.stringValue;
  }
  if (json.get(result, "consumoAtual_kWh")) {
    if (result.type == FirebaseJson::JSON_FLOAT || result.type == FirebaseJson::JSON_DOUBLE) {
      ultimoConsumo = result.doubleValue;
    } else if (result.type == FirebaseJson::JSON_INT) {
      ultimoConsumo = (double) result.intValue;
    }
  }
  if (json.get(result, "idDispositivo")) {
    if (result.type == FirebaseJson::JSON_INT) ultimoIdDisp = result.intValue;
  }

  if (ts == "") {
    Serial.println("ultima_leitura não tem timestamp, pulando fechamento retroativo.");
    return;
  }

  // Esperamos timestamp no formato ISO "YYYY-MM-DD HH:MM:SS"
  // Extrair a data (primeiros 10 caracteres)
  String dataUltima = ts.substring(0, 10);
  String dataHoje = dataAtualISO();

  Serial.println("Data da ultima leitura: " + dataUltima + "  /  Data atual: " + dataHoje);

  if (dataUltima != dataHoje) {
    // fechar o dia dataUltima com o consumo registrado no último ponto
    String path = "/consumos_diarios/" + dataUltima;

    FirebaseJson out;
    out.set("consumo_kWh", ultimoConsumo);
    out.set("idDispositivo", (ultimoIdDisp == -1 ? idDispositivo : ultimoIdDisp));
    out.set("timestamp", ts);

    if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &out)) {
      Serial.println("Fechamento retroativo enviado para: " + path);
    } else {
      Serial.println("Falha ao enviar fechamento retroativo: " + fbdo.errorReason());
    }
  } else {
    Serial.println("ultima_leitura pertence ao mesmo dia. Nada a fechar.");
  }
}
