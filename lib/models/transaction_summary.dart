class TransactionSummary {
  final double income;
  final double expense;
  double get balance => income - expense;

  const TransactionSummary({
    required this.income,
    required this.expense,
  });

  Map<String, dynamic> toJson() => {
        'income': income,
        'expense': expense,
        'balance': balance,
      };

  factory TransactionSummary.fromTransactions(Iterable<double> amounts) {
    double inc = 0, exp = 0;
    for (final a in amounts) {
      if (a >= 0) {
        inc += a;
      } else {
        exp += a.abs();
      }
    }
    return TransactionSummary(income: inc, expense: exp);
  }
}
