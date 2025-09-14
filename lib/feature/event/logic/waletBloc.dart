import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/event/data/wallet.dart';

// Wallet Bloc
// Events
abstract class WalletEvent {
  const WalletEvent();
}

class LoadWallets extends WalletEvent {
  final String accountId;
  const LoadWallets(this.accountId);
}

// States
abstract class WalletState {
  const WalletState();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletLoaded extends WalletState {
  final List<Wallet> wallets;
  const WalletLoaded(this.wallets);
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);
}

// Bloc
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc() : super(const WalletLoading()) {
    on<LoadWallets>(_onLoadWallets);
  }

  void _onLoadWallets(LoadWallets event, Emitter<WalletState> emit) async {
    // In a real app, this would load from a repository
    // For now, it just ensures the current state is emitted, or loads initial dummy data.
    print('_onLoadWallets');

    emit(WalletLoaded((await ToolRepository().geListByAccount(event.accountId)).map(
      (Tool tool) => Wallet(
        id: tool.id,
        name: tool.name,
        icon: Icons.account_balance_wallet,
        color: Colors.indigo,
      ),
    ).toList()));
  }
}
