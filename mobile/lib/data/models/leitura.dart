class Leitura {
  final int? id;
  final int colmeiaId;
  final DateTime timestamp;
  final double temperatura;
  final double humidade;
  final double peso;
  final int entradasAbelhas;
  final int saidasAbelhas;
  final double nivelBateria;

  const Leitura({
    this.id,
    required this.colmeiaId,
    required this.timestamp,
    required this.temperatura,
    required this.humidade,
    required this.peso,
    required this.entradasAbelhas,
    required this.saidasAbelhas,
    required this.nivelBateria,
  });

  factory Leitura.fromJson(Map<String, dynamic> j) => Leitura(
        id:              j['id']               as int?,
        colmeiaId:       j['colmeia_id']       as int,
        timestamp:       DateTime.parse(j['timestamp'] as String),
        temperatura:     (j['temperatura']     as num).toDouble(),
        humidade:        (j['humidade']        as num).toDouble(),
        peso:            (j['peso']            as num).toDouble(),
        entradasAbelhas: (j['entradas_abelhas'] as num?)?.toInt() ?? 0,
        saidasAbelhas:   (j['saidas_abelhas']   as num?)?.toInt() ?? 0,
        nivelBateria:    (j['nivel_bateria']   as num).toDouble(),
      );

  /// Parses a CSV line: timestamp,temperatura,humidade,peso,entradas,saidas,bateria
  static Leitura? fromCsvLine(String line, {required int colmeiaId}) {
    final p = line.trim().split(',');
    if (p.length < 7) return null;
    try {
      return Leitura(
        colmeiaId:       colmeiaId,
        timestamp:       DateTime.parse(p[0]),
        temperatura:     double.parse(p[1]),
        humidade:        double.parse(p[2]),
        peso:            double.parse(p[3]),
        entradasAbelhas: int.parse(p[4]),
        saidasAbelhas:   int.parse(p[5]),
        nivelBateria:    double.parse(p[6]),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'colmeia_id':      colmeiaId,
        'timestamp':       timestamp.toIso8601String(),
        'temperatura':     temperatura,
        'humidade':        humidade,
        'peso':            peso,
        'entradas_abelhas': entradasAbelhas,
        'saidas_abelhas':  saidasAbelhas,
        'nivel_bateria':   nivelBateria,
      };

  // Payload for POST /api/colmeias/:id/leituras
  Map<String, dynamic> toApiJson() => {
        'timestamp':       timestamp.toIso8601String(),
        'temperatura':     temperatura,
        'humidade':        humidade,
        'peso':            peso,
        'entradas_abelhas': entradasAbelhas,
        'saidas_abelhas':  saidasAbelhas,
        'nivel_bateria':   nivelBateria,
      };
}
