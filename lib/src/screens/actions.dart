// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:bookstore/src/bloc/action/action_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class ActionsScreen extends StatelessWidget {
  @override
Widget build(BuildContext context) {
    // Accessing the ActionBloc instance from the context
    final ActionBloc counterBloc = BlocProvider.of<ActionBloc>(context);

    return BlocBuilder<ActionBloc, CounterState>(
      // Rebuilding the UI based on the current state of ActionBloc
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Flutter BLoC Example'),
            backgroundColor: Colors.blue.shade800, 
            foregroundColor: Colors.white, 
          ),
          body: Center(
            // Displaying the current counter value
            child: Text('Counter: ${state.counter}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            onPressed: () {
              // Dispatching an event to increment the counter
              counterBloc.add(CounterIncrementPressed(counter: state.counter));
            },
            child: Icon(Icons.add), 
          ),
        );
      },
    );
  }
}
