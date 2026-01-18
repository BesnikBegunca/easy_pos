String moneyFromCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final v = cents.abs();
  final eur = v ~/ 100;
  final c = v % 100;
  return '$sign$eur.${c.toString().padLeft(2, '0')} €';
}
