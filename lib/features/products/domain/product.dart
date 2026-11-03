class Product {
  const Product({
    this.id,
    required this.name,
    required this.purchasePriceMinor,
    required this.salePriceMinor,
    required this.minimumStock,
    required this.stockOnHand,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final int purchasePriceMinor;
  final int salePriceMinor;
  final double minimumStock;
  final double stockOnHand;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stockOnHand <= minimumStock;

  factory Product.fromDatabaseRow(Map<String, Object?> row) {
    return Product(
      id: row['id'] as int,
      name: row['name'] as String,
      purchasePriceMinor: row['purchase_price_minor'] as int,
      salePriceMinor: row['sale_price_minor'] as int,
      minimumStock: (row['minimum_stock'] as num).toDouble(),
      stockOnHand: (row['stock_on_hand'] as num).toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.quantityDelta,
    required this.sourceType,
    this.note,
    required this.occurredAt,
  });

  final int id;
  final int productId;
  final double quantityDelta;
  final String sourceType;
  final String? note;
  final DateTime occurredAt;

  factory StockMovement.fromDatabaseRow(Map<String, Object?> row) {
    return StockMovement(
      id: row['id'] as int,
      productId: row['product_id'] as int,
      quantityDelta: (row['quantity_delta'] as num).toDouble(),
      sourceType: row['source_type'] as String,
      note: row['note'] as String?,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
    );
  }
}
