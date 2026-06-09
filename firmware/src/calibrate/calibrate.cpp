#include <Arduino.h>
#include <HX711_ADC.h>

#define HX711_DT  34
#define HX711_SCK 32

HX711_ADC scale(HX711_DT, HX711_SCK);

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n=== CALIBRAÇÃO HX711 ===");
    Serial.println("Retira TODO o peso da balança e aguarda...");

    scale.begin();
    scale.start(3000, true);   // estabiliza 3 s com tara automática
    scale.setCalFactor(1.0f);  // factor neutro para ler valor bruto

    Serial.println("Tara feita. Valor bruto em repouso:");
    for (int i = 0; i < 5; i++) {
        scale.update();
        delay(300);
    }
    float zero = scale.getData();
    Serial.printf("  offset bruto = %.1f\n", zero);

    Serial.println("\nColoca um peso CONHECIDO na balança.");
    Serial.println("Quando estiver estável, envia o valor em KG pelo monitor série (ex: 1.000)");
}

void loop() {
    scale.update();

    if (Serial.available()) {
        float knownKg = Serial.parseFloat();
        if (knownKg <= 0) { Serial.println("Valor inválido."); return; }

        // Média de 20 amostras com peso
        float sum = 0;
        int n = 0;
        unsigned long t = millis();
        while (n < 20 && millis() - t < 8000) {
            if (scale.update()) { sum += scale.getData(); n++; }
            delay(50);
        }
        if (n == 0) { Serial.println("Sem leituras. Verifica ligações."); return; }

        float rawWithWeight = sum / n;
        float calFactor = rawWithWeight / knownKg;

        Serial.printf("\n--- RESULTADO ---\n");
        Serial.printf("Peso conhecido : %.3f kg\n", knownKg);
        Serial.printf("Valor bruto    : %.1f\n", rawWithWeight);
        Serial.printf("CAL_FACTOR     : %.2f\n\n", calFactor);
        Serial.println("Copia o CAL_FACTOR para main.cpp:");
        Serial.printf("  #define CAL_FACTOR  %.2ff\n\n", calFactor);
        Serial.println("Envia outro peso para confirmar, ou fecha o monitor.");
        scale.setCalFactor(calFactor);
    }
}
