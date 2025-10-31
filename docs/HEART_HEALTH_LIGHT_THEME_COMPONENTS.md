# 🫀 Heart Health Components - Light Theme

## Complete Color Scheme & Gradient Documentation for Guardian Angel Light Theme

---

## **Main Heart Health Card Container**

### **Container Structure**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Color(0xFFFFFFFF),  // Pure white surface
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF475569).withOpacity(0.15),  // Soft gray shadow
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
    color: Color(0xFFF5F5F7),  // Light gray background
    shape: BoxShape.circle,
  ),
  child: Icon(
    CupertinoIcons.heart_fill,
    color: Color(0xFF475569),  // Medium slate gray
    size: 24,
  ),
)
```

### **Heart Illustration Container**
```dart
Container(
  height: 120,
  decoration: BoxDecoration(
    color: Color(0xFFF5F5F7),  // Light gray background
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
    color: Color(0xFFF5F5F7),  // Light gray background
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Color(0xFFE0E0E2),  // Gentle cool gray border
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
        color: Color(0xFF475569),  // Medium slate - button text
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
    color: Color(0xFFFFFFFF),  // Pure white
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF475569).withOpacity(0.15),  // Soft shadow
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
        color: Color(0xFF475569),  // Medium slate gray
        size: 24,
      ),
      const SizedBox(height: 12),
      Text(
        'Heart pressure',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),  // Medium slate - label
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '120/80',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),  // Deep slate - value
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
    color: Color(0xFFFFFFFF),  // Pure white
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF475569).withOpacity(0.15),  // Soft shadow
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
        color: Color(0xFF475569),  // Medium slate gray
        size: 24,
      ),
      const SizedBox(height: 12),
      Text(
        'Heart rhythm',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),  // Medium slate - label
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '72 / min',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),  // Deep slate - value
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
    color: Color(0xFFF8FAFC),  // Very light gray-blue background
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Color(0xFFE2E8F0),  // Subtle gray border
      width: 1,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.favorite,
        color: Color(0xFFEF4444),  // Medical red heart icon
        size: 16,
      ),
      const SizedBox(height: 8),
      Text(
        '72 BPM',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),  // Deep slate - value
        ),
      ),
      Text(
        'Heart Rate',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),  // Light slate - label
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
        Color(0xFF4F46E5),  // Indigo
        Color(0xFF7C3AED),  // Purple
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF475569).withOpacity(0.15),
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

## **Gradient System - Light Theme**

### **Primary Background Gradients**
```dart
// Light Primary Gradient
static const LinearGradient lightPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFDFDFD),  // Off-white
    Color(0xFFF5F5F7),  // Light cloud gray
    Color(0xFFE0E0E2),  // Gentle cool gray
  ],
);

// Light Secondary Gradient
static const LinearGradient lightSecondaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFDFDFD),  // Off-white
    Color(0xFFF5F5F7),  // Light cloud gray
    Color(0xFFE0E0E2),  // Gentle cool gray
  ],
);

// Light Button Gradient
static const LinearGradient lightButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFDFDFD),  // Off-white
    Color(0xFFF5F5F7),  // Light cloud gray
    Color(0xFFE0E0E2),  // Gentle cool gray
  ],
);
```

### **Medical & Health Gradients**
```dart
// Medical Blue Gradient
static const LinearGradient medicalBlueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF2563EB),  // Medical blue primary
    Color(0xFF3B82F6),  // Medical blue lighter
  ],
);

// Heart Health Gradient
static const LinearGradient heartHealthGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFEF4444),  // Medical red
    Color(0xFFF87171),  // Light red
  ],
);
```

---

## **Shadow System - Light Theme**

### **Card Shadows**
```dart
// Light Card Shadow
static List<BoxShadow> lightCardShadow = [
  BoxShadow(
    color: Color(0xFF475569).withOpacity(0.08),  // Soft primary shadow
    blurRadius: 25,
    offset: const Offset(0, 1),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF475569).withOpacity(0.05),  // Ambient shadow
    blurRadius: 45,
    offset: const Offset(0, 10),
    spreadRadius: 0,
  ),
];

// Light Card Shadow Elevated
static List<BoxShadow> lightCardShadowElevated = [
  BoxShadow(
    color: Color(0xFF475569).withOpacity(0.12),  // Strong primary shadow
    blurRadius: 35,
    offset: const Offset(0, 2),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF475569).withOpacity(0.08),  // Deep ambient shadow
    blurRadius: 60,
    offset: const Offset(0, 15),
    spreadRadius: 0,
  ),
];
```

