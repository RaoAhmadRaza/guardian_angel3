# 🫀 Heart Health Components - Dark Theme

## Complete Color Scheme & Gradient Documentation for Guardian Angel Dark Theme

---

## **Main Heart Health Card Container**

### **Container Structure**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A2A),  // Deep charcoal surface
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),  // Deep black shadow
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  ),
)
```

### **Heart Icon Circle**
```dart
Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),  // Semi-transparent white
    shape: BoxShape.circle,
  ),
  child: Icon(
    CupertinoIcons.heart_fill,
    color: Colors.white.withOpacity(0.7),  // Semi-transparent white
    size: 24,
  ),
)
```

### **Heart Illustration Container**
```dart
Container(
  height: 120,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),  // Very subtle white tint
    borderRadius: BorderRadius.circular(16),
  ),
  child: Center(
    child: Image.asset(
      'images/heart.png',
      width: 400,
      height: 200,
      fit: BoxFit.cover,
    ),
  ),
)
```

### **Diagnostic Button**
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),  // Semi-transparent white
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),  // Semi-transparent white border
      width: 1,
    ),
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Text(
      'Diagnostic',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.8),  // Semi-transparent white text
      ),
    ),
  ),
)
```

---

## **Heart Health Metrics Cards**

### **Heart Pressure Card**
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A2A),  // Deep charcoal
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),  // Deep shadow
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        CupertinoIcons.heart,
        color: Colors.white.withOpacity(0.7),  // Semi-transparent white
        size: 24,
      ),
      const SizedBox(height: 12),
      Text(
        'Heart pressure',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.7),  // Semi-transparent white - label
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '120/80',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,  // Pure white - value
        ),
      ),
    ],
  ),
)
```

### **Heart Rhythm Card**
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A2A),  // Deep charcoal
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),  // Deep shadow
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        CupertinoIcons.waveform,
        color: Colors.white.withOpacity(0.7),  // Semi-transparent white
        size: 24,
      ),
      const SizedBox(height: 12),
      Text(
        'Heart rhythm',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.7),  // Semi-transparent white - label
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '72 / min',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,  // Pure white - value
        ),
      ),
    ],
  ),
)
```

---

## **Caregiver Heart Health Components**

### **Heart Rate Metric Container**
```dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),  // Subtle white tint
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),  // Semi-transparent border
      width: 1,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.favorite,
        color: Color(0xFFEF4444),  // Medical red heart icon (same as light)
        size: 16,
      ),
      const SizedBox(height: 8),
      Text(
        '72 BPM',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,  // Pure white - value
        ),
      ),
      Text(
        'Heart Rate',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.7),  // Semi-transparent white - label
        ),
      ),
    ],
  ),
)
```

### **Caregiver Profile Avatar**
```dart
Container(
  width: 56,
  height: 56,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      colors: [
        Color(0xFF6366F1),  // Indigo (darker variant)
        Color(0xFF8B5CF6),  // Violet (darker variant)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Icon(
    Icons.person,
    color: Colors.white,
    size: 28,
  ),
)
```

---

## **Gradient System - Dark Theme**

### **Primary Background Gradients**
```dart
// Dark Primary Gradient
static const LinearGradient darkPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0F0F0F),  // Rich black
    Color(0xFF1A1A1A),  // Deep charcoal
    Color(0xFF202124),  // Elevated charcoal
  ],
  stops: [0.0, 0.6, 1.0],
);

// Dark Secondary Gradient
static const LinearGradient darkSecondaryGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF1A1A1A),  // Deep charcoal
    Color(0xFF2D2D30),  // Rich gray
  ],
);

// Dark Button Gradient
static const LinearGradient darkButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF8F9FA),  // Pure light
    Color(0xFFE8EAED),  // Off-white
  ],
);
```

### **Medical & Health Gradients**
```dart
// Dark Medical Blue Gradient
static const LinearGradient darkMedicalBlueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF60A5FA),  // Lighter medical blue for dark theme
    Color(0xFF93C5FD),  // Even lighter blue
  ],
);

// Dark Heart Health Gradient
static const LinearGradient darkHeartHealthGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFEF4444),  // Medical red (same intensity)
    Color(0xFFF87171),  // Light red
  ],
);
```

---

## **Shadow System - Dark Theme**

