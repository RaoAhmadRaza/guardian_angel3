# Guardian Angel Design System Specification

**Version:** 1.0  
**Date:** January 1, 2026  
**Status:** Active  

---

## 1. Color System Specification

A comprehensive **Monochromatic Slate & Glass** color system designed for healthcare-grade clarity and premium aesthetics. This system prioritizes high-contrast legibility in Light Mode and a sophisticated "Glassmorphism" hierarchy in Dark Mode.

### 1.1 Foundation / Base Layers
*The canvas upon which all other elements sit.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `bg-primary` | `#FDFDFD` | `#0F0F0F` | Main application background (Scaffold). | Base |
| `bg-secondary` | `#F5F5F7` | `#FFFFFF (5%)` | Secondary backgrounds, avatars, and illustration containers. | Low |
| `surface-primary` | `#FFFFFF` | `#1C1C1E` | Primary cards (Health Summary, Doctor Contact, Automation). | Base |
| `surface-secondary` | `#FFFFFF` | `#2C2C2E` | Nested cards or highlighted sections (Heart Metrics). | Medium |
| `surface-glass` | `N/A` | `#FFFFFF (10%)` | Glassmorphic overlays, icon backgrounds, and decorative shapes. | Low |
| `border-subtle` | `#FFFFFF (30%)` | `#FFFFFF (10%)` | Subtle card borders for definition without harsh lines. | Low |
| `shadow-card` | `#475569 (15%)` | `#000000 (40%)` | Primary elevation shadow for cards (Blur: 16, Y: 6). | N/A |

### 1.2 Containers & Surfaces
*Structural elements that group content.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `container-default` | `#FFFFFF` | `#1C1C1E` | Standard container fill for content grouping. | Base |
| `container-highlight` | `#F5F5F7` | `#2C2C2E` | Highlighted or active container state. | Low |
| `container-slot` | `#F5F5F7` | `#FFFFFF (5%)` | List items, medication slots, or grid items. | Low |
| `container-slot-alt` | `#E0E0E2` | `#FFFFFF (10%)` | Alternating list items (zebra striping). | Low |
| `overlay-modal` | `#FFFFFF (80%)` | `#1A1A1A (80%)` | Background blur overlay for modals (Glassmorphism). | High |

### 1.3 Typography Colors
*Text hierarchy ensuring readability and hierarchy.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `text-primary` | `#0F172A` | `#FFFFFF` | Headings, titles, and primary data values. | High |
| `text-secondary` | `#475569` | `#FFFFFF (70%)` | Subtitles, body text, and secondary labels. | Medium |
| `text-tertiary` | `#64748B` | `#FFFFFF (50%)` | Hints, placeholders, and low-priority metadata. | Low |
| `text-inverse` | `#FFFFFF` | `#0F172A` | Text on high-contrast backgrounds (e.g., primary buttons). | High |
| `text-link` | `#2563EB` | `#60A5FA` | Interactive text elements and links. | High |

### 1.4 Iconography
*Visual symbols and indicators.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `icon-primary` | `#475569` | `#FFFFFF (70%)` | Primary navigation and action icons. | High |
| `icon-secondary` | `#94A3B8` | `#FFFFFF (40%)` | Decorative or low-priority icons. | Low |
| `icon-bg-primary` | `#F5F5F7` | `#FFFFFF (10%)` | Circular background for primary icons. | Low |
| `icon-bg-active` | `#FFFFFF` | `#FFFFFF (10%)` | Background for active/selected icons. | Low |

### 1.5 Interactive Elements
*States for buttons and actionable areas.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `action-primary-bg` | `#FFFFFF` | `#2C2C2E` | Primary action buttons (e.g., "Diagnostic"). | High |
| `action-primary-fg` | `#475569` | `#FFFFFF (80%)` | Text/Icon color on primary action buttons. | High |
| `action-hover` | `#F8FAFC` | `#FFFFFF (5%)` | Hover state overlay. | Low |
| `action-pressed` | `#E2E8F0` | `#000000 (20%)` | Pressed/Active state overlay. | Low |
| `action-disabled-bg` | `#F1F5F9` | `#FFFFFF (5%)` | Disabled button background. | Low |
| `action-disabled-fg` | `#94A3B8` | `#FFFFFF (30%)` | Disabled text/icon color. | Low |

