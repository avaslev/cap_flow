import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_event.dart';
import 'package:investflow/feature/tool_detail/tool_detail_state.dart';

/// Screen displaying detailed information about a financial tool.
/// Uses a BLoC (`ToolDetailBloc`) to load the tool data instead of a
/// direct `FutureBuilder`. This mirrors the pattern used in the `event`
/// feature (see `eventListScreen.dart`).
class ToolDetailScreen extends StatelessWidget {
  final String accountId;
  final String toolId;

  const ToolDetailScreen({
    super.key,
    required this.accountId,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC and trigger loading as soon as the widget is built.
    return BlocProvider<ToolDetailBloc>(
      create: (_) => ToolDetailBloc()..add(LoadToolDetail(accountId, toolId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tool Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<ToolDetailBloc, ToolDetailState>(
          builder: (context, state) {
            if (state is ToolDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ToolDetailError) {
              return Center(
                child: Text('Error loading tool: ${state.message}'),
              );
            }
            if (state is ToolDetailLoaded) {
              final tool = state.tool;
              // Build a richer UI with the additional fields.
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (tool.ticker != null)
                      Text('Ticker: ${tool.ticker}'),
                    Text('Account ID: ${tool.accountId}'),
                    Text('Type: ${tool.type}'),
                    Text('Quantity: ${tool.quantity.toStringAsFixed(2)}'),
                    Text('Current value: ${tool.currentValue.toStringAsFixed(2)}'),
                    if (tool.faceValue != null)
                      Text('Nominal (face) value: ${tool.faceValue}'),
                    if (tool.interestRate != null)
                      Text('Interest rate: ${tool.interestRate}%'),
                    if (tool.paymentDayOfMonth != null)
                      Text('Payment day of month: ${tool.paymentDayOfMonth}'),
                    const Spacer(),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                    ),
                  ],
                ),
              );
            }
            // Fallback – should never reach here.
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}