/// Entidad de dominio para Clientes.
class ClientEntity {
  const ClientEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.documentId,
    this.vehicleInfo,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? documentId;
  final String phone;
  final String? vehicleInfo;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
