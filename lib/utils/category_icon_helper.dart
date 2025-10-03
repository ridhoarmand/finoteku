import 'package:flutter/material.dart';

class CategoryIconHelper {
  // Predefined category icons mapping
  static const Map<String, IconData> _categoryIcons = {
    // Income Categories
    'salary': Icons.work,
    'freelance': Icons.computer,
    'investment': Icons.trending_up,
    'business': Icons.business,
    'gift': Icons.card_giftcard,
    'bonus': Icons.star,
    'dividend': Icons.account_balance,
    'rental': Icons.home,
    'side_hustle': Icons.handyman,
    'part_time': Icons.schedule,
    'consulting': Icons.psychology,
    'commission': Icons.sell,
    'royalty': Icons.music_note,
    'interest': Icons.savings,

    // Expense Categories - Food & Dining
    'food': Icons.restaurant,
    'dining': Icons.restaurant,
    'groceries': Icons.local_grocery_store,
    'restaurant': Icons.local_dining,
    'fast_food': Icons.fastfood,
    'coffee': Icons.coffee,
    'bakery': Icons.cake,
    'snacks': Icons.icecream,
    'delivery': Icons.delivery_dining,
    'breakfast': Icons.breakfast_dining,
    'lunch': Icons.lunch_dining,
    'dinner': Icons.dinner_dining,
    'pizza': Icons.local_pizza,

    // Transportation
    'transportation': Icons.directions_car,
    'car': Icons.directions_car,
    'fuel': Icons.local_gas_station,
    'taxi': Icons.local_taxi,
    'train': Icons.train,
    'bus': Icons.directions_bus,
    'motorcycle': Icons.motorcycle,
    'bike': Icons.pedal_bike,
    'flight': Icons.flight,
    'subway': Icons.directions_subway,
    'parking': Icons.local_parking,

    // Shopping & Personal
    'shopping': Icons.shopping_bag,
    'mall': Icons.local_mall,
    'clothing': Icons.checkroom,
    'beauty': Icons.face,
    'skincare': Icons.spa,
    'haircut': Icons.content_cut,
    'laundry': Icons.local_laundry_service,
    'dry_cleaning': Icons.dry_cleaning,

    // Entertainment & Lifestyle
    'entertainment': Icons.movie,
    'movie': Icons.movie,
    'gaming': Icons.sports_esports,
    'music': Icons.music_note,
    'sports': Icons.sports_soccer,
    'fitness': Icons.fitness_center,
    'gym': Icons.fitness_center,
    'travel': Icons.flight,
    'vacation': Icons.beach_access,
    'hobby': Icons.palette,

    // Health & Medical
    'health': Icons.local_hospital,
    'medical': Icons.medical_services,
    'doctor': Icons.local_hospital,
    'pharmacy': Icons.local_pharmacy,
    'hospital': Icons.emergency,
    'medicine': Icons.medication,
    'therapy': Icons.psychology,
    'dental': Icons.healing,
    'checkup': Icons.medical_information,

    // Education & Learning
    'education': Icons.school,
    'books': Icons.menu_book,
    'course': Icons.auto_stories,
    'training': Icons.science,
    'school': Icons.school,
    'university': Icons.school,
    'tuition': Icons.calculate,

    // Bills & Utilities
    'bills': Icons.receipt,
    'utilities': Icons.electrical_services,
    'electricity': Icons.electric_bolt,
    'water': Icons.water_drop,
    'internet': Icons.wifi,
    'phone': Icons.phone,
    'gas': Icons.gas_meter,
    'rent': Icons.home,
    'mortgage': Icons.apartment,
    'insurance': Icons.security,

    // Family & Personal Care
    'pets': Icons.pets,
    'baby': Icons.baby_changing_station,
    'childcare': Icons.child_friendly,
    'elderly_care': Icons.elderly,
    'personal_care': Icons.self_improvement,
    'charity': Icons.volunteer_activism,

    // Finance & Banking
    'bank': Icons.account_balance,
    'atm': Icons.local_atm,
    'credit_card': Icons.credit_card,
    'loan': Icons.payment,
    'investment_fee': Icons.assessment,
    'transfer': Icons.swap_horiz,
    'exchange': Icons.currency_exchange,

    // Home & Maintenance
    'home_maintenance': Icons.handyman,
    'repairs': Icons.build,
    'cleaning': Icons.cleaning_services,
    'gardening': Icons.local_florist,
    'plumbing': Icons.plumbing,
    'electrical': Icons.electrical_services,

    // Subscriptions & Services
    'subscription': Icons.subscriptions,
    'software': Icons.computer,

    // Miscellaneous
    'tax': Icons.gavel,
    'gift_giving': Icons.card_giftcard,
    'celebration': Icons.celebration,
    'office_supplies': Icons.inventory_2,
    'others': Icons.more_horiz,
    'miscellaneous': Icons.category,

    // Common Indonesian terms
    'sarapan': Icons.breakfast_dining,
    'makan siang': Icons.lunch_dining,
    'makan malam': Icons.dinner_dining,
    'kopi': Icons.coffee,
    'camilan': Icons.icecream,
    'pesan antar': Icons.delivery_dining,
    'sayur': Icons.grass,
    'buah': Icons.apple,
    'vitamin': Icons.medication,
    'dokter': Icons.local_hospital,
    'vaksin': Icons.vaccines,
    'tiket': Icons.airplane_ticket,
    'hotel': Icons.hotel,
    'oleh-oleh': Icons.card_giftcard,
    'bioskop': Icons.movie,
    'game': Icons.sports_esports,
    'musik': Icons.music_note,
    'event': Icons.event,
    'salon': Icons.content_cut,
    'grooming': Icons.content_cut,
    'makanan': Icons.pets,
    'buku': Icons.book,
    'kursus': Icons.school,
    'uang sekolah': Icons.school,
    'biaya admin': Icons.receipt_long,
    'biaya transfer': Icons.swap_horiz,
    'pajak': Icons.gavel,
    'netflix_id': Icons.ondemand_video,
    'spotify_id': Icons.music_note,
    'youtube': Icons.ondemand_video,
  };

