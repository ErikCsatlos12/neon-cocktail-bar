import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CocktailApp());
}

// --- CYBERPUNK SZÍNEK ---
class AppColors {
  static const Color background = Color(0xFF09090E);
  static const Color cardBg = Color(0xFF151522);
  static const Color neonCyan = Color(0xFF00F3FF);
  static const Color neonPink = Color(0xFFFF00E5);
  static const Color neonPurple = Color(0xFF9D00FF);
  static const Color textMain = Colors.white;
  static const Color textMuted = Color(0xFFA0A0B0);

  static Color get borderGlow => Colors.white.withValues(alpha: 0.05);
}

// Közös neon gombstílus
ButtonStyle neonButtonStyle() {
  return OutlinedButton.styleFrom(
    side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5), width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    backgroundColor: AppColors.neonCyan.withValues(alpha: 0.1),
  );
}

// --- API RÉTEG (TheCocktailDB) ---
class CocktailApi {
  static const String _base = 'https://www.thecocktaildb.com/api/json/v1/1';
  static const Duration _timeout = Duration(seconds: 15);

  // Koktélok keresése kezdőbetű (vagy számjegy) alapján
  static Future<List<Map<String, dynamic>>> searchByFirstLetter(String letter) async {
    final response = await http.get(Uri.parse('$_base/search.php?f=$letter')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return _parseDrinks(response.body);
  }

  // Egy véletlenszerű koktél
  static Future<Map<String, dynamic>?> random() async {
    final response = await http.get(Uri.parse('$_base/random.php')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final drinks = _parseDrinks(response.body);
    return drinks.isEmpty ? null : drinks.first;
  }

  static List<Map<String, dynamic>> _parseDrinks(String body) {
    if (body.trim().isEmpty) return [];
    final data = json.decode(body);
    final drinks = data is Map<String, dynamic> ? data['drinks'] : null;
    if (drinks is! List) return [];
    return drinks.whereType<Map<String, dynamic>>().toList();
  }
}

// Egy koktél hozzávalóinak nevei (strIngredient1 – strIngredient15)
List<String> ingredientNames(Map<String, dynamic> drink) {
  final names = <String>[];
  for (int i = 1; i <= 15; i++) {
    final value = drink['strIngredient$i'];
    if (value is String && value.trim().isNotEmpty) {
      names.add(value.trim());
    }
  }
  return names;
}

class CocktailApp extends StatelessWidget {
  const CocktailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Bar – Cocktail Recommender',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.neonPink,
          surface: AppColors.background,
        ),
        fontFamily: 'Roboto',
      ),
      home: const NeonHomePage(),
    );
  }
}

class NeonHomePage extends StatefulWidget {
  const NeonHomePage({super.key});

  @override
  State<NeonHomePage> createState() => _NeonHomePageState();
}

class _NeonHomePageState extends State<NeonHomePage> {
  static const Map<String, List<Map<String, String>>> _categorizedIngredients = {
    'Spirits & Liquors': [
      {'name': 'Vodka', 'icon': '❄️'}, {'name': 'Rum', 'icon': '🏴‍☠️'},
      {'name': 'Gin', 'icon': '🌲'}, {'name': 'Tequila', 'icon': '🌵'},
      {'name': 'Whiskey', 'icon': '🥃'}, {'name': 'Bourbon', 'icon': '🛢️'},
      {'name': 'Cognac', 'icon': '🍇'}, {'name': 'Amaretto', 'icon': '🌰'},
      {'name': 'Triple sec', 'icon': '🧡'}, {'name': 'Campari', 'icon': '🔴'},
      {'name': 'Kahlua', 'icon': '☕'}, {'name': 'Vermouth', 'icon': '🍸'},
    ],
    'Mixers & Juices': [
      {'name': 'Lime', 'icon': '🍈'}, {'name': 'Lemon', 'icon': '🍋'},
      {'name': 'Orange', 'icon': '🍊'}, {'name': 'Cranberry', 'icon': '🍒'},
      {'name': 'Pineapple', 'icon': '🍍'}, {'name': 'Tomato', 'icon': '🍅'},
      {'name': 'Coca-Cola', 'icon': '🥤'}, {'name': 'Sprite', 'icon': '🫗'},
      {'name': 'Ginger ale', 'icon': '🍺'}, {'name': 'Tonic water', 'icon': '🫧'},
      {'name': 'Soda', 'icon': '💧'},
    ],
    'Syrups & Extras': [
      {'name': 'Simple syrup', 'icon': '🍯'}, {'name': 'Grenadine', 'icon': '🩸'},
      {'name': 'Sugar', 'icon': '🍬'}, {'name': 'Mint', 'icon': '🌿'},
      {'name': 'Ice', 'icon': '🧊'}, {'name': 'Salt', 'icon': '🧂'},
      {'name': 'Coffee', 'icon': '🫘'}, {'name': 'Milk', 'icon': '🥛'},
    ],
  };

