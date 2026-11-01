import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/feature/event/data/event.dart';
import 'package:capflow/feature/event/data/wallet.dart';
import 'package:capflow/feature/event/logic/transferWalletOptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Wallet _wallet({
  required String id,
  required String accountId,
  required String ticker,
  ToolType type = ToolType.money,
}) {
  return Wallet(
    id: id,
    name: id,
    icon: Icons.account_balance_wallet,
    color: Colors.indigo,
    accountId: accountId,
    accountName: accountId,
    ticker: ticker,
    type: type,
  );
}

void main() {
  final List<Wallet> wallets = <Wallet>[
    _wallet(id: 'source', accountId: 'a', ticker: 'RUB'),
    _wallet(
      id: 'stock',
      accountId: 'a',
      ticker: 'RUB',
      type: ToolType.stocks,
    ),
    _wallet(id: 'other-rub', accountId: 'b', ticker: 'RUB'),
    _wallet(id: 'other-usd', accountId: 'b', ticker: 'USD'),
    _wallet(
      id: 'other-stock',
      accountId: 'b',
      ticker: 'RUB',
      type: ToolType.stocks,
    ),
  ];

  group('transferWalletOptions', () {
    test('внутри счёта источник — все тулы, получатель — кроме источника', () {
      final List<Wallet> sources = transferSourceWallets(
        wallets: wallets,
        accountId: 'a',
        type: FinancialEventType.transfer,
      );
      expect(sources.map((Wallet w) => w.id), <String>['source', 'stock']);

      final List<Wallet> destinations = transferDestinationWallets(
        wallets: wallets,
        accountId: 'a',
        type: FinancialEventType.transfer,
        sourceId: 'source',
      );
      expect(destinations.map((Wallet w) => w.id), <String>['stock']);
    });

    test('между счетами — только money-тулы с той же валютой', () {
      final List<Wallet> sources = transferSourceWallets(
        wallets: wallets,
        accountId: 'a',
        type: FinancialEventType.interAccountTransfer,
      );
      expect(sources.map((Wallet w) => w.id), <String>['source']);

      final List<Wallet> destinations = transferDestinationWallets(
        wallets: wallets,
        accountId: 'a',
        type: FinancialEventType.interAccountTransfer,
        sourceId: 'source',
      );
      expect(destinations.map((Wallet w) => w.id), <String>['other-rub']);
    });

    test('без источника получатели между счетами не предлагаются', () {
      expect(
        transferDestinationWallets(
          wallets: wallets,
          accountId: 'a',
          type: FinancialEventType.interAccountTransfer,
          sourceId: null,
        ),
        isEmpty,
      );
    });
  });

  group('FinancialEvent.copyWith', () {
    FinancialEvent event() => FinancialEvent(
      id: 'e1',
      name: 'Перевод',
      amount: 100,
      type: FinancialEventType.interAccountTransfer,
      category: '',
      date: DateTime(2026, 1, 1),
      walletId: 'source',
      destinationWalletId: 'other-rub',
    );

    test('null без clearDestinationWalletId сохраняет получателя', () {
      expect(
        event().copyWith(destinationWalletId: null).destinationWalletId,
        'other-rub',
      );
    });

    test('clearDestinationWalletId очищает получателя', () {
      expect(
        event().copyWith(clearDestinationWalletId: true).destinationWalletId,
        isNull,
      );
    });
  });

  test('новый тип входит в семейство переводов', () {
    expect(FinancialEventType.transfer.isTransfer, isTrue);
    expect(FinancialEventType.interAccountTransfer.isTransfer, isTrue);
    expect(FinancialEventType.income.isTransfer, isFalse);
  });
}
