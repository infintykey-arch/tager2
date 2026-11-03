import 'package:flutter/widgets.dart';

import 'app/tager_app.dart';
import 'data/local/app_database.dart';
import 'features/products/data/products_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = await AppDatabase.open();
  final productsRepository = SqliteProductsRepository(appDatabase.database);
  runApp(TagerApp(productsRepository: productsRepository));
}
