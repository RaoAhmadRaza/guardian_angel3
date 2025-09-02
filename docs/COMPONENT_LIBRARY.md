# Guardian Angel Component Library

A comprehensive, accessible, and beautifully designed component library for the Guardian Angel Flutter application.

## 🎨 Features

### ✨ **Developer Experience**
- **Comprehensive Documentation**: Every component has detailed dartdoc comments
- **Live Storybook**: Interactive component previews and development environment
- **Variant Factories**: Pre-configured component variants for common use cases
- **Type Safety**: Full TypeScript-like safety with Dart's strong typing

### ♿ **Accessibility First**
- **Screen Reader Support**: Semantic labels and ARIA-like properties
- **Autofill Hints**: Smart form completion for better UX
- **Haptic Feedback**: Tactile responses for better user engagement
- **Error Announcements**: Screen reader announcements for validation errors

### 🎭 **Beautiful Animations**
- **Smooth Transitions**: 60fps animations with proper easing curves
- **Interactive Feedback**: Visual responses to user interactions
- **State Animations**: Loading states, focus effects, and error animations
- **Performance Optimized**: Efficient animations that don't impact performance

## 📦 Components

### 🔘 **GradientButton**

A versatile gradient button with multiple variants and full accessibility support.

```dart
// Primary action button
GradientButton.primary(
  text: 'Continue',
  onPressed: () => Navigator.push(...),
)

// Secondary action
GradientButton.secondary(
  text: 'Cancel',
  icon: Icons.close,
  onPressed: () => Navigator.pop(),
)

// Destructive action
GradientButton.destructive(
  text: 'Delete Account',
  onPressed: () => showConfirmDialog(),
  semanticLabel: 'Delete your account permanently',
)

// Success action
GradientButton.success(
  text: 'Save Changes',
  icon: Icons.check,
  isLoading: isSaving,
  onPressed: () => saveData(),
)
```

**Features:**
- 4 predefined variants (primary, secondary, destructive, success)
- Loading states with spinner
- Icons and custom content
- Haptic feedback
- Full accessibility support
- Smooth press animations

### 📝 **CustomTextField**

An advanced text input field with validation, animations, and accessibility features.

```dart
// Email input with validation
CustomTextField.email(
  hint: 'Email Address',
  controller: emailController,
  validator: (value) => EmailValidator.validate(value),
  isRequired: true,
)

// Password field with security features
CustomTextField.password(
  hint: 'Password',
  controller: passwordController,
  validator: (value) => PasswordValidator.validate(value),
)

// Phone number with proper keyboard
CustomTextField.phone(
  hint: 'Phone Number',
  controller: phoneController,
)

// Name field with autofill
CustomTextField.name(
  hint: 'Full Name',
  controller: nameController,
  isRequired: true,
)
```

**Features:**
- Type-specific factory constructors
- Built-in validation with animated error messages
- Autofill hints for better UX
- Focus animations and glow effects
- Error state management
- Screen reader announcements
- Semantic labeling

### 🪟 **GlassCard**

A beautiful glassmorphism card for creating modern UI overlays.

```dart
GlassCard(
  child: Column(
    children: [
      Icon(Icons.star, color: Colors.white),
      Text('Glass Content'),
    ],
  ),
  borderRadius: BorderRadius.circular(20),
  blur: 25,
)
```

**Features:**
- Customizable blur effects
- Flexible border radius
- Responsive padding
- Perfect for overlays and modals

## 🛠 Development Tools

### 📚 **Storybook Integration**

Interactive component development and documentation:

```bash
# Run the storybook
flutter run lib/storybook/main.dart
```

The storybook provides:
- Live component previews
- Interactive controls (knobs)
- Different component states
- Dark/light theme testing
- Responsive breakpoint testing

### 🎯 **Usage Examples**

```dart
// Complete form example
class SignUpForm extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          CustomTextField.name(
            hint: 'Full Name',
            controller: nameController,
            validator: (value) => value?.isEmpty == true 
                ? 'Name is required' : null,
          ),
          SizedBox(height: 16),
          CustomTextField.email(
            hint: 'Email Address',
            controller: emailController,
            validator: EmailValidator.validate,
          ),
          SizedBox(height: 16),
          CustomTextField.password(
            hint: 'Password',
            controller: passwordController,
            validator: PasswordValidator.validate,
          ),
          SizedBox(height: 24),
          GradientButton.primary(
            text: 'Create Account',
            isLoading: isCreating,
            onPressed: createAccount,
            semanticLabel: 'Create your new account',
          ),
        ],
      ),
    );
  }
}
```

## ♿ Accessibility Features

### **Screen Reader Support**
All components include proper semantic labeling:
- Buttons announce their purpose and state
- Text fields describe their content and requirements
- Error messages are announced when they appear

### **Keyboard Navigation**
- Full keyboard navigation support
- Proper focus management
- Visual focus indicators

### **Form Accessibility**
- Autofill hints for faster form completion
- Required field indicators
- Associated labels and error messages

## 🎨 Theming Integration

Components automatically adapt to your app's theme:

```dart
MaterialApp(
  theme: AppThemeData.buildLightTheme(context),
  darkTheme: AppThemeData.buildDarkTheme(context),
  // Components automatically use theme colors
)
```

## 📱 Responsive Design

All components are built with responsive design in mind:
- Adaptive typography scaling
- Flexible layouts
- Touch target optimization
- Breakpoint-aware spacing

## 🚀 Performance

### **Optimizations**
- Efficient animations using `AnimationController`
- Minimal rebuilds with proper state management
- Lazy loading for complex components
- Memory-efficient image handling

### **Bundle Size**
- Tree-shakeable components
- Optional features to reduce bundle size
- Optimized dependencies

## 🔧 Customization

### **Theme Integration**
```dart
// Custom gradient button
GradientButton(
  text: 'Custom',
  gradient: LinearGradient(
    colors: [Colors.purple, Colors.pink],
  ),
  onPressed: () {},
)
```

### **Advanced Customization**
```dart
// Fully customized text field
CustomTextField(
  hint: 'Custom Field',
  prefixIcon: Icons.custom_icon,
  keyboardType: TextInputType.custom,
  autofillHints: [AutofillHints.custom],
  semanticLabel: 'Custom input for special data',
  validator: (value) => CustomValidator.validate(value),
)
```

## 📚 Documentation

Each component includes comprehensive documentation:
- Parameter descriptions
- Usage examples
- Accessibility guidelines
- Performance considerations
- Customization options

## 🧪 Testing

Components are built with testing in mind:
- Semantic labels for integration tests
- Proper widget keys
- Testable callbacks
- State management testing support

---

**Built with ❤️ for the Guardian Angel project**

This component library prioritizes user experience, accessibility, and developer productivity while maintaining beautiful design and smooth performance.
