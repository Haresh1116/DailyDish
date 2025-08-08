import 'dart:io'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  // Initialize Supabase and OneSignal
  await Supabase.initialize(
    url:'https://wbtbxdwybohrtyehchbk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndidGJ4ZHd5Ym9ocnR5ZWhjaGJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3Nzg4MTIsImV4cCI6MjA2OTM1NDgxMn0.h0UKSLSLhQMnroKjz1EW8XehxT8fJP1hEjzzY5FUOHI',
  );
  
  OneSignal.initialize('5ec25e78-e4fa-4a0d-af4e-6ba08e3352d9');
  // [NEW] Use the Rest API Key from the environment variable provided by GitHub Actions.
  // This is a secure way to access your key.
  final oneSignalRestApiKey = Platform.environment['os_v2_app_l3bf46he7jfa3l2onoqi4m2s3esjuggw3vwedqmvgyxd25kew6ti5367tipotbqopduovq7bemhdxwspvuu3vve7qzkmdcetenguhgi'];

  final supabase = Supabase.instance.client;
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final tomorrowDayTableName = days[tomorrow.weekday % 7];
  final tomorrowDate = DateFormat('yyyy-MM-dd').format(tomorrow);

  try {
    // Fetch all pending orders for tomorrow
    final List<dynamic> orders = await supabase
        .from('orders')
        .select('*, students(onesignal_player_id)')
        .eq('delivery_date', tomorrowDate)
        .eq('status', 'Pending');
    
    // Create a list of confirmed dishes for tomorrow
    final List<dynamic> confirmedDishes = await supabase
        .from(tomorrowDayTableName)
        .select('id, dish_name')
        .gte('pre_order_count', 10);
    
    final confirmedDishIds = confirmedDishes.map((dish) => dish['id']).toList();
    
    for (var order in orders) {
      final oneSignalPlayerId = order['students']['onesignal_player_id'] as String?;
      final dishName = order['dish_name'] as String;
      final dishId = order['dish_id'] as String;

      if (oneSignalPlayerId == null) continue;

      if (confirmedDishIds.contains(dishId)) {
        // Dish is confirmed
        OneSignal.Notifications.postNotification(
            OneSignal.Notification(
              playerIds: [oneSignalPlayerId],
              heading: OneSignal.NotificationTitle('Order Confirmed!'),
              content: OneSignal.NotificationContent('Your order for $dishName is confirmed for tomorrow. Enjoy your food!'),
            )
        );
      } else {
        // Dish is not confirmed
        OneSignal.Notifications.postNotification(
            OneSignal.Notification(
              playerIds: [oneSignalPlayerId],
              heading: OneSignal.NotificationTitle('Order Canceled'),
              content: OneSignal.NotificationContent('Sorry, your order for $dishName did not meet the minimum orders count and has been canceled.'),
            )
        );
        // Also update the order status in Supabase
        await supabase
            .from('orders')
            .update({'status': 'Cancelled'})
            .eq('order_id', order['order_id']);
      }
    }
  } catch (e) {
    print('Error during scheduled notification run: $e');
  }
}
