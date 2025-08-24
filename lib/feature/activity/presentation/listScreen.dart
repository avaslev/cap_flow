// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:bookstore/data/models/activity.dart';
import 'package:bookstore/feature/activity/logic/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';



/// Screen displaying the list of transactions, grouped by day.
class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the ActivityBloc instance from the context
    final ActivityBloc actionBloc = BlocProvider.of<ActivityBloc>(context);
    actionBloc.add(ActivityListTransitionEvent());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        centerTitle: false,
      ),
      body: BlocBuilder<ActivityBloc, ActivityState>(
        // Rebuilding the UI based on the current state of ActivityBloc
        builder: (context, state) {
          if (state is ActivityListLoaded) {
            if (state.grouped.isEmpty) {
              return const Center(
                child: Text('No transactions recorded.'),
              );
            }

            return ListView.builder(
              itemCount: state.grouped.keys.length,
              itemBuilder: (BuildContext context, int index) {
                final DateTime date = state.grouped.keys.elementAt(index);
                final List<Activity> actionsForDay = state.grouped[date]!;

                return _DayGroup(date: date, actions: actionsForDay);
              },
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
    );
  }
}

/// Widget to display a group of actions for a specific day.
class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<Activity> actions;

  const _DayGroup({
    required this.date,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat.yMMMd().format(date); // Formats date like 'Jul 20, 2024'

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            formattedDate,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...actions.map<Widget>((Activity action) => _ActivityListItem(action: action)).toList(),
        const Divider(height: 1.0, indent: 16.0, endIndent: 16.0),
      ],
    );
  }
}


// /// Widget to display a single action item.
class _ActivityListItem extends StatelessWidget {
  final Activity action;

  const _ActivityListItem({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon =Icons.swap_horiz;
    Color iconColor  = Colors.blueGrey;
    String sign  = '';
    Color sumColor  = Colors.blueGrey.shade700;

    switch (action.type) {
      case Type.add:
        icon = Icons.add_circle_outline;
        iconColor = Colors.green;
        sign = '+';
        sumColor = Colors.green.shade700;
        break;
      case Type.substract:
        icon = Icons.remove_circle_outline;
        iconColor = Colors.red;
        sign = '-';
        sumColor = Colors.red.shade700;
        break;
    }

    return InkWell(
      onTap: () {
        context.go('/activities/${action.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    action.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (action.comment != null && action.comment!.isNotEmpty)
                    Text(
                      action.comment!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            Text(
              '$sign${action.sum.toStringAsFixed(2)} ${action.currency.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: sumColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