  // Available icons for selection (comprehensive list matching CategoryIconPicker)
  static const List<IconData> availableIcons = [
    // Food & Dining
    Icons.restaurant,
    Icons.local_grocery_store,
    Icons.fastfood,
    Icons.coffee,
    Icons.cake,
    Icons.local_dining,
    Icons.lunch_dining,
    Icons.breakfast_dining,
    Icons.dinner_dining,
    Icons.local_pizza,
    Icons.icecream,
    Icons.delivery_dining,
    Icons.free_breakfast,
    Icons.takeout_dining,
    Icons.bakery_dining,
    Icons.ramen_dining,
    Icons.rice_bowl,
    Icons.set_meal,

    // Transportation
    Icons.directions_car,
    Icons.local_gas_station,
    Icons.local_taxi,
    Icons.train,
    Icons.directions_bus,
    Icons.motorcycle,
    Icons.pedal_bike,
    Icons.flight,
    Icons.directions_subway,
    Icons.local_parking,
    Icons.local_shipping,
    Icons.airport_shuttle,
    Icons.electric_car,
    Icons.car_rental,
    Icons.commute,
    Icons.two_wheeler,

    // Housing & Utilities
    Icons.home,
    Icons.apartment,
    Icons.electric_bolt,
    Icons.water_drop,
    Icons.wifi,
    Icons.phone,
    Icons.gas_meter,
    Icons.heat_pump,
    Icons.ac_unit,
    Icons.router,
    Icons.lightbulb,
    Icons.thermostat,
    Icons.security,
    Icons.house,
    Icons.cottage,

    // Health & Medical
    Icons.medical_services,
    Icons.local_pharmacy,
    Icons.local_hospital,
    Icons.psychology,
    Icons.fitness_center,
    Icons.spa,
    Icons.medical_information,
    Icons.emergency,
    Icons.healing,
    Icons.medication,
    Icons.vaccines,
    Icons.monitor_heart,
    Icons.health_and_safety,

    // Education & Learning
    Icons.school,
    Icons.menu_book,
    Icons.library_books,
    Icons.auto_stories,
    Icons.calculate,
    Icons.science,
    Icons.computer,
    Icons.laptop,
    Icons.tablet,
    Icons.book,
    Icons.quiz,
    Icons.class_,
    Icons.school_outlined,

    // Shopping & Personal
    Icons.shopping_bag,
    Icons.shopping_cart,
    Icons.local_mall,
    Icons.checkroom,
    Icons.dry_cleaning,
    Icons.local_laundry_service,
    Icons.content_cut,
    Icons.face,
    Icons.style,
    Icons.watch,
    Icons.diamond,
    Icons.shopping_basket,
    Icons.local_offer,
    Icons.storefront,

    // Entertainment & Lifestyle
    Icons.movie,
    Icons.sports_esports,
    Icons.music_note,
    Icons.theater_comedy,
    Icons.sports_soccer,
    Icons.sports_basketball,
    Icons.sports_tennis,
    Icons.pool,
    Icons.hiking,
    Icons.beach_access,
    Icons.camera_alt,
    Icons.photo_camera,
    Icons.videocam,
    Icons.sports,
    Icons.sports_golf,
    Icons.sports_baseball,
    Icons.sports_football,
    Icons.sports_volleyball,
    Icons.surfing,
    Icons.snowboarding,
    Icons.downhill_skiing,
    Icons.kayaking,
    Icons.sailing,
    Icons.paragliding,

    // Family & Personal Care
    Icons.pets,
    Icons.baby_changing_station,
    Icons.child_friendly,
    Icons.elderly,
    Icons.accessible,
    Icons.pregnant_woman,
    Icons.personal_injury,
    Icons.self_improvement,
    Icons.volunteer_activism,
    Icons.favorite,
    Icons.child_care,
    Icons.stroller,

    // Bills & Finance
    Icons.receipt_long,
    Icons.payment,
    Icons.credit_card,
    Icons.account_balance,
    Icons.local_atm,
    Icons.savings,
    Icons.currency_exchange,
    Icons.attach_money,
    Icons.price_check,
    Icons.receipt,
    Icons.euro_symbol,
    Icons.currency_yen,
    Icons.currency_pound,
    Icons.account_balance_wallet,

    // Work & Employment
    Icons.work,
    Icons.business,
    Icons.business_center,
    Icons.work_outline,
    Icons.badge,
    Icons.engineering,
    Icons.construction,
    Icons.architecture,
    Icons.design_services,
    Icons.support_agent,
    Icons.monetization_on,
    Icons.trending_up,
    Icons.sell,
    Icons.price_change,
    Icons.inventory,
    Icons.store,
    Icons.point_of_sale,
    Icons.campaign,
    Icons.handshake,
    Icons.groups,

    // Technology & Communication
    Icons.smartphone,
    Icons.tablet_mac,
    Icons.desktop_mac,
    Icons.headphones,
    Icons.speaker,
    Icons.tv,
    Icons.games,
    Icons.mouse,
    Icons.keyboard,
    Icons.cable,
    Icons.cloud,
    Icons.web,
    Icons.code,
    Icons.developer_mode,
    Icons.api,

    // Hobbies & Interests
    Icons.palette,
    Icons.brush,
    Icons.piano,
    Icons.audiotrack,
    Icons.casino,
    Icons.extension,
    Icons.toys,
    Icons.sports_handball,
    Icons.format_paint,

    // Gifts & Rewards
    Icons.card_giftcard,
    Icons.redeem,
    Icons.celebration,
    Icons.star,
    Icons.military_tech,
    Icons.emoji_events,
    Icons.workspace_premium,

    // Analytics & Reports
    Icons.assessment,
    Icons.bar_chart,
    Icons.show_chart,
    Icons.pie_chart,
    Icons.analytics,
    Icons.auto_graph,
    Icons.insights,
    Icons.track_changes,
    Icons.query_stats,
    Icons.timeline,
    Icons.format_list_numbered,
    Icons.checklist,
    Icons.task_alt,

    // Services & Maintenance
    Icons.build,
    Icons.handyman,
    Icons.plumbing,
    Icons.electrical_services,
    Icons.cleaning_services,
    Icons.local_florist,
    Icons.inventory_2,
    Icons.agriculture,
    Icons.grass,
    Icons.yard,
    Icons.eco,
    Icons.recycling,
    Icons.nature,
    Icons.park,
    Icons.forest,

    // Passive Income & Investment
    Icons.autorenew,
    Icons.repeat,
    Icons.schedule,
    Icons.access_time,
    Icons.update,
    Icons.sync,
    Icons.landscape,
    Icons.foundation,

    // Common Categories
    Icons.category,
    Icons.more_horiz,
    Icons.event,
  ];

