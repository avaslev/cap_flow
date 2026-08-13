// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:investflow/core/scaffold.dart';
import 'package:investflow/core/theme/appTheme.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/presentation/accountsScreen.dart';
import 'package:investflow/feature/tool_detail/presentation/tool_detail_screen.dart';
import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:investflow/feature/activity/presentation/detailScreen.dart';
import 'package:investflow/feature/activity/presentation/listScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/presentation/eventListScreen.dart';
import 'package:investflow/feature/report/logic/bloc.dart';
import 'package:investflow/feature/report/presentation/screen.dart';

import '../src/auth.dart';
import '../src/data.dart';
import '../src/screens/author_details.dart';
import '../src/screens/authors.dart';
import '../src/screens/book_details.dart';
import '../src/screens/books.dart';
import '../src/screens/settings.dart';
import '../src/screens/sign_in.dart';
import '../src/widgets/book_list.dart';
import '../src/widgets/fade_transition_page.dart';

final appShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app shell');
final booksNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'books shell');

class InvestApp extends StatefulWidget {
  const InvestApp({super.key});

  @override
  State<InvestApp> createState() => _InvestAppState();
}

class _InvestAppState extends State<InvestApp> {
  final BookstoreAuth auth = BookstoreAuth();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      builder: (context, child) {
        if (child == null) {
          throw ('No child in .router constructor builder');
        }
        return BookstoreAuthScope(notifier: auth, child: child);
      },
      theme: getTheme(context),
      routerConfig: GoRouter(
        refreshListenable: auth,
        debugLogDiagnostics: true,
        initialLocation: '/accounts',
        redirect: (context, state) {
          final signedIn = BookstoreAuth.of(context).signedIn;
          if (state.uri.toString() != '/sign-in' && !signedIn) {
            return '/sign-in';
          }
          return null;
        },
        routes: [
          ShellRoute(
            navigatorKey: appShellNavigatorKey,
            builder: (context, state, child) {
              return InvestflowScaffold(
                selectedIndex: switch (state.uri.path) {
                  var p when p.startsWith('/accounts') => 0,
                  var p when p.startsWith('/books') => 1,
                  var p when p.startsWith('/authors') => 2,
                  var p when p.startsWith('/activities') => 3,
                  var p when p.startsWith('/settings') => 4,
                  _ => 0,
                },
                child: child,
              );
            },
            routes: [
              ShellRoute(
                pageBuilder: (context, state, child) {
                  return FadeTransitionPage<dynamic>(
                    key: state.pageKey,
                    // Use a builder to get the correct BuildContext
                    // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
                    child: Builder(
                      builder: (context) {
                        return BooksScreen(
                          onTap: (idx) {
                            GoRouter.of(context).go(switch (idx) {
                              0 => '/books/popular',
                              1 => '/books/new',
                              2 => '/books/all',
                              _ => '/books/popular',
                            });
                          },
                          selectedIndex: switch (state.uri.path) {
                            var p when p.startsWith('/books/popular') => 0,
                            var p when p.startsWith('/books/new') => 1,
                            var p when p.startsWith('/books/all') => 2,
                            _ => 0,
                          },
                          child: child,
                        );
                      },
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: '/books/popular',
                    pageBuilder: (context, state) {
                      return FadeTransitionPage<dynamic>(
                        // Use a builder to get the correct BuildContext
                        // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
                        key: state.pageKey,
                        child: Builder(
                          builder: (context) {
                            return BookList(
                              books: libraryInstance.popularBooks,
                              onTap: (book) {
                                GoRouter.of(
                                  context,
                                ).go('/books/popular/book/${book.id}');
                              },
                            );
                          },
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'book/:bookId',
                        parentNavigatorKey: appShellNavigatorKey,
                        builder: (context, state) {
                          return BookDetailsScreen(
                            book: libraryInstance.getBook(
                              state.pathParameters['bookId'] ?? '',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: '/books/new',
                    pageBuilder: (context, state) {
                      return FadeTransitionPage<dynamic>(
                        key: state.pageKey,
                        // Use a builder to get the correct BuildContext
                        // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
                        child: Builder(
                          builder: (context) {
                            return BookList(
                              books: libraryInstance.newBooks,
                              onTap: (book) {
                                GoRouter.of(
                                  context,
                                ).go('/books/new/book/${book.id}');
                              },
                            );
                          },
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'book/:bookId',
                        parentNavigatorKey: appShellNavigatorKey,
                        builder: (context, state) {
                          return BookDetailsScreen(
                            book: libraryInstance.getBook(
                              state.pathParameters['bookId'] ?? '',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: '/books/all',
                    pageBuilder: (context, state) {
                      return FadeTransitionPage<dynamic>(
                        key: state.pageKey,
                        // Use a builder to get the correct BuildContext
                        // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
                        child: Builder(
                          builder: (context) {
                            return BookList(
                              books: libraryInstance.allBooks,
                              onTap: (book) {
                                GoRouter.of(
                                  context,
                                ).go('/books/all/book/${book.id}');
                              },
                            );
                          },
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'book/:bookId',
                        parentNavigatorKey: appShellNavigatorKey,
                        builder: (context, state) {
                          return BookDetailsScreen(
                            book: libraryInstance.getBook(
                              state.pathParameters['bookId'] ?? '',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/authors',
                pageBuilder: (context, state) {
                  return FadeTransitionPage<dynamic>(
                    key: state.pageKey,
                    child: Builder(
                      builder: (context) {
                        return AuthorsScreen(
                          onTap: (author) {
                            GoRouter.of(
                              context,
                            ).go('/authors/author/${author.id}');
                          },
                        );
                      },
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'author/:authorId',
                    builder: (context, state) {
                      final author = libraryInstance.allAuthors.firstWhere(
                        (author) =>
                            author.id ==
                            int.parse(state.pathParameters['authorId']!),
                      );
                      // Use a builder to get the correct BuildContext
                      // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
                      return Builder(
                        builder: (context) {
                          return AuthorDetailsScreen(
                            author: author,
                            onBookTapped: (book) {
                              GoRouter.of(
                                context,
                              ).go('/books/all/book/${book.id}');
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/accounts',
                pageBuilder: (context, state) {
                  return FadeTransitionPage<dynamic>(
                    key: state.pageKey,
                    child: BlocProvider(
                      create: (context) => AccountsBloc(),
                      child: AccountListScreen(),
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: '/:accountId/events',
                    pageBuilder: (context, state) {
                      String accountId = state.pathParameters['accountId']!;
                      return FadeTransitionPage<dynamic>(
                        key: state.pageKey,
                        child: BlocProvider(
                          create: (context) => FinancialEventBloc(),
                          child: FinancialEventOverviewPage(accountId: accountId),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: '/:accountId/report',
                    pageBuilder: (context, state) {
                      String accountId = state.pathParameters['accountId']!;
                      return FadeTransitionPage<dynamic>(
                        key: state.pageKey,
                        child: BlocProvider(
                          create: (context) => ReportBloc(),
                          child: ReportScreen(accountId: accountId),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: '/:accountId/tools/:toolId',
                    pageBuilder: (context, state) {
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
                pageBuilder: (context, state) {
                  return FadeTransitionPage<dynamic>(
                    key: state.pageKey,
                    child: BlocProvider(
                      create: (context) => ActivityBloc(),
                      child: ActivityListScreen(),
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/activities/:id',
                pageBuilder: (context, state) {
                  final String activityId = state.pathParameters['id']!;
                  return FadeTransitionPage<dynamic>(
                    key: state.pageKey,
                    child: BlocProvider(
                      create: (context) => ActivityBloc(),
                      child: ActivityDetailScreen(activityId: activityId),
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) {
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
            builder: (context, state) {
              // Use a builder to get the correct BuildContext
              // TODO (johnpryan): remove when https://github.com/flutter/flutter/issues/108177 lands
              return Builder(
                builder: (context) {
                  return SignInScreen(
                    onSignIn: (value) async {
                      final router = GoRouter.of(context);
                      await BookstoreAuth.of(
                        context,
                      ).signIn(value.username, value.password);
                      router.go('/books/popular');
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
