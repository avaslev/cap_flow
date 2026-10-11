import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/scaffold.dart';
import 'package:investflow/core/theme/appTheme.dart';
import 'package:investflow/core/theme/theme_cubit.dart';
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

import '../src/auth.dart';
import '../src/screens/settings.dart';
import '../src/screens/sign_in.dart';
import '../src/widgets/fade_transition_page.dart';

final appShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app shell');

class InvestApp extends StatefulWidget {
  final ThemeCubit themeCubit;

  const InvestApp({super.key, required this.themeCubit});

  @override
  State<InvestApp> createState() => _InvestAppState();
}

class _InvestAppState extends State<InvestApp> {
  final BookstoreAuth auth = BookstoreAuth();

  // Роутер создаётся один раз: пересоздание при смене темы сбрасывало
  // навигацию на начальный экран.
  late final GoRouter _router = _createRouter();

  GoRouter _createRouter() {
    return GoRouter(
      refreshListenable: auth,
      debugLogDiagnostics: true,
      initialLocation: '/accounts',
      redirect: (BuildContext context, GoRouterState state) {
        final bool signedIn = BookstoreAuth.of(context).signedIn;
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
              child: child,
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
                    await BookstoreAuth.of(
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
          return MaterialApp.router(
            builder: (BuildContext context, Widget? child) {
              if (child == null) {
                throw ('No child in .router constructor builder');
              }
              return BookstoreAuthScope(notifier: auth, child: child);
            },
            theme: getTheme(Brightness.light),
            darkTheme: getTheme(Brightness.dark),
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
