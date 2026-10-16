import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/scaffold.dart';
import 'package:investflow/core/theme/appTheme.dart';
import 'package:investflow/core/theme/theme_cubit.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/presentation/accountsScreen.dart';
import 'package:investflow/feature/tool_detail/presentation/tool_detail_screen.dart';
import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:investflow/feature/activity/presentation/detailScreen.dart';
import 'package:investflow/feature/activity/presentation/listScreen.dart';
import 'package:go_router/go_router.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/presentation/eventListScreen.dart';
import 'package:investflow/feature/report/logic/bloc.dart';
import 'package:investflow/feature/report/presentation/screen.dart';

import 'package:investflow/feature/auth/logic/auth_session.dart';
import 'package:investflow/feature/settings/presentation/settings_screen.dart';
import 'package:investflow/feature/auth/presentation/sign_in_screen.dart';
import 'package:investflow/core/widgets/fade_transition_page.dart';

final appShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app shell');

class InvestApp extends StatefulWidget {
  /// Счётчик полных перезапусков UI (после восстановления БД).
  static final ValueNotifier<int> restartSignal = ValueNotifier<int>(0);

  final ThemeCubit themeCubit;

  const InvestApp({super.key, required this.themeCubit});

  @override
  State<InvestApp> createState() => _InvestAppState();
}

class _InvestAppState extends State<InvestApp> {
  final AuthSession auth = AuthSession();

  /// Время последнего свайпа «назад» на главном экране (окно выхода 2 с).
  DateTime? _lastBackAt;

  // Роутер создаётся один раз: пересоздание при смене темы сбрасывало
  // навигацию на начальный экран. Пересоздаётся только при рестарте
  // приложения (например, после восстановления базы из копии).
  GoRouter _router = GoRouter(routes: <RouteBase>[]);
  int _routerRestartCount = -1;

  GoRouter _routerFor(int restartCount) {
    if (_routerRestartCount != restartCount) {
      _router = _createRouter();
      _routerRestartCount = restartCount;
    }
    return _router;
  }

  GoRouter _createRouter() {
    return GoRouter(
      refreshListenable: auth,
      debugLogDiagnostics: true,
      initialLocation: '/accounts',
      redirect: (BuildContext context, GoRouterState state) {
        final bool signedIn = AuthSession.of(context).signedIn;
        if (state.uri.toString() != '/sign-in' && !signedIn) {
          return '/sign-in';
        }
        return null;
      },
      routes: <RouteBase>[
        ShellRoute(
          navigatorKey: appShellNavigatorKey,
          builder: (
            BuildContext context,
            GoRouterState state,
            Widget child,
          ) {
            return InvestflowScaffold(
              selectedIndex: switch (state.uri.path) {
                var p when p.startsWith('/accounts') => 0,
                var p when p.startsWith('/activities') => 1,
                var p when p.startsWith('/settings') => 2,
                _ => 0,
              },
              child: PopScope(
                // Свайп «назад»: настройки и активность ведут на главный
                // экран; с аккаунтов — двойной свайп с предупреждением.
                canPop: false,
                onPopInvokedWithResult: (bool didPop, Object? result) {
                  if (didPop) return;
                  if (state.uri.path.startsWith('/settings') ||
                      state.uri.path.startsWith('/activities')) {
                    _lastBackAt = null;
                    GoRouter.of(context).go('/accounts');
                    return;
                  }
                  // Главный экран: первый свайп — подсказка, второй — выход.
                  final DateTime now = DateTime.now();
                  if (_lastBackAt != null &&
                      now.difference(_lastBackAt!) <
                          const Duration(seconds: 2)) {
                    SystemNavigator.pop();
                  } else {
                    _lastBackAt = now;
                    Toast.show(context, 'Свайпните ещё раз, чтобы выйти');
                  }
                },
                child: child,
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/accounts',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return FadeTransitionPage<dynamic>(
                  key: state.pageKey,
                  child: BlocProvider(
                    create: (BuildContext context) => AccountsBloc(),
                    child: AccountListScreen(),
                  ),
                );
              },
              routes: <RouteBase>[
                GoRoute(
                  path: '/:accountId/events',
                  pageBuilder: (BuildContext context, GoRouterState state) {
                    final String accountId = state.pathParameters['accountId']!;
                    return FadeTransitionPage<dynamic>(
                      key: state.pageKey,
                      child: BlocProvider(
                        create: (BuildContext context) => FinancialEventBloc(),
                        child: FinancialEventOverviewPage(accountId: accountId),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: '/:accountId/report',
                  pageBuilder: (BuildContext context, GoRouterState state) {
                    final String accountId = state.pathParameters['accountId']!;
                    return FadeTransitionPage<dynamic>(
                      key: state.pageKey,
                      child: BlocProvider(
                        create: (BuildContext context) => ReportBloc(),
                        child: ReportScreen(accountId: accountId),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: '/:accountId/tools/:toolId',
                  pageBuilder: (BuildContext context, GoRouterState state) {
                    final String accountId = state.pathParameters['accountId']!;
                    final String toolId = state.pathParameters['toolId']!;
                    return FadeTransitionPage<dynamic>(
                      key: state.pageKey,
                      child: ToolDetailScreen(
                        accountId: accountId,
                        toolId: toolId,
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/activities',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return FadeTransitionPage<dynamic>(
                  key: state.pageKey,
                  child: BlocProvider(
                    create: (BuildContext context) => ActivityBloc(),
                    child: ActivityListScreen(),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/activities/:id',
              pageBuilder: (BuildContext context, GoRouterState state) {
                final String activityId = state.pathParameters['id']!;
                return FadeTransitionPage<dynamic>(
                  key: state.pageKey,
                  child: BlocProvider(
                    create: (BuildContext context) => ActivityBloc(),
                    child: ActivityDetailScreen(activityId: activityId),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return FadeTransitionPage<dynamic>(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/sign-in',
          builder: (BuildContext context, GoRouterState state) {
            return Builder(
              builder: (BuildContext context) {
                return SignInScreen(
                  onSignIn: (value) async {
                    final GoRouter router = GoRouter.of(context);
                    await AuthSession.of(
                      context,
                    ).signIn(value.username, value.password);
                    router.go('/accounts');
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: widget.themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (BuildContext context, ThemeMode themeMode) {
          return ValueListenableBuilder<int>(
          valueListenable: InvestApp.restartSignal,
          builder: (BuildContext context, int restartCount, Widget? _) {
          return MaterialApp.router(
            key: ValueKey<int>(restartCount),
            routerConfig: _routerFor(restartCount),
            builder: (BuildContext context, Widget? child) {
              if (child == null) {
                throw ('No child in .router constructor builder');
              }
              return AuthSessionScope(notifier: auth, child: child);
            },
            theme: getTheme(Brightness.light),
            darkTheme: getTheme(Brightness.dark),
            themeMode: themeMode,
          );
          },
          );
        },
      ),
    );
  }
}
