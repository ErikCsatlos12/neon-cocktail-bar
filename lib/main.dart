import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

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
  
  static Color get borderGlow => Colors.white.withOpacity(0.05);
}

class CocktailApp extends StatelessWidget {
  const CocktailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Cocktail Recommender',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.neonPink,
          background: AppColors.background,
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
  final Map<String, List<Map<String, String>>> _categorizedIngredients = {
    'Spirits & Liquors': [
      {'name': 'Vodka', 'icon': '🧊'}, {'name': 'Rum', 'icon': '🏴‍☠️'},
      {'name': 'Gin', 'icon': '🌲'}, {'name': 'Tequila', 'icon': '🌵'},
      {'name': 'Whiskey', 'icon': '🥃'}, {'name': 'Bourbon', 'icon': '🛢️'},
      {'name': 'Cognac', 'icon': '🍇'}, {'name': 'Amaretto', 'icon': '🌰'},
      {'name': 'Triple sec', 'icon': '🍊'}, {'name': 'Campari', 'icon': '🔴'},
      {'name': 'Kahlua', 'icon': '☕'}, {'name': 'Vermouth', 'icon': '🍸'},
    ],
    'Mixers & Juices': [
      {'name': 'Lime', 'icon': '🍈'}, {'name': 'Lemon', 'icon': '🍋'},
      {'name': 'Orange', 'icon': '🍊'}, {'name': 'Cranberry', 'icon': '🍒'},
      {'name': 'Pineapple', 'icon': '🍍'}, {'name': 'Tomato', 'icon': '🍅'},
      {'name': 'Coca-Cola', 'icon': '🥤'}, {'name': 'Sprite', 'icon': '🍋‍🟩'},
      {'name': 'Ginger ale', 'icon': '🍺'}, {'name': 'Tonic water', 'icon': '🫧'},
      {'name': 'Soda', 'icon': '💧'},
    ],
    'Syrups & Extras': [
      {'name': 'Simple syrup', 'icon': '🍯'}, {'name': 'Grenadine', 'icon': '🩸'},
      {'name': 'Sugar', 'icon': '🧂'}, {'name': 'Mint', 'icon': '🌿'},
      {'name': 'Ice', 'icon': '🧊'}, {'name': 'Salt', 'icon': '🧂'},
      {'name': 'Coffee', 'icon': '☕'}, {'name': 'Milk', 'icon': '🥛'},
    ],
  };

