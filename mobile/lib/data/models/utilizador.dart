import 'dart:convert';

class Utilizador {
  final int id;
  final String nome;
  final String email;
  final String role;

  const Utilizador({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory Utilizador.fromJson(Map<String, dynamic> j) => Utilizador(
        id:    j['id']    as int,
        nome:  j['nome']  as String,
        email: j['email'] as String,
        role:  j['role']  as String,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'nome': nome, 'email': email, 'role': role};

  String toJsonString() => jsonEncode(toJson());
  factory Utilizador.fromJsonString(String s) =>
      Utilizador.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
