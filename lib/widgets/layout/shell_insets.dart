import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

/// Marge bas des listes d’onglets.
/// Le [Scaffold] place déjà le body au-dessus de la [NavigationBar] :
/// on ajoute seulement une marge de confort pour que le dernier bloc
/// puisse défiler entièrement (évite le texte « coupé » en bas).
double shellBottomPadding(BuildContext context, {double extra = 48}) {
  final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
  return AppSpacing.xl + extra + systemBottom;
}
