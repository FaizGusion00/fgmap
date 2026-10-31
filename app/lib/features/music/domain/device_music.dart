/// Kebenaran membaca muzik pada peranti; `unsupported` di platform tanpa jambatan (web, desktop).
enum DeviceMusicAccess {
  unsupported,
  notDetermined,
  denied,
  authorized;

  static DeviceMusicAccess fromName(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return DeviceMusicAccess.notDetermined;
  }
}
