class Colmeia {
  final int id;
  final int utilizadorId;
  final String nome;
  final String? localizacao;
  final double? latitude;
  final double? longitude;
  final bool ativa;
  final String? macAddress;
  final String modo; // 'base' | 'premium'

  const Colmeia({
    required this.id,
    required this.utilizadorId,
    required this.nome,
    this.localizacao,
    this.latitude,
    this.longitude,
    this.ativa = true,
    this.macAddress,
    this.modo = 'base',
  });

  bool get isPremium => modo == 'premium';

  factory Colmeia.fromJson(Map<String, dynamic> j) => Colmeia(
        id:           j['id']             as int,
        utilizadorId: j['utilizador_id']  as int,
        nome:         j['nome']           as String,
        localizacao:  j['localizacao']    as String?,
        latitude:     (j['latitude']  as num?)?.toDouble(),
        longitude:    (j['longitude'] as num?)?.toDouble(),
        ativa:        j['ativa'] == 1 || j['ativa'] == true,
        macAddress:   j['mac_address']    as String?,
        modo:         j['modo']           as String? ?? 'base',
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'utilizador_id': utilizadorId,
        'nome':          nome,
        'localizacao':   localizacao,
        'latitude':      latitude,
        'longitude':     longitude,
        'ativa':         ativa,
        'mac_address':   macAddress,
        'modo':          modo,
      };

  Colmeia copyWith({String? modo}) => Colmeia(
        id:           id,
        utilizadorId: utilizadorId,
        nome:         nome,
        localizacao:  localizacao,
        latitude:     latitude,
        longitude:    longitude,
        ativa:        ativa,
        macAddress:   macAddress,
        modo:         modo ?? this.modo,
      );
}