### 1.6 Status & Feedback Colors
*Semantic colors for system communication.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `status-success` | `#059669` | `#34D399` | Positive states, "All Clear", completion. | High |
| `status-warning` | `#D97706` | `#FBBF24` | Warnings, alerts, attention needed. | High |
| `status-error` | `#DC2626` | `#F87171` | Critical errors, "Emergency", failures. | High |
| `status-info` | `#2563EB` | `#60A5FA` | Informational messages, updates. | High |
| `status-neutral` | `#475569` | `#94A3B8` | Inactive or unmonitored states. | Medium |

### 1.7 Input & Control Elements
*Form fields and toggles.*

| Token Name | Light Mode Value | Dark Mode Value | Usage Description | Contrast Role |
| :--- | :--- | :--- | :--- | :--- |
| `input-bg` | `#FEFEFE` | `#1A1A1A` | Text field background. | Base |
| `input-border` | `#E2E8F0` | `#3C4043` | Default input border. | Low |
| `input-border-focus`| `#3B82F6` | `#F8F9FA` | Active input border (Focus state). | High |
| `control-active` | `#2563EB` | `#F5F5F5` | Active state for switches/checkboxes. | High |
| `control-track` | `#E2E8F0` | `#3C4043` | Inactive track for switches/sliders. | Low |

---

## 2. UI & Layout Specification

Built on a **4px base grid** with a strong emphasis on **organic shapes** (large border radii), **glassmorphism**, and **generous whitespace** to create a calm, healthcare-focused interface.

### 2.1 Layout & Spacing System
*Built on a 4px base unit scale (`baseUnit = 4.0`).*

| Token Name | Value (px) | Usage Description |
| :--- | :--- | :--- |
| `space-xs` | `4px` | Minimal separation (e.g., icon to text in compact rows). |
| `space-sm` | `8px` | Tight grouping (e.g., title to subtitle). |
| `space-md` | `12px` | Element separation within a component. |
| `space-lg` | `16px` | Standard separation between related elements. |
| `space-xl` | `20px` | Generous separation (e.g., between sections). |
| `space-2xl` | `24px` | **Primary Padding:** Screen edges, card interiors. |
| `space-3xl` | `32px` | Major section breaks. |
| `space-4xl` | `40px` | Significant whitespace (e.g., bottom of scroll view). |

**Grid & Container Logic:**
*   **Screen Padding:** `20px` (Mobile) / `24px` (Tablet+).
*   **Card Padding:** `24px` (Standard) / `14px` (Compact/Grid items).
*   **Bottom Safe Area:** `120px` padding at bottom of scroll views to clear floating navigation.

### 2.2 Shape & Surface System
*Defines the physical feel of the interface.*

**Border Radii (Organic & Friendly):**
| Token Name | Value | Usage |
| :--- | :--- | :--- |
| `radius-sm` | `6px` | Small inner elements (e.g., icon backgrounds). |
| `radius-md` | `12px` | Buttons, input fields, small containers. |
| `radius-lg` | `16px` | Standard cards, images. |
| `radius-xl` | `20px` | Featured cards (Metrics, Automation). |
| `radius-2xl` | `24px` | **Primary Card Shape:** Main containers. |
| `radius-3xl` | `28px` | Large organic containers (Automation Grid). |
| `radius-full` | `999px` | Avatars, icon circles, pill buttons. |

**Shadows & Elevation (Soft & Diffused):**
*   **Card Shadow:** `Blur: 16`, `Offset: 0, 6`, `Color: Black (15% Light / 40% Dark)`.
*   **Floating Shadow:** `Blur: 24`, `Offset: 0, 8`, `Color: Black (5% Light / 20% Dark)`.
*   **Inner Shadow:** Not used; depth is achieved via borders and background opacity.

**Glassmorphism (The "Crystal" Effect):**
*   **Blur Strength:** `SigmaX: 10`, `SigmaY: 10`.
*   **Border:** `1px` solid, `White (10-30%)` opacity.
*   **Fill:** `White (5-10%)` opacity in Dark Mode, `White (70-90%)` in Light Mode.

### 2.3 Typography System
*Hierarchy designed for clarity and scanning.*

| Token Name | Size | Weight | Letter Spacing | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `display-lg` | `28px` | `700 (Bold)` | `0` | Major status (e.g., "All Clear"). |
| `display-md` | `24px` | `700 (Bold)` | `-0.4` | Section headers ("Home Automation"). |
| `heading-lg` | `22px` | `700 (Bold)` | `0` | Card titles ("Read Newspaper"). |
| `heading-md` | `20px` | `600 (SemiBold)` | `0` | Greetings, sub-headers. |
| `heading-sm` | `18px` | `600 (SemiBold)` | `0` | Doctor name, small card titles. |
| `body-lg` | `16px` | `700 (Bold)` | `-0.1` | Data values (Heart rate). |
| `body-md` | `14px` | `600 (SemiBold)` | `-0.2` | Labels, button text. |
| `body-sm` | `14px` | `400 (Regular)` | `0` | Subtitles, descriptions. |
| `caption` | `11px` | `400 (Regular)` | `-0.1` | Secondary metadata. |

