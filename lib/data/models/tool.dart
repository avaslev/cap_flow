import 'package:uuid/uuid.dart';

class Tool {
  final String id;
  final String name;
  final String accountId;
  final String type;
  final String? ticker; // Ticker symbol for some tools

  // Deposit specific fields, nullable for other tool types
  final DateTime? startDate;
  final DateTime? endDate;
  final String? payType; // for deposites and credits

  // New Credit specific fields, nullable for other tool types
  // Annual interest rate for credit/loan and deposit
  final double? interestRate;
  final int? paymentDayOfMonth; // Day of the month for credit payments

  // New Bond specific fields
  final double? faceValue; // Nominal value of the bond

  Tool({
    required this.id,
    required this.name,
    required this.accountId,
    required this.type,
    this.ticker,
    this.startDate,
    this.endDate,
    this.payType,
    this.interestRate,
    this.paymentDayOfMonth,
    this.faceValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountId': accountId,
      'type': type,
      'ticker': ticker,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.microsecondsSinceEpoch,
      'payType': payType,
      'interestRate': interestRate,
      'paymentDayOfMonth': paymentDayOfMonth,
      'faceValue': faceValue,
    };
  }

  factory Tool.fromMap(Map<String, dynamic> map) {
    print(map);
    // Required fields are assumed to be present and of correct type.
    final String id = map['id'] as String;
    final String name = map['name'] as String;
    final String accountId = map['accountId'] as String;
    final String type = map['type'] as String;

    // Nullable string fields can be directly cast with `as String?`.
    final String? ticker = map['ticker'] as String?;
    final String? payType = map['payType'] as String?;

    // DateTimes are stored as int (milliseconds or microseconds since epoch).
    // Check if the value is an int before converting.
    final DateTime? startDate =
        (map['startDate'] is int)
            ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
            : null;

    final DateTime? endDate =
        (map['endDate'] is int)
            ? DateTime.fromMicrosecondsSinceEpoch(map['endDate'] as int)
            : null;

    // Double fields can be stored as int or double (num).
    // Convert to double if it's a number, otherwise null.
    final double? interestRate =
        (map['interestRate'] is num)
            ? (map['interestRate'] as num).toDouble()
            : null;

    // Integer fields can be directly cast if present and an int.
    final int? paymentDayOfMonth =
        (map['paymentDayOfMonth'] is int)
            ? (map['paymentDayOfMonth'] as int)
            : null;

    final double? faceValue =
        (map['faceValue'] is num) ? (map['faceValue'] as num).toDouble() : null;

    return Tool(
      id: id,
      name: name,
      accountId: accountId,
      type: type,
      ticker: ticker,
      startDate: startDate,
      endDate: endDate,
      payType: payType,
      interestRate: interestRate,
      paymentDayOfMonth: paymentDayOfMonth,
      faceValue: faceValue,
    );
  }
}
