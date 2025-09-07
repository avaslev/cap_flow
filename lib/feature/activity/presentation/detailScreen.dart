// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ActivityDetailScreen extends StatelessWidget {
  final String activityId;

  const ActivityDetailScreen({required this.activityId, super.key});

  @override
  Widget build(BuildContext context) {
    final ActivityBloc actionBloc = BlocProvider.of<ActivityBloc>(context);
    actionBloc.add(ActivityTransitionEvent(activityId: activityId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/activities'); // Navigate back using GoRouter
          },
        ),
      ),
      body: BlocBuilder<ActivityBloc, ActivityState>(
        // Rebuilding the UI based on the current state of ActionBloc
        builder: (context, state) {
          if (state is ActivityLoaded) {

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildDetailRow(context, 'Name:', state.data.name!),
                  _buildDetailRow(context, 'Type:', state.data.type.name),
                  _buildDetailRow(context, 'Amount:', '${state.data.quantity.toStringAsFixed(2)} ${state.data.currency.name}'),
                  _buildDetailRow(context, 'Date:', DateFormat.yMMMd().add_jm().format(state.data.createAt)),
                  if (state.data.comment != null && state.data.comment!.isNotEmpty)
                    _buildDetailRow(context, 'Comment:', state.data.comment!),
                ],
              ),
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      )
    );
  }

    Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80, // Fixed width for labels
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
