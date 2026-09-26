/// Global application constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Notesboard';

  // Responsive Breakpoints (px)
  static const double mobileBreakpoint = 640;
  static const double tabletBreakpoint = 1024;

  // Canvas Engine Defaults
  static const double minZoom = 0.15;
  static const double maxZoom = 3.0;
  static const double defaultZoom = 1.0;
  static const double zoomStep = 0.15;

  // Grid
  static const double gridSpacing = 24.0;
  static const double gridDotRadius = 1.0;

  // Default Dimensions
  static const double defaultNoteWidth = 220.0;
  static const double defaultNoteHeight = 150.0;
  static const double minNoteWidth = 140.0;
  static const double minNoteHeight = 80.0;

  static const double defaultImageWidth = 240.0;
  static const double defaultImageHeight = 180.0;
  static const double minImageWidth = 120.0;
  static const double minImageHeight = 100.0;

  static const double defaultGroupWidth = 360.0;
  static const double defaultGroupHeight = 260.0;
  static const double minGroupWidth = 180.0;
  static const double minGroupHeight = 140.0;

  // Autosave Debounce Duration
  static const Duration autosaveDebounceDuration = Duration(milliseconds: 350);
}
