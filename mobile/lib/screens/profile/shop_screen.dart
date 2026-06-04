import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/api.dart';
import '../../state/session_state.dart';
import '../../theme/app_theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Map<String, dynamic>> _items = [];
  int _xp = 0;
  int _userLevel = 1;
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  bool _isConsumable(Map<String, dynamic> item) {
    return (item['category'] ?? '').toString() == 'consumable';
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final sessionState = Provider.of<SessionState>(context, listen: false);
      if ((sessionState.token ?? '').isNotEmpty) {
        Api.setToken(sessionState.token);
      }
      final data = await Api.getShopItems();
      final rawItems = (data['items'] as List<dynamic>?) ?? [];

      final items =
          rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      final xp = _toInt(data['xp']);
      final userLevel = _toInt(data['userLevel'], fallback: 1);
      final hintBalance = _toInt(data['hintBalance']);

      if (!mounted) return;
      setState(() {
        _items = items;
        _xp = xp;
        _userLevel = userLevel;
        _loading = false;
      });

      sessionState.updateProfile(
        xp: xp,
        level: userLevel,
        hintBalance: hintBalance,
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '').trim();
      final message = raw.isEmpty ? 'Impossible de charger la boutique.' : raw;
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategory == 'all') return _items;
    if (_selectedCategory == 'owned') {
      return _items
          .where(
            (i) =>
                i['owned'] == true ||
                (_toInt(i['count']) > 0) ||
                ((i['purchased'] ?? false) == true),
          )
          .toList();
    }
    return _items;
  }

  Future<void> _buyItem(Map<String, dynamic> item) async {
    final state = Provider.of<SessionState>(context, listen: false);
    final isFr = state.isFrench;

    if (item['locked'] == true) {
      final minLevel = _toInt(item['minLevel'], fallback: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? '🔒 Niveau $minLevel requis (vous êtes niveau $_userLevel)'
                : '🔒 Level $minLevel required (you are level $_userLevel)',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    if (item['owned'] == true) {
      if (!mounted) return;
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

    final price = _toInt(item['price']);
    if (_xp < price) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'XP insuffisant ! Il vous faut $price XP'
                : 'Not enough XP! You need $price XP',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
                (item['icon'] ?? '🎁').toString(),
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 12),
              Text(
                isFr
                    ? (item['name'] ?? '').toString()
                    : (item['name_en'] ?? item['name'] ?? '').toString(),
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
                  '$price XP',
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
                    ? 'Solde après achat: ${_xp - price} XP'
                    : 'Balance after purchase: ${_xp - price} XP',
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
        );
      },
    );

    if (confirm != true) return;

    try {
      final result = await Api.buyShopItem((item['id'] ?? '').toString());
      if (result['success'] == true) {
        final newXP = _toInt(result['xp_remaining']);
        final newLevel = _toInt(result['level'], fallback: _userLevel);
        final newHintBalance = result['hintBalance'] != null
            ? _toInt(result['hintBalance'])
            : null;

        if (!mounted) return;
        setState(() {
          _xp = newXP;
          _userLevel = newLevel;
        });
        state.updateProfile(
          xp: newXP,
          level: newLevel,
          hintBalance: newHintBalance,
        );

        final itemId = (item['id'] ?? '').toString();
        if (itemId == 'theme_dark') {
          state.setDarkTheme(true);
        } else if (itemId.startsWith('avatar_')) {
          state.updateProfile(avatarId: itemId);
        } else if (itemId.startsWith('title_')) {
          final titleName =
              (item['name']?.toString().replaceFirst('Titre: ', '') ?? itemId);
          state.updateProfile(activeTitle: titleName);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? '✅ ${(item['name'] ?? 'Achat').toString()} acheté !'
                  : '✅ ${(item['name_en'] ?? item['name'] ?? 'Purchase').toString()} purchased!',
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );

        await _load();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((result['error'] ?? 'Erreur').toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<SessionState>(context);
    final isFr = state.isFrench;

    if (!state.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isFr ? 'Boutique' : 'Shop',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.lock,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                Text(
                  isFr
                      ? 'Veuillez vous connecter pour accéder à la boutique.'
                      : 'Please log in to access the shop.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isFr ? 'Boutique' : 'Shop',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.coins,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_xp XP',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.wifiOff,
                        size: 52,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: Text(isFr ? 'Réessayer' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                children: [
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _chip('all', isFr ? 'Tout' : 'All'),
                        const SizedBox(width: 10),
                        _chip('owned', isFr ? 'Mes achats' : 'My purchases'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              isFr ? 'Aucun article disponible' : 'No items available',
                              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _buildShopList(isFr),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      isFr
                          ? 'Niveau actuel: $_userLevel'
                          : 'Current level: $_userLevel',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildShopList(bool isFr) {
    final consumables = _filteredItems.where(_isConsumable).toList();
    final permanents = _filteredItems.where((i) => !_isConsumable(i)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        // ── Section Consommables ──
        if (consumables.isNotEmpty) ...[
          _sectionHeader(
            icon: LucideIcons.shoppingBag,
            title: isFr ? 'Indices & Atouts' : 'Hints & Boosts',
            subtitle: isFr
                ? 'Utilisables pendant vos simulations'
                : 'Use them during simulations',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: consumables.length,
            itemBuilder: (_, i) => _shopCard(consumables[i], isFr, isConsumable: true),
          ),
          const SizedBox(height: 24),
        ],
        // ── Section Permanents ──
        if (permanents.isNotEmpty) ...[
          _sectionHeader(
            icon: LucideIcons.star,
            title: isFr ? 'Articles Permanents' : 'Permanent Items',
            subtitle: isFr ? 'Thèmes, avatars, titres' : 'Themes, avatars, titles',
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: permanents.length,
            itemBuilder: (_, i) => _shopCard(permanents[i], isFr),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
            ),
            Text(
              subtitle,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String key, String label) {
    final selected = _selectedCategory == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _shopCard(Map<String, dynamic> item, bool isFr, {bool isConsumable = false}) {
    final name =
        isFr
            ? (item['name'] ?? '').toString()
            : (item['name_en'] ?? item['name'] ?? '').toString();
    final desc =
        isFr
            ? (item['description'] ?? '').toString()
            : (item['description_en'] ?? item['description'] ?? '').toString();
    final icon = (item['icon'] ?? '🎁').toString();
    final price = _toInt(item['price']);
    final owned = item['owned'] == true;
    final locked = item['locked'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              if (isConsumable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFr ? 'Consommable' : 'Consumable',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                )
              else if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('🔒', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '$price XP',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: owned || locked ? null : () => _buyItem(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        owned ? const Color(0xFFCBD5E1) : AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    owned
                        ? (isFr ? 'Acheté' : 'Owned')
                        : (isFr ? 'Acheter' : 'Buy'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
