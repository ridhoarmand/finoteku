/// Value object for representing monetary amount in a specific currency.
class Money {
  final double amount;
  final String currency; // ISO code e.g., 'IDR'
  const Money(this.amount, {this.currency = 'IDR'});

  Money operator +(Money other) {
    assert(other.currency == currency, 'Currency mismatch');
    return Money(amount + other.amount, currency: currency);
  }

  Money operator -(Money other) {
    assert(other.currency == currency, 'Currency mismatch');
    return Money(amount - other.amount, currency: currency);
  }

  Money copyWith({double? amount, String? currency}) =>
      Money(amount ?? this.amount, currency: currency ?? this.currency);

  @override
  String toString() => '$currency $amount';
}
