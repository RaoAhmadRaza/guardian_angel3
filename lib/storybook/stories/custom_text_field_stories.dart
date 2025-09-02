import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';
import '../../widgets.dart';

/// Stories for CustomTextField component variations.
///
/// This file contains all the different states and configurations
/// of the CustomTextField widget for development and testing.
final List<Story> customTextFieldStories = [
  Story(
    name: 'Inputs/CustomTextField/Basic Types',
    description: 'Different input field types with proper configurations',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField.email(
            hint: 'Email Address',
            controller: TextEditingController(),
          ),
          const SizedBox(height: 16),
          CustomTextField.password(
            hint: 'Password',
            controller: TextEditingController(),
          ),
          const SizedBox(height: 16),
          CustomTextField.phone(
            hint: 'Phone Number',
            controller: TextEditingController(),
          ),
          const SizedBox(height: 16),
          CustomTextField.name(
            hint: 'Full Name',
            controller: TextEditingController(),
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Inputs/CustomTextField/With Validation',
    description: 'Text fields with validation and error states',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField.email(
            hint: 'Email Address',
            controller: TextEditingController(text: 'invalid-email'),
            validator: (value) {
              if (value?.isEmpty == true) return 'Email is required';
              if (!value!.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField.password(
            hint: 'Password',
            controller: TextEditingController(text: '123'),
            validator: (value) {
              if (value?.isEmpty == true) return 'Password is required';
              if (value!.length < 8)
                return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField.name(
            hint: 'Full Name',
            controller: TextEditingController(),
            validator: (value) {
              if (value?.isEmpty == true) return 'Name is required';
              return null;
            },
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Inputs/CustomTextField/Custom Configuration',
    description: 'Fully customizable text field with all options',
    builder: (context) {
      final hint = context.knobs.text(
        label: 'Hint Text',
        initial: 'Enter something...',
      );

      final obscureText = context.knobs.boolean(
        label: 'Obscure Text',
        initial: false,
      );

      final hasIcon = context.knobs.boolean(
        label: 'Show Icon',
        initial: true,
      );

      final hasValidation = context.knobs.boolean(
        label: 'Enable Validation',
        initial: false,
      );

      final keyboardType = context.knobs.options(
        label: 'Keyboard Type',
        initial: 'text',
        options: [
          const Option(label: 'Text', value: 'text'),
          const Option(label: 'Email', value: 'email'),
          const Option(label: 'Phone', value: 'phone'),
          const Option(label: 'Number', value: 'number'),
        ],
      );

      TextInputType? inputType;
      IconData? icon;

      switch (keyboardType) {
        case 'email':
          inputType = TextInputType.emailAddress;
          icon = Icons.email_outlined;
          break;
        case 'phone':
          inputType = TextInputType.phone;
          icon = Icons.phone_outlined;
          break;
        case 'number':
          inputType = TextInputType.number;
          icon = Icons.numbers;
          break;
        default:
          inputType = TextInputType.text;
          icon = Icons.text_fields;
      }

      return Container(
        padding: const EdgeInsets.all(24),
        child: CustomTextField(
          hint: hint,
          obscureText: obscureText,
          keyboardType: inputType,
          prefixIcon: hasIcon ? icon : null,
          controller: TextEditingController(),
          validator: hasValidation
              ? (value) =>
                  value?.isEmpty == true ? 'This field is required' : null
              : null,
          semanticLabel: 'Custom input field',
          semanticHint: 'This is a customizable input field',
        ),
      );
    },
  ),
  Story(
    name: 'Inputs/CustomTextField/States',
    description: 'Different input field states and interactions',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Normal state
          const Text('Normal State:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CustomTextField(
            hint: 'Normal input field',
            prefixIcon: Icons.edit_outlined,
            controller: TextEditingController(),
          ),
          const SizedBox(height: 24),

          // Filled state
          const Text('Filled State:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CustomTextField(
            hint: 'Filled input field',
            prefixIcon: Icons.check_circle_outline,
            controller: TextEditingController(text: 'Sample content'),
          ),
          const SizedBox(height: 24),

          // Error state
          const Text('Error State:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CustomTextField(
            hint: 'Input with error',
            prefixIcon: Icons.error_outline,
            controller: TextEditingController(text: 'Invalid'),
            validator: (value) => 'This field has an error',
          ),
        ],
      ),
    ),
  ),
];
