import 'package:flutter/material.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:capflow/data/models/account.dart';
import 'package:capflow/data/repository/accountRepository.dart';

/// Список скрытых (архивных) счетов с возможностью восстановления.
/// Счётчик архивных записей может быть большим — список ленивый
/// (ListView.builder), а экран отдельный, чтобы не раздувать настройки.
class ArchivedAccountsScreen extends StatefulWidget {
  const ArchivedAccountsScreen({super.key});

  @override
  State<ArchivedAccountsScreen> createState() => _ArchivedAccountsScreenState();
}

class _ArchivedAccountsScreenState extends State<ArchivedAccountsScreen> {
  List<Account> _accounts = <Account>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Account> list = await AccountRepository().getArchivedList();
    if (mounted) {
      setState(() {
        _accounts = list;
        _loading = false;
      });
    }
  }

  Future<void> _restore(Account account) async {
    await AccountRepository().unarchive(account.id);
    await _load();
    if (mounted) {
      Toast.show(context, 'Счёт «${account.name}» восстановлен');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Архивные счета')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Нет скрытых счетов.\nСкрытые счета сохраняют данные '
                  'и не входят в общий баланс.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (BuildContext context, int index) {
                final Account account = _accounts[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    account.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Скрыт'),
                  trailing: TextButton(
                    onPressed: () => _restore(account),
                    child: const Text('Восстановить'),
                  ),
                );
              },
            ),
    );
  }
}
