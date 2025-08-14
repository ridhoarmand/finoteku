import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/wallet_icon_helper.dart';
// import '../widgets/wallet_sync_status_widget.dart';
// import '../widgets/auto_sync_hook.dart';

class ManageWalletsScreen extends ConsumerWidget {
  const ManageWalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Wallets'),
        actions: [
          // Sync status indicator removed (online-only architecture)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Check if user is authenticated before showing dialog
              final user = currentUser.valueOrNull;
              if (user != null) {
                _showAddWalletDialog(context, ref);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait for authentication to complete'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please login first'));
          }

          final walletsAsync = ref.watch(walletsProvider(user.id));

          return walletsAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return _buildEmptyState(context, ref, user.id);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(walletsProvider(user.id));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    return _buildWalletCard(context, ref, wallet, user.id);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading wallets',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(walletsProvider(user.id)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Authentication Error', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String userId) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text('No Wallets Yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create your first wallet to start\nmanaging your finances',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _showAddWalletDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24, // Larger circle for 36px icon
          backgroundColor: wallet.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          child: WalletIconHelper.buildIcon(
            wallet.icon,
            size: 36, // Full size for 1:1 SVG display
            // Only apply color for default icon (when wallet.icon is null)
            color: wallet.icon == null || wallet.icon!.isEmpty
                ? (wallet.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant)
                : null,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                wallet.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: wallet.isActive
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Sync status indicator removed
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CurrencyFormatter.format(wallet.balance, wallet.currency),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: wallet.balance >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            Text(
              'Currency: ${wallet.currency}',
              style: theme.textTheme.bodySmall,
            ),
            if (!wallet.isActive)
              Text(
                'Inactive',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleMenuAction(context, ref, value, wallet, userId),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            // sync option removed
            PopupMenuItem(
              value: wallet.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(
                    wallet.isActive ? Icons.visibility_off : Icons.visibility,
                  ),
                  const SizedBox(width: 8),
                  Text(wallet.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showWalletDetails(context, wallet),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Wallet wallet,
    String userId,
  ) {
    switch (action) {
      case 'edit':
        _showEditWalletDialog(context, ref, wallet);
        break;
      case 'activate':
      case 'deactivate':
        _toggleWalletStatus(context, ref, wallet, userId);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref, wallet, userId);
        break;
    }
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => WalletFormDialog(
        title: 'Add New Wallet',
        onSave: (request) async {
          final user = ref.read(currentUserProvider).value;
          if (user != null) {
            final walletService = ref.read(walletServiceProvider);
            await walletService.createWallet(user.id, request);
            // Refresh semua wallet providers untuk memastikan semua UI terupdate
            refreshWalletProviders(ref);
          }
        },
      ),
    );
  }

  void _showEditWalletDialog(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
  ) {
    showDialog(
      context: context,
      builder: (context) => WalletFormDialog(
        title: 'Edit Wallet',
        initialData: UpdateWalletRequest(
          name: wallet.name,
          balance: wallet.balance,
          currency: wallet.currency,
          icon: wallet.icon,
          isActive: wallet.isActive,
        ),
        onSave: (request) async {
          final walletService = ref.read(walletServiceProvider);
          await walletService.updateWallet(wallet.id, wallet.userId, request);
          // Refresh semua wallet providers untuk memastikan semua UI terupdate
          refreshWalletProviders(ref);
        },
      ),
    );
  }

  void _toggleWalletStatus(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      await walletService.updateWallet(
        wallet.id,
        userId,
        UpdateWalletRequest(isActive: !wallet.isActive),
      );
      // Refresh semua wallet providers untuk memastikan semua UI terupdate
      refreshWalletProviders(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wallet.isActive
                  ? '${wallet.name} deactivated'
                  : '${wallet.name} activated',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text(
          'Are you sure you want to delete "${wallet.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteWallet(context, ref, wallet, userId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWallet(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      await walletService.deleteWallet(wallet.id, userId);
      ref.invalidate(walletsProvider(userId));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${wallet.name} deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting wallet: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showWalletDetails(BuildContext context, Wallet wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(wallet.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Balance',
              CurrencyFormatter.format(wallet.balance, wallet.currency),
            ),
            _buildDetailRow('Currency', wallet.currency),
            _buildDetailRow(
              'Icon',
              wallet.icon != null
                  ? WalletIconHelper.getIconDisplayName(wallet.icon!)
                  : 'Default',
            ),
            _buildDetailRow('Status', wallet.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow(
              'Created',
              '${wallet.createdAt.day}/${wallet.createdAt.month}/${wallet.createdAt.year}',
            ),
            _buildDetailRow(
              'Last Updated',
              '${wallet.updatedAt.day}/${wallet.updatedAt.month}/${wallet.updatedAt.year}',
            ),
            // sync status removed
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // _forceSyncWallet removed
}

class WalletFormDialog extends StatefulWidget {
  final String title;
  final UpdateWalletRequest? initialData;
  final Function(dynamic request) onSave;

  const WalletFormDialog({
    super.key,
    required this.title,
    this.initialData,
    required this.onSave,
  });

  @override
  State<WalletFormDialog> createState() => _WalletFormDialogState();
}

class _WalletFormDialogState extends State<WalletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedCurrency = 'IDR';
  String? _selectedIcon;
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _currencies = [
    'IDR',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'SGD',
    'MYR',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!.name ?? '';
      _balanceController.text = widget.initialData!.balance?.toString() ?? '';
      _selectedCurrency = widget.initialData!.currency ?? 'IDR';
      _selectedIcon = widget.initialData!.icon;
      _isActive = widget.initialData!.isActive ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter wallet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Balance',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter balance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
                items: _currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Icon Selection
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected Icon: ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: WalletIconHelper.buildIcon(_selectedIcon, size: 24),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _showIconSelectionDialog,
                    child: const Text('Select Icon'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value ?? true;
                      });
                    },
                  ),
                  const Text('Active'),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _showIconSelectionDialog() {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.7; // 70% of screen height

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: maxDialogHeight,
            maxWidth: 500, // Max width for better UX
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Wallet Icon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: WalletIconHelper.buildIconSelectionGrid(
                    selectedIcon: _selectedIcon,
                    onIconSelected: (iconPath) {
                      setState(() {
                        _selectedIcon = iconPath;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedIcon = null;
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Use Default'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final balance = double.parse(_balanceController.text);

      if (widget.initialData != null) {
        // Update existing wallet
        final request = UpdateWalletRequest(
          name: _nameController.text.trim(),
          balance: balance,
          currency: _selectedCurrency,
          icon: _selectedIcon,
          isActive: _isActive,
        );
        await widget.onSave(request);
      } else {
        // Create new wallet
        final request = CreateWalletRequest(
          name: _nameController.text.trim(),
          initialBalance: balance,
          currency: _selectedCurrency,
          icon: _selectedIcon,
        );
        await widget.onSave(request);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialData != null
                  ? 'Wallet updated successfully'
                  : 'Wallet created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
