import 'package:investflow/data/models/tools/typed_tool.dart';

/// Operations allowed on a tool, by kind.
enum ToolOperationType {
  topUp,
  withdraw,
  interestPayout,
  mature, // закрытие депозита в конце срока
  creditPayment, // плановый платёж (проценты + тело)
  earlyRepayment,
  manualRevalue,
  buy,
  sell,
  transferIn,
  transferOut,
}

/// Operations available for a typed tool. Several tools of the same kind may
/// exist on an account — nothing here depends on tool identity.
Set<ToolOperationType> allowedOperations(TypedTool tool) {
  return switch (tool) {
    MoneyTool() => <ToolOperationType>{
      ToolOperationType.topUp,
      ToolOperationType.withdraw,
      ToolOperationType.transferIn,
      ToolOperationType.transferOut,
    },
    DepositTool() => <ToolOperationType>{
      ToolOperationType.topUp,
      ToolOperationType.withdraw,
      ToolOperationType.interestPayout,
      ToolOperationType.mature,
    },
    CreditTool() => <ToolOperationType>{
      ToolOperationType.creditPayment,
      ToolOperationType.earlyRepayment,
    },
    SecurityTool() => <ToolOperationType>{
      ToolOperationType.buy,
      ToolOperationType.sell,
    },
    OtherTool() => <ToolOperationType>{ToolOperationType.manualRevalue},
  };
}

/// Transfers are only allowed between cash instruments.
bool canAcceptTransfer(TypedTool tool) => tool is MoneyTool;