  final Set<String> _selectedIngredients = {};
  List<Map<String, dynamic>> _masterDrinks = [];
  List<Map<String, dynamic>> _drinks = [];
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadMasterDatabase();
  }

  // Induláskor letöltünk egy gazdag recept-adatbázist a korlátozások megkerülésére
  Future<void> _loadMasterDatabase() async {
    List<String> letters = ['a', 'b', 'c', 'm', 't', 's', 'p', 'r', 'l', 'd', 'o'];
    List<Map<String, dynamic>> collected = [];
    Set<String> seenIds = {};

    try {
      for (String letter in letters) {
        final url = Uri.parse('https://www.thecocktaildb.com/api/json/v1/1/search.php?f=$letter');
        final response = await http.get(url);
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final data = json.decode(response.body);
          if (data['drinks'] != null && data['drinks'] is List) {
            for (var drink in data['drinks']) {
              final id = drink['idDrink'];
              if (!seenIds.contains(id)) {
                seenIds.add(id);
                collected.add(drink as Map<String, dynamic>);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }

    setState(() {
      _masterDrinks = collected;
      _isInitializing = false;
    });
  }

  // Helyi, 100%-ig pontos metszet (AND) szűrés
  void _filterCocktailsLocally() {
    if (_selectedIngredients.isEmpty) {
      setState(() {
        _drinks = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    List<Map<String, dynamic>> matches = [];

    for (var drink in _masterDrinks) {
      bool matchesAll = true;

      for (String sel in _selectedIngredients) {
        String selLower = sel.toLowerCase();
        bool foundInDrink = false;

        // Végignézzük a koktél összes hozzávalóját (strIngredient1 - strIngredient15)
        for (int i = 1; i <= 15; i++) {
          String? ing = drink['strIngredient$i'];
          if (ing != null && ing.toLowerCase().contains(selLower)) {
            foundInDrink = true;
            break;
          }
        }

        if (!foundInDrink) {
          matchesAll = false;
          break;
        }
      }

      if (matchesAll) {
        matches.add(drink);
      }
    }

    setState(() {
      _drinks = matches;
      _isLoading = false;
    });
  }

  // Véletlenszerű koktél sorsolása a helyi adatbázisból vagy API-ból
  Future<void> _fetchRandomCocktail() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _selectedIngredients.clear();
    });

    try {
      final response = await http.get(Uri.parse('https://www.thecocktaildb.com/api/json/v1/1/random.php'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawList = data['drinks'] as List<dynamic>;
        setState(() {
          _drinks = rawList.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      setState(() => _drinks = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
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
                shadows: [Shadow(color: AppColors.neonPink.withOpacity(0.8), blurRadius: 10)],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.neonCyan),
                  SizedBox(height: 20),
                  Text("INITIALIZING BAR DATABASE...", style: TextStyle(color: AppColors.textMuted, letterSpacing: 2)),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // CÍMSOR ÉS MEGLEPETÉS GOMB
                      Text(
                        'WHAT SHOULD WE\nDRINK TONIGHT?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(color: AppColors.neonCyan.withOpacity(0.8), blurRadius: 20, offset: const Offset(-2, 2)),
                            Shadow(color: AppColors.neonPurple.withOpacity(0.8), blurRadius: 20, offset: const Offset(2, -2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      OutlinedButton.icon(
                        onPressed: _fetchRandomCocktail,
                        icon: const Icon(Icons.casino, color: AppColors.neonCyan),
                        label: const Text(
                          'SURPRISE ME!',
                          style: TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.neonCyan.withOpacity(0.5), width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: AppColors.neonCyan.withOpacity(0.1),
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // KATEGÓRIÁK - LENYÍLÓ HARMONIKA MENÜK
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: _categorizedIngredients.entries.map((category) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: false,
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
                                          children: category.value.map((item) {
                                            final ingredient = item['name']!;
                                            final icon = item['icon']!;
                                            final isSelected = _selectedIngredients.contains(ingredient);

                                            return InkWell(
                                              onTap: () => _toggleIngredient(ingredient),
                                              borderRadius: BorderRadius.circular(20),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? AppColors.neonCyan.withOpacity(0.15) : AppColors.cardBg,
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: isSelected ? AppColors.neonCyan : AppColors.borderGlow,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [BoxShadow(color: AppColors.neonCyan.withOpacity(0.4), blurRadius: 10)]
                                                      : [],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(icon, style: const TextStyle(fontSize: 16)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      ingredient,
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : AppColors.textMuted,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            
                            const SliverToBoxAdapter(child: SizedBox(height: 10)),
                            const SliverToBoxAdapter(child: Divider(color: Colors.white10)),
                            
                            // AKTÍV SZŰRŐK ÉS TÖRLÉS SÁVJA
                            if (_selectedIngredients.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Row(
                                    children: [
                                      const Text('ACTIVE FILTERS: ', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: _selectedIngredients.map((e) => Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Chip(
                                                label: Text(e, style: const TextStyle(fontSize: 12)),
                                                backgroundColor: AppColors.neonPurple.withOpacity(0.3),
                                                side: const BorderSide(color: AppColors.neonPurple),
                                                deleteIcon: const Icon(Icons.close, size: 14),
                                                onDeleted: () => _toggleIngredient(e),
                                              ),
                                            )).toList(),
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _clearAll,
                                        icon: const Icon(Icons.delete_sweep, color: AppColors.neonPink, size: 18),
                                        label: const Text('CLEAR ALL', style: TextStyle(color: AppColors.neonPink)),
                                      )
                                    ],
                                  ),
                                ),
                              ),

                            // EREDMÉNYEK (GRID)
                            if (_isLoading)
                              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.neonCyan)))
                            else if (!_hasSearched)
                              SliverFillRemaining(
                                child: Center(
                                  child: Text(
                                    'Awaiting input...',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 2, color: AppColors.textMuted.withOpacity(0.5)),
                                  ),
                                ),
                              )
                            else if (_drinks.isEmpty)
                              SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.neonPink.withOpacity(0.6)),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'NO MATCH FOUND FOR ALL SELECTED INGREDIENTS.\nTRY FEWER FILTERS.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.neonPink, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
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
                              
                            const SliverToBoxAdapter(child: SizedBox(height: 50)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (context, animation, secondaryAnimation) => CyberRecipePage(drink: widget.drink),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.cardBg,
            border: Border.all(
              color: _isHovered ? AppColors.neonPink : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: AppColors.neonPink.withOpacity(0.5), blurRadius: 20)]
                : [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'drink_img_${widget.drink['idDrink']}',
                child: Image.network(
                  widget.drink['strDrinkThumb'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background.withOpacity(0.95)],
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
                      widget.drink['strDrink'].toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward_ios, color: AppColors.neonCyan, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'MIX IT',
                          style: TextStyle(color: AppColors.neonCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
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
    List<Map<String, String>> ingredients = [];
    for (int i = 1; i <= 15; i++) {
      String? name = drink['strIngredient$i'];
      String? measure = drink['strMeasure$i'];
      if (name != null && name.trim().isNotEmpty) {
        ingredients.add({'name': name, 'measure': measure ?? 'To taste'});
      }
    }
    return ingredients;
  }

  @override
  Widget build(BuildContext context) {
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.neonCyan),
                    color: Colors.black.withOpacity(0.5),
                    onPressed: () => Navigator.pop(context),
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
                    Image.network(drink['strDrinkThumb'], fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.background],
                          stops: const [0.4, 1.0],
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
                      Text(
                        drink['strDrink'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [Shadow(color: AppColors.neonPink.withOpacity(0.8), blurRadius: 15)],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildCyberTag(drink['strAlcoholic'] ?? 'Alcoholic', AppColors.neonCyan),
                          const SizedBox(width: 12),
                          _buildCyberTag(drink['strGlass'] ?? 'Glass', AppColors.neonPurple),
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
                                border: Border(left: BorderSide(color: AppColors.neonCyan, width: 4)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ing['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(ing['measure']!, style: const TextStyle(fontSize: 16, color: AppColors.neonPink, fontWeight: FontWeight.bold)),
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
                          border: Border.all(color: AppColors.neonPurple.withOpacity(0.5), width: 1),
                          boxShadow: [BoxShadow(color: AppColors.neonPurple.withOpacity(0.1), blurRadius: 20)],
                        ),
                        child: Text(
                          drink['strInstructions'] ?? 'No instructions available.',
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
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCyberTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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