  final Set<String> _selectedIngredients = {};
  List<Map<String, dynamic>> _masterDrinks = [];
  List<Map<String, dynamic>> _drinks = [];
  bool _isInitializing = true;
  bool _loadFailed = false;
  bool _isLoadingRandom = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadMasterDatabase();
  }

  // Induláskor párhuzamosan letöltjük az összes kezdőbetű (a–z, 0–9) receptjeit
  Future<void> _loadMasterDatabase() async {
    const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';

    final results = await Future.wait(
      characters.split('').map((letter) async {
        try {
          return await CocktailApi.searchByFirstLetter(letter);
        } catch (e) {
          debugPrint('Betöltési hiba ($letter): $e');
          return <Map<String, dynamic>>[];
        }
      }),
    );

    final collected = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (final list in results) {
      for (final drink in list) {
        final id = drink['idDrink'];
        if (id is String && seenIds.add(id)) {
          collected.add(drink);
        }
      }
    }
    collected.sort((a, b) =>
        (a['strDrink'] as String? ?? '').compareTo(b['strDrink'] as String? ?? ''));

    if (!mounted) return;
    setState(() {
      _masterDrinks = collected;
      _isInitializing = false;
      _loadFailed = collected.isEmpty;
    });
  }

  void _retryLoad() {
    setState(() {
      _isInitializing = true;
      _loadFailed = false;
    });
    _loadMasterDatabase();
  }

  // Helyi ÉS-szűrés: minden kiválasztott hozzávaló szerepeljen, egész szavas egyezéssel
  // (így az "Ice" nem egyezik a "Lime juice"-szal, a "Gin" pedig nem a "Ginger ale"-lel)
  void _filterCocktailsLocally() {
    if (_selectedIngredients.isEmpty) {
      setState(() {
        _drinks = [];
        _hasSearched = false;
      });
      return;
    }

    final patterns = _selectedIngredients
        .map((sel) => RegExp(r'\b' + RegExp.escape(sel) + r'\b', caseSensitive: false))
        .toList();

    final matches = _masterDrinks.where((drink) {
      final ingredients = ingredientNames(drink);
      return patterns.every((pattern) => ingredients.any(pattern.hasMatch));
    }).toList();

    setState(() {
      _drinks = matches;
      _hasSearched = true;
    });
  }

  // Véletlenszerű koktél az API-ból
  Future<void> _fetchRandomCocktail() async {
    setState(() {
      _isLoadingRandom = true;
      _hasSearched = true;
      _selectedIngredients.clear();
    });

    try {
      final drink = await CocktailApi.random();
      if (!mounted) return;
      setState(() => _drinks = drink == null ? [] : [drink]);
    } catch (e) {
      debugPrint('Random hiba: $e');
      if (!mounted) return;
      setState(() {
        _drinks = [];
        _hasSearched = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CONNECTION ERROR – COULD NOT FETCH A RANDOM COCKTAIL.'),
          backgroundColor: AppColors.cardBg,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingRandom = false);
    }
  }

  void _toggleIngredient(String ingredient) {
    if (_selectedIngredients.contains(ingredient)) {
      _selectedIngredients.remove(ingredient);
    } else {
      _selectedIngredients.add(ingredient);
    }
    _filterCocktailsLocally();
  }

  void _clearAll() {
    setState(() {
      _selectedIngredients.clear();
      _drinks = [];
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_bar, color: AppColors.neonPink),
            const SizedBox(width: 10),
            Text(
              'NEON BAR',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.textMain,
                shadows: [Shadow(color: AppColors.neonPink.withValues(alpha: 0.8), blurRadius: 10)],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.neonCyan),
            SizedBox(height: 20),
            Text(
              'INITIALIZING BAR DATABASE...',
              style: TextStyle(color: AppColors.textMuted, letterSpacing: 2),
            ),
          ],
        ),
      );
    }
    if (_loadFailed) {
      return _buildLoadError();
    }
    return _buildMainContent();
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: AppColors.neonPink.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            const Text(
              'CONNECTION ERROR\nCOULD NOT LOAD THE BAR DATABASE.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neonPink, letterSpacing: 1.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _retryLoad,
              icon: const Icon(Icons.refresh, color: AppColors.neonCyan),
              label: const Text(
                'TRY AGAIN',
                style: TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              style: neonButtonStyle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // CÍMSOR ÉS MEGLEPETÉS GOMB
              Semantics(
                header: true,
                child: Text(
                  'WHAT SHOULD WE\nDRINK TONIGHT?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    height: 1.1,
                    shadows: [
                      Shadow(color: AppColors.neonCyan.withValues(alpha: 0.8), blurRadius: 20, offset: const Offset(-2, 2)),
                      Shadow(color: AppColors.neonPurple.withValues(alpha: 0.8), blurRadius: 20, offset: const Offset(2, -2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _isLoadingRandom ? null : _fetchRandomCocktail,
                icon: const Icon(Icons.casino, color: AppColors.neonCyan),
                label: const Text(
                  'SURPRISE ME!',
                  style: TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                style: neonButtonStyle(),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // KATEGÓRIÁK – LENYÍLÓ HARMONIKA MENÜK
                    SliverToBoxAdapter(
                      child: Column(
                        children: _categorizedIngredients.entries.map(_buildCategory).toList(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    const SliverToBoxAdapter(child: Divider(color: Colors.white10)),

                    // AKTÍV SZŰRŐK ÉS TÖRLÉS SÁVJA
                    if (_selectedIngredients.isNotEmpty) SliverToBoxAdapter(child: _buildActiveFilters()),

                    // EREDMÉNYEK
                    ..._buildResultSlivers(),

                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(MapEntry<String, List<Map<String, String>>> category) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        collapsedIconColor: AppColors.neonPink,
        iconColor: AppColors.neonCyan,
        title: Text(
          category.key.toUpperCase(),
          style: const TextStyle(
            color: AppColors.neonPink,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: category.value
                .map((item) => _buildIngredientChip(item['name']!, item['icon']!))
                .toList(),
          ),
        ],
      ),
    );
  }

  // Natív FilterChip: billentyűzettel elérhető, a képernyőolvasó a kijelölt állapotot is bemondja
  Widget _buildIngredientChip(String ingredient, String icon) {
    final isSelected = _selectedIngredients.contains(ingredient);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected
            ? [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.4), blurRadius: 10)]
            : [],
      ),
      child: FilterChip(
        selected: isSelected,
        onSelected: (_) => _toggleIngredient(ingredient),
        showCheckmark: false,
        avatar: ExcludeSemantics(child: Text(icon, style: const TextStyle(fontSize: 16))),
        label: Text(ingredient),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.textMain : AppColors.textMuted,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: AppColors.cardBg,
        selectedColor: AppColors.neonCyan.withValues(alpha: 0.15),
        side: BorderSide(
          color: isSelected ? AppColors.neonCyan : AppColors.borderGlow,
          width: isSelected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        children: [
          const Text(
            'ACTIVE FILTERS: ',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _selectedIngredients
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Chip(
                            label: Text(e, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.neonPurple.withValues(alpha: 0.3),
                            side: const BorderSide(color: AppColors.neonPurple),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteButtonTooltipMessage: 'Remove $e',
                            onDeleted: () => _toggleIngredient(e),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep, color: AppColors.neonPink, size: 18),
            label: const Text('CLEAR ALL', style: TextStyle(color: AppColors.neonPink)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResultSlivers() {
    if (_isLoadingRandom) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.neonCyan),
            ),
          ),
        ),
      ];
    }

    if (!_hasSearched) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Pick ingredients or hit SURPRISE ME!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 2, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ];
    }

    if (_drinks.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.neonPink.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'NO MATCH FOUND FOR ALL SELECTED INGREDIENTS.\nTRY FEWER FILTERS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.neonPink, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${_drinks.length} ${_drinks.length == 1 ? 'MATCH' : 'MATCHES'} FOUND',
              style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        ),
      ),
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          childAspectRatio: 0.75,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => CyberDrinkCard(drink: _drinks[index]),
          childCount: _drinks.length,
        ),
      ),
    ];
  }
}

