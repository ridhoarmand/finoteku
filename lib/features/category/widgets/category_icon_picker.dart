import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';
import '../theme/category_theme.dart';

class CategoryIconPicker extends ConsumerWidget {
  final IconData? selectedIcon;
  final Function(IconData?) onIconSelected;
  final CategoryType categoryType;

  const CategoryIconPicker({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
    required this.categoryType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryColor = CategoryTheme.forType(categoryType);

    // Icon options based on category type
    final List<IconData> iconOptions = categoryType == CategoryType.expense
        ? _expenseIcons
        : _incomeIcons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Icon Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  selectedIcon ?? _getDefaultIcon(categoryType),
                  color: categoryColor,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedIcon != null
                      ? ref.tr(context, 'icon_selected')
                      : ref.tr(context, 'no_icon_selected'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (selectedIcon != null)
                InkWell(
                  onTap: () => onIconSelected(null),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.clear, size: 16),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Icon Grid
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: iconOptions.length,
            itemBuilder: (context, index) {
              final icon = iconOptions[index];
              final isSelected = selectedIcon == icon;

              return GestureDetector(
                onTap: () => onIconSelected(icon),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? categoryColor
                          : theme.dividerColor.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? categoryColor
                        : theme.iconTheme.color?.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getDefaultIcon(CategoryType type) {
    return type == CategoryType.expense
        ? Icons.trending_down
        : Icons.trending_up;
  }

  static const List<IconData> _expenseIcons = [
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

    // Hobbies & Interests
    Icons.palette,
    Icons.brush,
    Icons.piano,
    Icons.music_note,
    Icons.audiotrack,
    Icons.casino,
    Icons.extension,
    Icons.toys,
    Icons.sports_handball,
    Icons.format_paint,

    // Miscellaneous
    Icons.local_florist,
    Icons.celebration,
    Icons.card_giftcard,
    Icons.redeem,
    Icons.inventory_2,
    Icons.build,
    Icons.handyman,
    Icons.plumbing,
    Icons.electrical_services,
    Icons.cleaning_services,
    Icons.agriculture,
    Icons.grass,
    Icons.yard,
    Icons.eco,
    Icons.recycling,
    Icons.nature,
    Icons.park,
    Icons.forest,
  ];

  static const List<IconData> _incomeIcons = [
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

    // Finance & Investment
    Icons.monetization_on,
    Icons.account_balance,
    Icons.trending_up,
    Icons.attach_money,
    Icons.savings,
    Icons.credit_card,
    Icons.local_atm,
    Icons.payment,
    Icons.currency_exchange,
    Icons.euro_symbol,
    Icons.currency_yen,
    Icons.currency_pound,
    Icons.price_change,
    Icons.account_balance_wallet,

    // Business & Sales
    Icons.sell,
    Icons.store,
    Icons.storefront,
    Icons.shopping_cart,
    Icons.point_of_sale,
    Icons.inventory,
    Icons.local_offer,
    Icons.campaign,
    Icons.handshake,
    Icons.groups,

    // Gifts & Rewards
    Icons.card_giftcard,
    Icons.redeem,
    Icons.celebration,
    Icons.cake,
    Icons.star,
    Icons.military_tech,
    Icons.emoji_events,
    Icons.workspace_premium,

    // Analytics & Reports
    Icons.receipt_long,
    Icons.calculate,
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

    // Online & Digital
    Icons.computer,
    Icons.laptop,
    Icons.smartphone,
    Icons.cloud,
    Icons.web,
    Icons.code,
    Icons.developer_mode,
    Icons.api,

    // Investment & Assets
    Icons.home,
    Icons.apartment,
    Icons.directions_car,
    Icons.diamond,
    Icons.landscape,
    Icons.foundation,

    // Freelance & Services
    Icons.design_services,
    Icons.brush,
    Icons.palette,
    Icons.camera_alt,
    Icons.videocam,
    Icons.mic,
    Icons.edit,
    Icons.content_copy,

    // Passive Income
    Icons.autorenew,
    Icons.repeat,
    Icons.schedule,
    Icons.access_time,
    Icons.update,
    Icons.sync,
  ];
}