### **Card Shadows**
```dart
// Dark Card Shadow
static List<BoxShadow> darkCardShadow = [
  BoxShadow(
    color: Color(0xFF000000).withOpacity(0.4),  // Deep black shadow
    blurRadius: 24,
    offset: const Offset(0, 4),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF000000).withOpacity(0.2),  // Ambient darkness
    blurRadius: 48,
    offset: const Offset(0, 12),
    spreadRadius: 0,
  ),
];

// Dark Card Shadow Elevated
static List<BoxShadow> darkCardShadowElevated = [
  BoxShadow(
    color: Color(0xFF000000).withOpacity(0.5),  // Stronger shadow
    blurRadius: 32,
    offset: const Offset(0, 6),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF000000).withOpacity(0.3),  // Deep ambient shadow
    blurRadius: 64,
    offset: const Offset(0, 16),
    spreadRadius: 0,
  ),
];
```

### **Button Shadows**
```dart
// Dark Button Shadow
static List<BoxShadow> darkButtonShadow = [
  BoxShadow(
    color: Color(0xFFF8F9FA).withOpacity(0.1),  // Subtle light glow
    blurRadius: 20,
    offset: const Offset(0, 4),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF000000).withOpacity(0.3),  // Depth shadow
    blurRadius: 16,
    offset: const Offset(0, 2),
    spreadRadius: 0,
  ),
];
```

---

## **Typography Colors - Dark Theme**

### **Text Hierarchy**
```dart
// Primary Text Colors
static const Color darkTextPrimary = Color(0xFFF8F9FA);     // Pure light - headlines
static const Color darkTextSecondary = Color(0xFFE8EAED);   // Off-white - body text
static const Color darkTextTertiary = Color(0xFF9AA0A6);    // Medium gray - supporting text
static const Color darkTextDisabled = Color(0xFF5F6368);    // Muted gray - disabled text
static const Color darkTextPlaceholder = Color(0xFF80868B); // Subtle placeholder text

// Medical Text Colors (lighter variants for dark theme)
static const Color darkMedicalTextSuccess = Color(0xFF34D399);   // Light green
static const Color darkMedicalTextWarning = Color(0xFFFBBF24);   // Light amber
static const Color darkMedicalTextError = Color(0xFFF87171);     // Light red
static const Color darkMedicalTextInfo = Color(0xFF60A5FA);      // Light blue
```

---

## **Surface & Background Colors - Dark Theme**

### **Background Colors**
```dart
static const Color darkBackground = Color(0xFF0F0F0F);           // Rich black - main background
static const Color darkSurface = Color(0xFF1A1A1A);             // Deep charcoal - cards, modals
static const Color darkSurfaceVariant = Color(0xFF202124);      // Elevated charcoal - alternate surfaces
static const Color darkCard = Color(0xFF1A1A1A);                // Rich card background
static const Color darkOverlay = Color(0xFF2D2D30);             // Dark overlay - disabled states
static const Color darkElevated = Color(0xFF2D2D30);            // Elevated surfaces
```

### **Border Colors**
```dart
static const Color darkBorder = Color(0xFF3C4043);              // Subtle boundaries
static const Color darkBorderVariant = Color(0xFF2D2D30);       // Softer boundaries
static const Color darkBorderAccent = Color(0xFF5F6368);        // Accent borders
static const Color darkBorderFocus = Color(0xFFF8F9FA);         // Focus borders
static const Color darkDivider = Color(0xFF3C4043);             // Clean dark separation
```

---

## **Interactive States - Dark Theme**

### **Hover & Focus States**
```dart
static const Color darkHover = Color(0xFF202124);               // Gentle hover elevation
static const Color darkHoverSecondary = Color(0xFF2D2D30);      // Secondary hover
static const Color darkPressed = Color(0xFF2D2D30);             // Subtle press feedback
static const Color darkPressedSecondary = Color(0xFF3C4043);    // Secondary pressed
static const Color darkFocused = Color(0xFFF8F9FA);             // Crisp focus indicator
static const Color darkFocusBackground = Color(0xFF1A1A1A);     // Focus background
static const Color darkSelected = Color(0xFF1A73E8);            // Professional blue selection
static const Color darkSelectedBorder = Color(0xFF60A5FA);      // Selected border
```

---

## **Medical & Health Specific Colors - Dark Theme**

### **Heart Health Colors**
```dart
static const Color darkHeartIconRed = Color(0xFFEF4444);        // Medical red (maintains visibility)
static const Color darkHeartIconWhite = Color(0xFFF8F9FA);      // White for secondary heart icons
static const Color darkHeartRateText = Color(0xFFF8F9FA);       // Heart rate values
static const Color darkHeartRateLabel = Color(0xFFE8EAED);      // Heart rate labels
```

