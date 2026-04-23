import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const Set<String> _allowedItemIds = {
    'hint_pack_small',
    'xp_boost_2x',
    'streak_shield',
  };

  List<dynamic> _items = [];
  int _xp = 0;
  int _userLevel = 1;
  int _hintBalance = 0;
  bool _loading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.getShopItems();
      final allItems = (data['items'] ?? []) as List<dynamic>;
      setState(() {
        _items =
            allItems
                .where(
                  (e) =>
                      e is Map<String, dynamic> &&
                      _allowedItemIds.contains((e['id'] ?? '').toString()),
                )
                .toList();
        _xp = (data['xp'] ?? 0) as int;
        _userLevel = (data['userLevel'] ?? 1) as int;
        _hintBalance = (data['hintBalance'] ?? 0) as int;
        _loading = false;
      });
      // Update state
      final state = Provider.of<SessionState>(context, listen: false);
      state.updateProfile(hintBalance: _hintBalance);

      // Apply already-owned theme/avatar/title
      for (final item in _items) {
        if (item['owned'] == true) {
          final id = item['id'] as String;
          if (id == 'theme_dark') {
            state.setDarkTheme(true);
          }
        }
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredItems {
    if (_selectedCategory == 'all') return _items;
    if (_selectedCategory == 'owned') {
      return _items
          .where(
            (i) =>
                i['owned'] == true ||
                (i['count'] != null && (i['count'] as int) > 0),
          )
          .toList();
    }
    return _items.where((i) => i['category'] == _selectedCategory).toList();
  }

  Future<void> _buyItem(Map<String, dynamic> item) async {
    final state = Provider.of<SessionState>(context, listen: false);
    final isFr = state.isFrench;

    // Check level lock
    if (item['locked'] == true) {
      final minLevel = item['minLevel'] ?? 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? '🔒 Niveau $minLevel requis (vous êtes niveau $_userLevel)'
                : '🔒 Level $minLevel required (you are level $_userLevel)',
          ),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
      );
      return;
    }

    if (item['owned'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'Vous possédez déjà cet article'
                : 'You already own this item',
          ),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    if (_xp < (item['price'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'XP insuffisant ! Il vous faut ${item['price']} XP'
                : 'Not enough XP! You need ${item['price']} XP',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              isFr ? 'Confirmer l\'achat' : 'Confirm Purchase',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['icon'] ?? '🎁',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  isFr
                      ? (item['name'] ?? '')
                      : (item['name_en'] ?? item['name'] ?? ''),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item['price']} XP',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isFr
                      ? 'Solde après achat: ${_xp - (item['price'] as int)} XP'
                      : 'Balance after purchase: ${_xp - (item['price'] as int)} XP',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  isFr ? 'Annuler' : 'Cancel',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  isFr ? 'Acheter' : 'Buy',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      final result = await Api.buyShopItem(item['id']);
      if (result['success'] == true) {
        final oldLevel = _userLevel;
        final newXP = (result['xp_remaining'] ?? 0) as int;
        final newLevel = (result['level'] ?? 1) as int;
        setState(() {
          _xp = newXP;
          _userLevel = newLevel;
        });
        state.updateProfile(xp: newXP, level: newLevel);

        // Apply purchased item effects
        final itemId = item['id'] as String;
        if (itemId == 'theme_dark') {
          state.setDarkTheme(true);
        } else if (itemId.startsWith('avatar_')) {
          state.updateProfile(avatarId: itemId);
        } else if (itemId.startsWith('title_')) {
          final titleName =
              item['name']?.toString().replaceFirst('Titre: ', '') ?? itemId;
          state.updateProfile(activeTitle: titleName);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFr
                    ? '✅ ${item['name']} acheté !'
                    : '✅ ${item['name_en'] ?? item['name']} purchased!',
              ),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
          if (newLevel > oldLevel) {
            _showLevelUpDialog(oldLevel, newLevel, isFr);
          }
        }
        _load(); // Refresh
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showLevelUpDialog(int oldLevel, int newLevel, bool isFr) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(
                  isFr ? 'Level Up !' : 'Level Up!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr
                      ? 'Vous passez du niveau $oldLevel au niveau $newLevel.'
                      : 'You advanced from level $oldLevel to level $newLevel.',
                  style: GoogleFonts.outfit(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  isFr
                      ? 'Nouveaux contenus et avantages potentiellement débloqués.'
                      : 'New content and benefits may now be unlocked.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<SessionState>(context);
    final isFr = state.isFrench;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFr ? 'Boutique XP' : 'XP Shop',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  // XP Balance
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.coins,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_xp XP',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Filters
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildCategoryChip(
                    'all',
                    isFr ? 'Tout' : 'All',
                    LucideIcons.grid,
                  ),
                  _buildCategoryChip(
                    'owned',
                    isFr ? 'Mes achats' : 'My Items',
                    LucideIcons.package2,
                  ),
                  _buildCategoryChip(
                    'consumable',
                    isFr ? 'Consommables' : 'Consumables',
                    LucideIcons.zap,
                  ),
                ],
              ),
            ),
            // Hint balance banner
            if (_hintBalance > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFBBF24).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFr
                              ? '$_hintBalance indice${_hintBalance > 1 ? 's' : ''} disponible${_hintBalance > 1 ? 's' : ''}'
                              : '$_hintBalance hint${_hintBalance > 1 ? 's' : ''} available',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Items Grid
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredItems.isEmpty
                      ? Center(
                        child: Text(
                          isFr
                              ? 'Aucun article dans cette catégorie'
                              : 'No items in this category',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                      : RefreshIndicator(
                        onRefresh: _load,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item =
                                _filteredItems[index] as Map<String, dynamic>;
                            return _buildShopCard(item, isFr);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label, IconData icon) {
    final selected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> item, bool isFr) {
    final owned = item['owned'] == true;
    final price = item['price'] as int;
    final canAfford = _xp >= price;
    final isLocked = item['locked'] == true;
    final minLevel = item['minLevel'] ?? 1;
    final consumableCount = (item['count'] ?? 0) as int;
    final name =
        isFr ? (item['name'] ?? '') : (item['name_en'] ?? item['name'] ?? '');
    final desc =
        isFr
            ? (item['description'] ?? '')
            : (item['description_en'] ?? item['description'] ?? '');

    return GestureDetector(
      onTap: () => _buyItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                owned
                    ? const Color(0xFF22C55E).withOpacity(0.4)
                    : const Color(0xFFE2E8F0),
            width: owned ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon area
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      isLocked
                          ? const Color(0xFFF1F5F9)
                          : owned
                          ? const Color(0xFFDCFCE7)
                          : _getCategoryColor(
                            item['category'],
                          ).withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Opacity(
                        opacity: isLocked ? 0.4 : 1.0,
                        child: Text(
                          item['icon'] ?? '🎁',
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                    if (isLocked)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Niv.$minLevel',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (owned)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    if (consumableCount > 0)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x$consumableCount',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info area
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(
                        desc,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Price button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            isLocked
                                ? const Color(0xFFF3E8FF)
                                : owned
                                ? const Color(0xFFDCFCE7)
                                : canAfford
                                ? AppColors.primary
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          isLocked
                              ? '🔒 ${isFr ? 'Niv.' : 'Lv.'}$minLevel'
                              : owned
                              ? (isFr ? 'Possédé ✓' : 'Owned ✓')
                              : '$price XP',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color:
                                isLocked
                                    ? const Color(0xFF8B5CF6)
                                    : owned
                                    ? const Color(0xFF22C55E)
                                    : canAfford
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'title':
        return const Color(0xFFA855F7);
      case 'avatar':
        return const Color(0xFF3B82F6);
      case 'consumable':
        return const Color(0xFFF59E0B);
      case 'theme':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
