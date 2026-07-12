import '../util/format.dart';

/// A CRM contact — mirrors the `public.contacts` table.
///
/// The server owns `id`, `created_at`, `updated_at`, and `deleted_at`; the client
/// only ever writes the human fields (see [toRpcParams]). `dob` is a real date.
class Contact {
  final String id;
  final String name;
  final DateTime? dob;
  final String? email;
  final String? phone;
  final String? company;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Contact({
    required this.id,
    required this.name,
    this.dob,
    this.email,
    this.phone,
    this.company,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  /// A not-yet-persisted contact. Uses an empty id — the DB assigns the real one.
  const Contact.draft({
    required this.name,
    this.dob,
    this.email,
    this.phone,
    this.company,
    this.remarks,
  }) : id = '',
       createdAt = null,
       updatedAt = null;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    dob: _parseDate(json['dob']),
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    remarks: json['remarks'] as String?,
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
  );

  /// Params for the `create_contact` / `update_contact` RPCs (Decision 26 — all writes go
  /// through RPCs). `p_name` is trimmed here (belt-and-suspenders with the server, mirroring
  /// `Event.toRpcParams`); the optional text fields are sent raw and the RPC normalizes
  /// empty→null via `nullif(trim(...))`, so that logic lives in one place (the DB). The repo
  /// adds `p_id` for updates.
  Map<String, dynamic> toRpcParams() => {
    'p_name': name.trim(),
    'p_dob': dob == null ? null : ymd(dob!),
    'p_email': email,
    'p_phone': phone,
    'p_company': company,
    'p_remarks': remarks,
  };

  Contact copyWith({
    String? name,
    DateTime? dob,
    bool clearDob = false,
    String? email,
    String? phone,
    String? company,
    String? remarks,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    dob: clearDob ? null : (dob ?? this.dob),
    email: email ?? this.email,
    phone: phone ?? this.phone,
    company: company ?? this.company,
    remarks: remarks ?? this.remarks,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
