import 'package:uuid/uuid.dart';

/// The single client-side id mint point. New entities carry a client-generated v4 uuid so the
/// create_* RPCs can be idempotent (`on conflict (id) do nothing`) — a retry with the same id is a
/// no-op instead of a duplicate row (issue #9 / Decision 41). Forms hold one id across re-taps so a
/// user retry after a hung save reuses it.
const _uuid = Uuid();

/// A fresh v4 uuid for a not-yet-persisted entity.
String newEntityId() => _uuid.v4();
