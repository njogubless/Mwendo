import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Curated step icons. The API stores the name; unknown names fall back gracefully.
const stepIcons = <String, IconData>{
  'check_circle': Symbols.check_circle,
  'water_drop': Symbols.water_drop,
  'directions_run': Symbols.directions_run,
  'directions_walk': Symbols.directions_walk,
  'fitness_center': Symbols.fitness_center,
  'self_improvement': Symbols.self_improvement,
  'spa': Symbols.spa,
  'menu_book': Symbols.menu_book,
  'edit_note': Symbols.edit_note,
  'psychology': Symbols.psychology,
  'flag': Symbols.flag,
  'local_cafe': Symbols.local_cafe,
  'restaurant': Symbols.restaurant,
  'shower': Symbols.shower,
  'bedtime': Symbols.bedtime,
  'wb_sunny': Symbols.wb_sunny,
  'favorite': Symbols.favorite,
  'music_note': Symbols.music_note,
  'school': Symbols.school,
  'laptop': Symbols.laptop,
  'cleaning_services': Symbols.cleaning_services,
  'medication': Symbols.medication,
  'pets': Symbols.pets,
  'call': Symbols.call,
};

IconData stepIcon(String name) => stepIcons[name] ?? Symbols.check_circle;
