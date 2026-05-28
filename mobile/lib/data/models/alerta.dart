class Alerta {
  final int id;
  final int colmeiaId;
  final String tipo; // 'temperatura' | 'humidade' | 'peso' | 'bateria'
  final String mensagem;
  final bool lido;
  final DateTime criadoEm;

  const Alerta({
    required this.id,
    required this.colmeiaId,
    required this.tipo,
    required this.mensagem,
    required this.lido,
    required this.criadoEm,
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        id:         j['id']         as int,
        colmeiaId:  j['colmeia_id'] as int,
        tipo:       j['tipo']       as String,
        mensagem:   j['mensagem']   as String,
        lido:       j['lido'] == 1 || j['lido'] == true,
        criadoEm:   DateTime.parse(j['criado_em'] as String),
      );
}