  // Get icon for category name (auto-detection)
  static IconData getIconForCategory(String categoryName) {
    final lowerName = categoryName.toLowerCase();

    // Direct match first
    if (_categoryIcons.containsKey(lowerName)) {
      return _categoryIcons[lowerName]!;
    }

    // Partial match
    for (final entry in _categoryIcons.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default icon
    return Icons.category;
  }

  // Inherit icon from parent if child has no explicit icon selection
  static IconData inheritIcon({
    required IconData? childIcon,
    required String parentName,
  }) {
    if (childIcon != null) return childIcon;
    return getIconForCategory(parentName);
  }

  // Get icon from stored codePoint (tree-shake friendly)
  static IconData getIconFromCodePoint(int? codePoint) {
    if (codePoint == null) return Icons.category;

    // Find matching icon from our predefined list
    for (final icon in availableIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }

    // If not found in available icons, check category icons mapping
    for (final icon in _categoryIcons.values) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }

    // Fallback to default category icon
    return Icons.category;
  }

  // Convert IconData to codePoint for storage
  static int getCodePointFromIcon(IconData icon) {
    return icon.codePoint;
  }

  // Debug method to check if icon exists in our mappings
  static bool isIconSupported(int codePoint) {
    // Check in availableIcons
    for (final iconData in availableIcons) {
      if (iconData.codePoint == codePoint) {
        return true;
      }
    }

    // Check in category icons
    for (final iconData in _categoryIcons.values) {
      if (iconData.codePoint == codePoint) {
        return true;
      }
    }

    return false;
  }