### **Button Shadows**
```dart
// Light Button Shadow
static List<BoxShadow> lightButtonShadow = [
  BoxShadow(
    color: Color(0xFF3B82F6).withOpacity(0.15),  // Blue button shadow
    blurRadius: 20,
    offset: const Offset(0, 2),
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0xFF1E40AF).withOpacity(0.08),  // Deep blue ambient
    blurRadius: 35,
    offset: const Offset(0, 8),
    spreadRadius: 0,
  ),
];
```

---

## **Typography Colors - Light Theme**

### **Text Hierarchy**
```dart
// Primary Text Colors
static const Color lightTextPrimary = Color(0xFF0F172A);     // Deep slate - headlines
static const Color lightTextSecondary = Color(0xFF475569);   // Medium slate - body text
static const Color lightTextTertiary = Color(0xFF64748B);    // Light slate - supporting text
static const Color lightTextQuaternary = Color(0xFF94A3B8);  // Subtle gray - captions
static const Color lightTextDisabled = Color(0xFFCBD5E1);   // Muted gray - disabled text
static const Color lightTextPlaceholder = Color(0xFF9CA3AF); // Placeholder text

// Medical Text Colors
static const Color medicalTextSuccess = Color(0xFF059669);   // Health green
static const Color medicalTextWarning = Color(0xFFD97706);   // Medical amber
static const Color medicalTextError = Color(0xFFDC2626);     // Medical red
static const Color medicalTextInfo = Color(0xFF2563EB);      // Medical blue
```

---

## **Surface & Background Colors - Light Theme**

### **Background Colors**
```dart
static const Color lightBackground = Color(0xFFFDFDFD);           // Ultra-soft off-white
static const Color lightBackgroundSecondary = Color(0xFFFAFAFA); // Subtle cream background
static const Color lightSurface = Color(0xFFFEFEFE);             // Primary card surface
static const Color lightSurfaceVariant = Color(0xFFF9FAFB);      // Secondary surfaces
static const Color lightSurfaceElevated = Color(0xFFF4F6F8);     // Elevated elements
static const Color lightCard = Color(0xFFFFFFFF);                // Pure white emphasis
static const Color lightOverlay = Color(0xFFF1F3F5);             // Disabled overlays
```

### **Border Colors**
```dart
static const Color lightBorder = Color(0xFFE2E8F0);        // Primary borders
static const Color lightBorderVariant = Color(0xFFF1F5F9); // Secondary borders
static const Color lightBorderAccent = Color(0xFFCBD5E1);  // Accent borders
static const Color lightBorderFocus = Color(0xFF3B82F6);   // Focus borders
static const Color lightDivider = Color(0xFFE5E7EB);       // Standard dividers
```

---

## **Interactive States - Light Theme**

### **Hover & Focus States**
```dart
static const Color lightHover = Color(0xFFF8FAFC);           // Primary hover
static const Color lightHoverSecondary = Color(0xFFF1F5F9); // Secondary hover
static const Color lightPressed = Color(0xFFE2E8F0);        // Primary pressed
static const Color lightPressedSecondary = Color(0xFFCBD5E1); // Secondary pressed
static const Color lightFocused = Color(0xFF3B82F6);        // Blue focus indicator
static const Color lightFocusBackground = Color(0xFFEFF6FF); // Focus background
static const Color lightSelected = Color(0xFFEBF4FF);       // Selected background
static const Color lightSelectedBorder = Color(0xFF93C5FD); // Selected border
```

---

## **Medical & Health Specific Colors**

### **Heart Health Colors**
```dart
static const Color heartIconRed = Color(0xFFEF4444);      // Medical red for heart icons
static const Color heartIconGray = Color(0xFF475569);     // Gray for secondary heart icons
static const Color heartRateText = Color(0xFF0F172A);     // Heart rate values
static const Color heartRateLabel = Color(0xFF475569);    // Heart rate labels
```

### **Medical Status Colors**
```dart
static const Color medicalSuccess = Color(0xFF059669);    // Healthy status
static const Color medicalWarning = Color(0xFFD97706);    // Caution status
static const Color medicalError = Color(0xFFDC2626);      // Critical status
static const Color medicalInfo = Color(0xFF2563EB);       // Information status
```

### **Healthcare UI Elements**
```dart
static const Color diagnosticButton = Color(0xFFF5F5F7);  // Diagnostic button background
static const Color diagnosticBorder = Color(0xFFE0E0E2);  // Diagnostic button border
static const Color healthCardSurface = Color(0xFFFFFFFF); // Health card background
static const Color metricsContainer = Color(0xFFF8FAFC); // Metrics container background
```
