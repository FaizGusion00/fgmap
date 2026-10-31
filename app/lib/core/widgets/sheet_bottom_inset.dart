import 'package:flutter/widgets.dart';

/// Menjauhkan kandungan lembaran bawah daripada bar navigasi sistem (butang Android 3-butang atau
/// garis gerak isyarat). `showModalBottomSheet(useSafeArea: true)` hanya melindungi bahagian atas,
/// jadi tanpa ini butang di tepi bawah lembaran berada di bawah bar sistem dan sukar diketik.
/// Permukaan lembaran tetap memanjang di belakang bar; hanya kandungan yang dijarakkan.
class SheetBottomInset extends StatelessWidget {
  const SheetBottomInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
    child: child,
  );
}
