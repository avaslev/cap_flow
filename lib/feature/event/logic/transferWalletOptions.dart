import 'package:capflow/feature/event/data/event.dart';
import 'package:capflow/feature/event/data/wallet.dart';

/// Источники для перевода.
///
/// Внутри счёта поведение прежнее: доступны все тулы текущего счёта.
/// Для перевода между счетами — только открытые money-тулы текущего счёта.
List<Wallet> transferSourceWallets({
  required List<Wallet> wallets,
  required String accountId,
  required FinancialEventType type,
}) {
  if (type == FinancialEventType.interAccountTransfer) {
    return wallets
        .where(
          (Wallet wallet) => wallet.accountId == accountId && wallet.isMoney,
        )
        .toList();
  }
  return wallets
      .where((Wallet wallet) => wallet.accountId == accountId)
      .toList();
}

/// Получатели для перевода.
///
/// Внутри счёта — тулы текущего счёта, кроме источника.
/// Между счетами — money-тулы других счетов с той же валютой.
List<Wallet> transferDestinationWallets({
  required List<Wallet> wallets,
  required String accountId,
  required FinancialEventType type,
  required String? sourceId,
}) {
  if (type == FinancialEventType.transfer) {
    return wallets
        .where(
          (Wallet wallet) =>
              wallet.accountId == accountId && wallet.id != sourceId,
        )
        .toList();
  }

  if (type == FinancialEventType.interAccountTransfer) {
    Wallet? source;
    for (final Wallet wallet in wallets) {
      if (wallet.id == sourceId) {
        source = wallet;
        break;
      }
    }
    if (source == null) return const <Wallet>[];

    final Wallet sourceWallet = source;
    return wallets
        .where(
          (Wallet wallet) =>
              wallet.isMoney &&
              wallet.id != sourceWallet.id &&
              wallet.accountId != sourceWallet.accountId &&
              wallet.ticker == sourceWallet.ticker,
        )
        .toList();
  }

  return const <Wallet>[];
}
