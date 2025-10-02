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

    // Expense Categories
    'food': Icons.restaurant,
    'dining': Icons.restaurant,
    'transportation': Icons.directions_car,
    'car': Icons.directions_car,
    'shopping': Icons.shopping_bag,
    'groceries': Icons.shopping_cart,
    'entertainment': Icons.movie,
    'health': Icons.local_hospital,
    'medical': Icons.local_hospital,
    'education': Icons.school,
    'bills': Icons.receipt,
    'utilities': Icons.electrical_services,
    'rent': Icons.home,
    'insurance': Icons.security,
    'fuel': Icons.local_gas_station,
    'phone': Icons.phone,
    'internet': Icons.wifi,
    'clothing': Icons.checkroom,
    'beauty': Icons.face,
    'fitness': Icons.fitness_center,
    'travel': Icons.flight,
    'subscription': Icons.subscriptions,
    'charity': Icons.volunteer_activism,
    'pets': Icons.pets,
    'repairs': Icons.build,
    'tax': Icons.gavel,
    'others': Icons.more_horiz,

    // Common child/sub-category hints (partial matches)
    'sarapan': Icons.free_breakfast,
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
    'skincare': Icons.spa,
    'haircut': Icons.cut,
    'salon': Icons.brush,
    'gym': Icons.fitness_center,
    'grooming': Icons.cut,
    'makanan': Icons.pets,
    'buku': Icons.book,
    'kursus': Icons.school,
    'uang sekolah': Icons.school,
    'biaya admin': Icons.receipt_long,
    'biaya transfer': Icons.swap_horiz,
    'pajak': Icons.gavel,
    'netflix': Icons.subscriptions,
    'spotify': Icons.music_note,
    'icloud': Icons.cloud,
    'youtube': Icons.ondemand_video,
  };

  // Available icons for selection (combination of Material + additional icons)
  static const List<IconData> availableIcons = [
    // Common category icons
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.shopping_cart,
    Icons.movie,
    Icons.local_hospital,
    Icons.school,
    Icons.work,
    Icons.computer,
    Icons.trending_up,
    Icons.business,
    Icons.card_giftcard,
    Icons.home,
    Icons.receipt,
    Icons.electrical_services,
    Icons.security,
    Icons.local_gas_station,
    Icons.phone,
    Icons.wifi,
    Icons.checkroom,
    Icons.face,
    Icons.fitness_center,
    Icons.flight,
    Icons.subscriptions,
    Icons.volunteer_activism,
    Icons.pets,
    Icons.build,
    Icons.gavel,
    Icons.star,
    Icons.account_balance,
    Icons.handyman,

    // Additional useful icons
    Icons.coffee,
    Icons.fastfood,
    Icons.local_pizza,
    Icons.cake,
    Icons.directions_bus,
    Icons.train,
    Icons.two_wheeler,
    Icons.local_taxi,
    Icons.store,
    Icons.local_mall,
    Icons.sports_esports,
    Icons.music_note,
    Icons.book,
    Icons.laptop,
    Icons.smartphone,
    Icons.tv,
    Icons.sports,
    Icons.beach_access,
    Icons.camera_alt,
    Icons.palette,
    Icons.brush,
    Icons.cut,
    Icons.spa,
    Icons.child_care,
    Icons.elderly,
    Icons.medical_services,
    Icons.local_pharmacy,
    Icons.more_horiz,
    Icons.category,
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

  // Get icon from stored icon data (from database)
  static IconData getIconFromCodePoint(int? codePoint) {
    if (codePoint == null) return Icons.category;

    // Try to find a matching constant icon first
    for (final iconData in _categoryIcons.values) {
      if (iconData.codePoint == codePoint) {
        return iconData;
      }
    }

    // Common Material Icons fallback mapping for known codePoints
    final knownIcons = <int, IconData>{
      Icons.category.codePoint: Icons.category,
      Icons.work.codePoint: Icons.work,
      Icons.restaurant.codePoint: Icons.restaurant,
      Icons.directions_car.codePoint: Icons.directions_car,
      Icons.shopping_bag.codePoint: Icons.shopping_bag,
      Icons.movie.codePoint: Icons.movie,
      Icons.local_hospital.codePoint: Icons.local_hospital,
      Icons.school.codePoint: Icons.school,
      Icons.receipt.codePoint: Icons.receipt,
      Icons.home.codePoint: Icons.home,
      Icons.trending_up.codePoint: Icons.trending_up,
      Icons.business.codePoint: Icons.business,
      Icons.card_giftcard.codePoint: Icons.card_giftcard,
      Icons.star.codePoint: Icons.star,
      Icons.account_balance.codePoint: Icons.account_balance,
      Icons.handyman.codePoint: Icons.handyman,
      Icons.shopping_cart.codePoint: Icons.shopping_cart,
      Icons.electrical_services.codePoint: Icons.electrical_services,
      Icons.security.codePoint: Icons.security,
      Icons.local_gas_station.codePoint: Icons.local_gas_station,
      Icons.phone.codePoint: Icons.phone,
      Icons.wifi.codePoint: Icons.wifi,
      Icons.checkroom.codePoint: Icons.checkroom,
      Icons.face.codePoint: Icons.face,
      Icons.fitness_center.codePoint: Icons.fitness_center,
      Icons.flight.codePoint: Icons.flight,
      Icons.subscriptions.codePoint: Icons.subscriptions,
      Icons.volunteer_activism.codePoint: Icons.volunteer_activism,
      Icons.pets.codePoint: Icons.pets,
      Icons.build.codePoint: Icons.build,
      Icons.gavel.codePoint: Icons.gavel,
      Icons.more_horiz.codePoint: Icons.more_horiz,
    };

    return knownIcons[codePoint] ?? Icons.category;
  }

  // Convert IconData to codePoint for storage
  static int getCodePointFromIcon(IconData icon) {
    return icon.codePoint;
  }

  // Get icon display name for UI
  static String getIconName(IconData icon) {
    // You can create a reverse mapping or use a more sophisticated approach
    for (final entry in _categoryIcons.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key.replaceAll('_', ' ').toUpperCase();
      }
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
