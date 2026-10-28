import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/models/tools/typed_tool.dart';

/// Maps DB tool rows to typed domain models and back.
///
/// Kind selection is the only decision made here — no valuation or
/// operation logic lives in the mapping layer.

/// Parses a DB [Tool] row into a typed domain model.
///
/// Throws [ArgumentError] for unknown [Tool.type] values — the DB must only
/// contain known kinds, failing fast protects data integrity.
TypedTool typedToolFromDb(Tool tool) {
  final ToolType kind = ToolType.values.byName(tool.type);
  switch (kind) {
    case ToolType.money:
      return MoneyTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        isClosed: tool.isClosed,
      );
    case ToolType.deposit:
      return DepositTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        interestRate: tool.interestRate ?? 0,
        startDate: tool.startDate ?? DateTime.now(),
        endDate: tool.endDate,
        payoutType: tool.payType == null
            ? null
            : PayoutType.values.byName(tool.payType!),
        withdrawalToolId: null,
        isClosed: tool.isClosed,
      );
    case ToolType.credit:
      return CreditTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        interestRate: tool.interestRate ?? 0,
        loanStartDate: tool.startDate,
        termMonths: tool.termMonths,
        paymentDayOfMonth: tool.paymentDayOfMonth,
        paymentType: tool.payType == null
            ? null
            : CreditPaymentType.values.byName(tool.payType!),
        isClosed: tool.isClosed,
      );
    case ToolType.stocks:
      return StockTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        faceValue: tool.faceValue,
      );
    case ToolType.bonds:
      return BondTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        faceValue: tool.faceValue,
      );
    case ToolType.cryptocurrency:
      return CryptoTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        isClosed: tool.isClosed,
      );
    case ToolType.other:
      return OtherTool(
        id: tool.id,
        accountId: tool.accountId,
        name: tool.name,
        ticker: tool.ticker,
        isClosed: tool.isClosed,
      );
  }
}

/// Converts a typed model back into a DB row. Type-specific fields of other
/// kinds are explicitly nulled so a row never carries metadata of a foreign
/// kind.
Tool typedToolToDb(TypedTool tool, {double? faceValue}) {
  switch (tool) {
    case MoneyTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        isClosed: t.isClosed,
      );
    case DepositTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        startDate: t.startDate,
        endDate: t.endDate,
        payType: t.payoutType?.name,
        interestRate: t.interestRate,
        isClosed: t.isClosed,
      );
    case CreditTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        startDate: t.loanStartDate,
        payType: t.paymentType?.name,
        interestRate: t.interestRate,
        paymentDayOfMonth: t.paymentDayOfMonth,
        termMonths: t.termMonths,
        isClosed: t.isClosed,
      );
    case StockTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        faceValue: t.faceValue ?? faceValue,
        isClosed: t.isClosed,
      );
    case BondTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        faceValue: t.faceValue ?? faceValue,
        isClosed: t.isClosed,
      );
    case CryptoTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        isClosed: t.isClosed,
      );
    case OtherTool t:
      return Tool(
        id: t.id,
        accountId: t.accountId,
        name: t.name,
        type: t.kind.name,
        ticker: t.ticker,
        isClosed: t.isClosed,
      );
  }
}