  // Get all supported codePoints for debugging
  static Set<int> getAllSupportedCodePoints() {
    final Set<int> codePoints = {};

    // Add from availableIcons
    for (final icon in availableIcons) {
      codePoints.add(icon.codePoint);
    }

    // Add from category icons
    for (final icon in _categoryIcons.values) {
      codePoints.add(icon.codePoint);
    }

    return codePoints;
  }

  // Get icon display name for UI
  static String getIconName(IconData icon) {
    // Check in category icons mapping first
    for (final entry in _categoryIcons.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key.replaceAll('_', ' ').toUpperCase();
      }
    }

    // Check if it's in availableIcons and provide common names
    final commonIconNames = <int, String>{
      Icons.coffee.codePoint: 'COFFEE',
      Icons.fastfood.codePoint: 'FAST FOOD',
      Icons.local_pizza.codePoint: 'PIZZA',
      Icons.cake.codePoint: 'CAKE',
      Icons.directions_bus.codePoint: 'BUS',
      Icons.train.codePoint: 'TRAIN',
      Icons.two_wheeler.codePoint: 'MOTORCYCLE',
      Icons.local_taxi.codePoint: 'TAXI',
      Icons.store.codePoint: 'STORE',
      Icons.local_mall.codePoint: 'MALL',
      Icons.sports_esports.codePoint: 'GAMING',
      Icons.music_note.codePoint: 'MUSIC',
      Icons.book.codePoint: 'BOOK',
      Icons.laptop.codePoint: 'LAPTOP',
      Icons.smartphone.codePoint: 'SMARTPHONE',
      Icons.tv.codePoint: 'TV',
      Icons.sports.codePoint: 'SPORTS',
      Icons.beach_access.codePoint: 'BEACH',
      Icons.camera_alt.codePoint: 'CAMERA',
      Icons.palette.codePoint: 'PALETTE',
      Icons.brush.codePoint: 'BRUSH',
      Icons.cut.codePoint: 'CUT',
      Icons.spa.codePoint: 'SPA',
      Icons.child_care.codePoint: 'CHILD CARE',
      Icons.elderly.codePoint: 'ELDERLY',
      Icons.medical_services.codePoint: 'MEDICAL',
      Icons.local_pharmacy.codePoint: 'PHARMACY',
    };

    if (commonIconNames.containsKey(icon.codePoint)) {
      return commonIconNames[icon.codePoint]!;
    }

    return 'CUSTOM';
  }

  // Build icon selection grid widget
  static Widget buildIconSelectionGrid({
    required IconData? selectedIcon,
    required Function(IconData) onIconSelected,
    double iconSize = 32.0,
  }) {
    return Builder(
      builder: (context) {
        return SizedBox(
          height: 180, // Reduced height to prevent overflow
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: availableIcons.length,
            itemBuilder: (context, index) {
              final icon = availableIcons[index];
              final isSelected = selectedIcon?.codePoint == icon.codePoint;

              return GestureDetector(
                onTap: () => onIconSelected(icon),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Build icon widget with proper styling
  static Widget buildCategoryIcon(
    IconData? icon, {
    double size = 24.0,
    Color? color,
    Color? backgroundColor,
  }) {
    final displayIcon = icon ?? Icons.category;

    if (backgroundColor != null) {
      return CircleAvatar(
        backgroundColor: backgroundColor,
        radius: size,
        child: Icon(displayIcon, size: size * 0.6, color: color),
      );
    }

    return Icon(displayIcon, size: size, color: color);
  }
}