// --- KÉP HIBA- ÉS BETÖLTÉSKEZELÉSSEL ---
class DrinkImage extends StatelessWidget {
  final String? url;
  final String? semanticLabel;

  const DrinkImage({super.key, required this.url, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.cardBg,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, color: AppColors.textMuted, size: 48),
    );

    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: AppColors.cardBg),
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

// --- CYBERPUNK KOKTÉL KÁRTYA ---
class CyberDrinkCard extends StatefulWidget {
  final Map<String, dynamic> drink;
  const CyberDrinkCard({super.key, required this.drink});

  @override
  State<CyberDrinkCard> createState() => _CyberDrinkCardState();
}

class _CyberDrinkCardState extends State<CyberDrinkCard> {
  // Egérrel ráhúzva VAGY billentyűzettel fókuszálva világít
  bool _isActive = false;

  void _setActive(bool value) {
    if (_isActive != value) setState(() => _isActive = value);
  }

  void _openRecipe() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => CyberRecipePage(drink: widget.drink),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.drink['strDrink'] as String? ?? 'Unknown cocktail';
    final thumb = widget.drink['strDrinkThumb'] as String?;

    return Semantics(
      button: true,
      label: '$name – open recipe',
      onTap: _openRecipe,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.cardBg,
            border: Border.all(
              color: _isActive ? AppColors.neonPink : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isActive
                ? [BoxShadow(color: AppColors.neonPink.withValues(alpha: 0.5), blurRadius: 20)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openRecipe,
              onHover: _setActive,
              onFocusChange: _setActive,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'drink_img_${widget.drink['idDrink']}',
                    child: DrinkImage(url: thumb),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.95)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.arrow_forward_ios, color: AppColors.neonCyan, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'MIX IT',
                              style: TextStyle(color: AppColors.neonCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- RÉSZLETES RECEPT NÉZET ---
class CyberRecipePage extends StatelessWidget {
  final Map<String, dynamic> drink;
  const CyberRecipePage({super.key, required this.drink});

  List<Map<String, String>> _getIngredients() {
    final ingredients = <Map<String, String>>[];
    for (int i = 1; i <= 15; i++) {
      final name = drink['strIngredient$i'];
      final measure = drink['strMeasure$i'];
      if (name is String && name.trim().isNotEmpty) {
        ingredients.add({
          'name': name.trim(),
          'measure': (measure is String && measure.trim().isNotEmpty) ? measure.trim() : 'To taste',
        });
      }
    }
    return ingredients;
  }

  @override
  Widget build(BuildContext context) {
    final name = drink['strDrink'] as String? ?? 'Unknown cocktail';
    final thumb = drink['strDrinkThumb'] as String?;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back, color: AppColors.neonCyan),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'drink_img_${drink['idDrink']}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DrinkImage(url: thumb, semanticLabel: 'Photo of $name'),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.background],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain,
                            letterSpacing: 2,
                            shadows: [Shadow(color: AppColors.neonPink.withValues(alpha: 0.8), blurRadius: 15)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildCyberTag(drink['strAlcoholic'] as String? ?? 'Unknown', AppColors.neonCyan),
                          _buildCyberTag(drink['strGlass'] as String? ?? 'Any glass', AppColors.neonPurple),
                        ],
                      ),
                      const SizedBox(height: 50),

                      _buildSectionTitle('INGREDIENTS'),
                      const SizedBox(height: 20),
                      ..._getIngredients().map((ing) => Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: const Border(left: BorderSide(color: AppColors.neonCyan, width: 4)),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      ing['name']!,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    ing['measure']!,
                                    style: const TextStyle(fontSize: 16, color: AppColors.neonPink, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          )),

                      const SizedBox(height: 50),
                      _buildSectionTitle('INSTRUCTIONS'),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.5), width: 1),
                          boxShadow: [BoxShadow(color: AppColors.neonPurple.withValues(alpha: 0.1), blurRadius: 20)],
                        ),
                        child: Text(
                          drink['strInstructions'] as String? ?? 'No instructions available.',
                          style: const TextStyle(fontSize: 18, height: 1.8, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.memory, color: AppColors.neonCyan),
        const SizedBox(width: 10),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildCyberTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }
}