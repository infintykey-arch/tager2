import '../../products/domain/product.dart';

class SaleCartLine {
  const SaleCartLine({required this.product, required this.quantity});

  final Product product;
  final double quantity;

  SaleCartLine withQuantity(double value) =>
      SaleCartLine(product: product, quantity: value);
}