---

## 3. Generic Component Patterns

Abstracted implementation details into reusable design patterns applicable across the entire application.

### 3.1 Global Header Pattern
*Standardized top-level identity and navigation block.*
*   **Structure:** Horizontal Row (`CrossAxisAlignment.center`).
*   **Leading Element:** `50x50` Circular Avatar / Identity Indicator with `shadow-card`.
*   **Content Area:** Flexible column for Greeting/Title (Primary Text) and Subtitle (Secondary Text).
*   **Trailing Action:** `40x40` Circular Icon Button (Notification/Settings) with `bg-surface` and `shadow-card`.
*   **Spacing:** `space-lg` (16px) between elements.

### 3.2 Hero Card Component
*High-emphasis container for the screen's primary data summary.*
*   **Container:** `radius-2xl` (24px), `padding-2xl` (24px).
*   **Layout:** Asymmetric Row (typically 2:1 flex ratio).
*   **Visual Anchor:** Large Circular Icon Container (`48x48`) with semantic color background.
*   **Typography:** Uses `display-md` or `heading-lg` for titles to establish hierarchy.
*   **Interaction:** Full-card touch target (`InkWell`) with `HapticFeedback.lightImpact()`.
*   **Usage:** Primary health status, main dashboard summary, active call status.

### 3.3 Compact Metric Tile
*Standardized grid item for secondary data points.*
*   **Dimensions:** Fixed height (typically `100px`) for uniform grid alignment.
*   **Padding:** `14px` (Compact) to maximize internal space.
*   **Decoration:** Glassmorphic surface (`BackdropFilter` + `surface-glass`).
*   **Internal Layout:**
    *   **Top:** Row with Small Icon (`18px` in padded box) + Label (`body-md`).
    *   **Middle:** `Spacer()` to push content to edges.
    *   **Bottom:** Data Value (`body-lg` / `heading-sm`).
*   **Usage:** Vitals grid, environmental sensors, quick stats.

### 3.4 Content List Card
*Horizontal card pattern for items within a collection.*
*   **Container:** `radius-xl` (20px) or `radius-3xl` (28px) for grouped sections.
*   **Animation:** Staggered Entrance (Slide-up `8px` + Fade-in `600ms`).
*   **Typography:** Optimized for density—tight line heights (`1.1` - `1.2`) and negative letter spacing.
*   **Visuals:** Consistent icon alignment (Top-Left) with semantic color coding.
*   **Usage:** Automation devices, medication schedules, task lists, notification items.

### 3.5 Empty State Container
*Standardized placeholder for null or loading states.*
*   **Container:** Inherits standard card decoration (Border + Shadow).
*   **Layout:** Horizontal Row.
*   **Visual:** Muted Icon (`24px`) in a low-opacity container (`8px` padding).
*   **Message:** Secondary Text (`body-md`) with reduced opacity (`50%`).
*   **Usage:** "No devices connected", "No medications added", "No recent activity".

### 3.6 Secondary Action Buttons
*Standardized touch targets for auxiliary actions.*
*   **Circular Action:** `44x44` Circle, `bg-secondary` (Light) / `bg-glass` (Dark). Used for quick actions like "Call" or "Message".
*   **Inline Action:** Glassmorphic Pill (`radius-xl`), `padding-horizontal: 24px`, `padding-vertical: 12px`. Used for "See More" or "Edit" actions within sections.
*   **State:** Distinct disabled state with reduced opacity (`30-50%`) and grayscale conversion.

### 3.7 Section Container
*Wrapper for grouping related content blocks.*
*   **Background:** Theme-aware fill (`bg-surface` or `bg-primary`).
*   **Border:** `radius-3xl` (28px) – distinctly rounder than inner cards to create a "nesting" visual cue.
*   **Shadow:** Enhanced floating shadow (`blur-2xl`) to lift the entire section.
*   **Header:** `display-md` title with `space-2xl` bottom padding before content.
*   **Usage:** Grouping automation controls, settings groups, or complex form sections.
