# Neon Bar – Cocktail Recommender

Cyberpunk hangulatú koktélajánló webalkalmazás Flutter Webben. Kiválasztod, milyen hozzávalóid vannak otthon, és az app megmutatja, milyen koktélokat tudsz belőlük kikeverni.

**Élő demó:** https://erikcsatlos12.github.io/neon-cocktail-bar/

## Funkciók

- Hozzávalók kiválasztása kategóriánként (szeszes italok, üdítők és levek, szirupok és extrák)
- ÉS-szűrés: csak azok a koktélok jelennek meg, amelyekben minden kiválasztott hozzávaló szerepel (egész szavas egyezéssel)
- „Surprise me!” – véletlenszerű koktél
- Részletes receptoldal: hozzávalók mennyiséggel, elkészítés, pohár típusa, alkoholtartalom
- Betöltési, üres, „nincs találat” és hálózati hibaállapot (újrapróbálás gombbal)
- Billentyűzettel is használható, képernyőolvasó-barát (Semantics, FilterChip)

## Technológia

- Flutter Web (Dart), Material 3
- `http` csomag az API-hívásokhoz
- Adatforrás: [TheCocktailDB](https://www.thecocktaildb.com/) ingyenes API
- Hosting: GitHub Pages

## Használt API végpontok

| Végpont | Mire használja |
|---|---|
| `search.php?f={betű}` | Induláskor a–z és 0–9 összes koktélja (párhuzamos kérésekkel), ebből történik a helyi szűrés |
| `random.php` | Véletlenszerű koktél a „Surprise me!” gombhoz |

A TheCocktailDB ingyenes API-ja nem tud több hozzávalóra egyszerre szűrni, ezért az app induláskor letölti a receptadatbázist, és a szűrést helyben végzi.

## Futtatás és build

```bash
flutter pub get
flutter run -d chrome
flutter build web --release --base-href /neon-cocktail-bar/
```

A kész build a `build/web` mappába kerül, ennek tartalma van feltöltve a repó gyökerébe a GitHub Pages számára.

## Mappaszerkezet

- `lib/main.dart` – az alkalmazás forráskódja
- `pubspec.yaml` – projektbeállítások és függőségek
- a gyökérben lévő többi fájl (`index.html`, `main.dart.js`, `canvaskit/` stb.) – a lefordított build, amit a GitHub Pages kiszolgál

## Készítette

Csatlos Erik – UMFST