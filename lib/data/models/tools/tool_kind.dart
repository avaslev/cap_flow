/// Types of financial tools (instruments) stored on an account.
///
/// Single source of truth for tool kind. Re-exported by
/// `accountDataState.dart` for backward compatibility.
enum ToolType {
  money,
  deposit,
  credit,
  stocks,
  bonds,
  cryptocurrency,
  other,
}

/// How a deposit pays out interest.
enum PayoutType {
  atEndOfTerm, // в конце срока
  monthly, // ежемесячная выплата
  monthlyToWithdrawalAccount, // ежемесячная выплата на счет списания
}

/// How a credit payment is structured.
enum CreditPaymentType {
  annuity, // аннуитетный (fixed payment amount over time)
  differentiated, // дифференцированный (decreasing payment amount over time)
}
