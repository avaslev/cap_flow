// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:capflow/feature/activity/logic/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ActivitysScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Accessing the ActivityBloc instance from the context
    final ActivityBloc actionBloc = BlocProvider.of<ActivityBloc>(context);
    actionBloc.add(ActivityListTransitionEvent());

    return Scaffold(
      appBar: AppBar(title: Text('Activitys')),
      body: BlocBuilder<ActivityBloc, ActivityState>(
        // Rebuilding the UI based on the current state of ActivityBloc
        builder: (context, state) {
          if (state is ActivityListLoaded) {
            return ListView.builder(
              itemCount: state.data.length,
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  child: ListTile(
                    title: Text(state.data[index].id.toString()),
                    subtitle: Text(state.data[index].quantity.toString()),
                    trailing: Text(state.data[index].comment ?? ''),
                  ),
                );
              },
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        onPressed: () {
          actionBloc.add(ActivityListTransitionEvent());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