### **Medical Status Colors**
```dart
static const Color darkMedicalSuccess = Color(0xFF34D399);      // Light green for healthy status
static const Color darkMedicalWarning = Color(0xFFFBBF24);      // Light amber for caution
static const Color darkMedicalError = Color(0xFFF87171);        // Light red for critical
static const Color darkMedicalInfo = Color(0xFF60A5FA);         // Light blue for information
```

### **Healthcare UI Elements**
```dart
static const Color darkDiagnosticButton = Color(0xFF202124);    // Diagnostic button background
static const Color darkDiagnosticBorder = Color(0xFF3C4043);    // Diagnostic button border
static const Color darkHealthCardSurface = Color(0xFF1A1A1A);   // Health card background
static const Color darkMetricsContainer = Color(0xFF202124);    // Metrics container background
```

---

## **Glass Morphism Effects - Dark Theme**

### **Glass Effect Container**
```dart
BoxDecoration getDarkGlassEffect({Color? color}) {
  return BoxDecoration(
    color: (color ?? Color(0xFF1A1A1A)).withOpacity(0.8),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: Color(0xFF3C4043).withOpacity(0.2),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF000000).withOpacity(0.4),
        blurRadius: 32,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0xFFF8F9FA).withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, -4),
      ),
    ],
  );
}
```

---

## **Opacity & Transparency System**

### **Standard Opacity Values**
```dart
// White overlay opacities for dark theme
static const double darkOverlayMinimal = 0.05;      // Very subtle white tint
static const double darkOverlaySubtle = 0.1;        // Subtle white overlay
static const double darkOverlayMedium = 0.2;        // Medium white overlay
static const double darkOverlayStrong = 0.3;        // Strong white overlay

// Text opacity values
static const double darkTextPrimaryOpacity = 1.0;    // Full opacity for primary text
static const double darkTextSecondaryOpacity = 0.8;  // Secondary text
static const double darkTextTertiaryOpacity = 0.7;   // Tertiary text
static const double darkTextQuaternaryOpacity = 0.5; // Quaternary text
static const double darkTextDisabledOpacity = 0.3;   // Disabled text
```

### **Shadow Opacity Values**
```dart
// Shadow opacity values for dark theme
static const double darkShadowLight = 0.2;          // Light shadows
static const double darkShadowMedium = 0.3;         // Medium shadows
static const double darkShadowStrong = 0.4;         // Strong shadows
static const double darkShadowHeavy = 0.5;          // Heavy shadows
```

---

## **Animation & Transition Colors**

### **Heart Beat Animation Colors**
```dart
// Heart beat animation for dark theme
Color darkHeartBeatStart = Color(0xFFEF4444);        // Medical red
Color darkHeartBeatEnd = Color(0xFFF87171);          // Lighter red
Color darkHeartBeatGlow = Color(0xFFEF4444).withOpacity(0.3); // Glow effect
```

### **Pulse Animation Colors**
```dart
// Pulse animation for health metrics
Color darkPulseStart = Colors.white.withOpacity(0.1);
Color darkPulseEnd = Colors.white.withOpacity(0.3);
Color darkPulseFocus = Color(0xFF60A5FA).withOpacity(0.2);
```

---

## **Accessibility & Contrast**

### **High Contrast Mode Colors**
```dart
// High contrast variants for accessibility
static const Color darkHighContrastText = Color(0xFFFFFFFF);    // Pure white text
static const Color darkHighContrastBorder = Color(0xFFFFFFFF);  // Pure white borders
static const Color darkHighContrastFocus = Color(0xFF60A5FA);   // Bright blue focus
static const Color darkHighContrastBackground = Color(0xFF000000); // Pure black background
```

### **WCAG AA+ Compliant Colors**
```dart
// Contrast ratios optimized for dark theme
static const Color darkTextAAA = Color(0xFFFFFFFF);             // 21:1 contrast ratio
static const Color darkTextAA = Color(0xFFF8F9FA);              // 16.75:1 contrast ratio
static const Color darkTextAMedium = Color(0xFFE8EAED);         // 12.5:1 contrast ratio
static const Color darkTextALarge = Color(0xFF9AA0A6);          // 7.2:1 contrast ratio
```
