# UI-SPEC — Hanoi Travel Planner (Flutter Web)

> Spec for implementing 5 mobile mockups in **Flutter Web**.
> Source images: `Main.png`, `ExplorePage.png`, `AIChatbot.png`, `MyTripPage.png`, `ProfilePage.png`.
> Always look at the PNG next to this file. Where this spec and the PNG disagree, **the PNG wins for visuals, this spec wins for behavior and data**.

---

## 0. How to read this spec

- Values marked `~` are **estimated from the mockups** (the PNGs have different resolutions). Match proportions visually; sample exact colors with an eyedropper if needed.
- Sizes are in Flutter logical pixels (dp) assuming a **390 dp wide** phone frame.
- UI copy is quoted exactly as shown in the mockups. Do not translate or "fix" it unless told to (see §10, localization).
- Anything not drawn in the mockups is listed in §11 as **Not designed**. Do not invent full screens for those; use a stub/placeholder page.

---

## 1. Screens overview

| # | Screen | Mockup | Route | Bottom nav | Active tab |
|---|--------|--------|-------|-----------|-----------|
| 1 | Home | `Main.png` | `/` | yes | Home |
| 2 | Explore | `ExplorePage.png` | `/explore` | yes | Explore |
| 3 | AI Chatbot | `AIChatbot.png` | `/ai` | **no** (full-screen) | — |
| 4 | My Trip | `MyTripPage.png` | `/trips` | yes | My Trip |
| 5 | Profile | `ProfilePage.png` | `/profile` | yes | Profile |

Navigation rules:
- Tabs Home / Explore / My Trip / Profile live in a shell route (shared bottom nav).
- The center **AI** button pushes `/ai` on top of the shell (no bottom nav, has a back button).
- Home search bar's **AI** button, Home's **Generate My Itinerary →** button, and the center nav **AI** button all open `/ai`. If the search field has text, pass it as the first user message.

---

## 2. Design tokens

### 2.1 Colors (estimated)

```dart
class AppColors {
  // Backgrounds
  static const bgTop        = Color(0xFFFDF6EC); // cream
  static const bgBottom     = Color(0xFFF5E4D0); // warm beige
  static const surface      = Color(0xFFFFFBF5); // cards (use ~85% opacity over bg)
  static const surfaceTint  = Color(0xFFF6E7D4); // active nav pill, stat panel, inactive chips

  // Brand
  static const primary      = Color(0xFF8A4A2A); // brown: buttons, active tabs, icons
  static const primaryLight = Color(0xFFA9653D); // gradient start
  static const primaryDark  = Color(0xFF6E3418); // gradient end

  // Text
  static const textPrimary   = Color(0xFF4A2012); // headings, titles (very dark brown)
  static const textSecondary = Color(0xFF7B5A48); // subtitles, descriptions
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Lines
  static const outline  = Color(0xFFD9B99A); // outlined buttons, borders
  static const divider  = Color(0xFFEBD5BE);

  // Accent
  static const star     = Color(0xFFF2A93B); // rating star
  static const flame    = Color(0xFFE8742A); // "Popular" flame icon
  static const pin      = Color(0xFFB23A2A); // location pin in itinerary cards (red-brown)

  // Chat
  static const userBubble = Color(0xFFF5DDB9);
  static const aiBubble   = Color(0xFFFFFCF7);

  // Status chips (My Trip)
  static const upcomingBg = Color(0xFFFBE4A6);
  static const upcomingFg = Color(0xFF9A6B12);
  static const completedBg = Color(0xFFDCE3BD);
  static const completedFg = Color(0xFF5B7330);
}
```

Primary gradient (buttons, active tab pills, AI FAB, send button): `LinearGradient(begin: topLeft, end: bottomRight, colors: [primaryLight, primaryDark])`.

Page background: vertical gradient `bgTop → bgBottom`, plus a faint watercolor/paper texture (optional; a plain gradient is acceptable).

### 2.2 Typography

Two families, both must support **Vietnamese** glyphs (use the `google_fonts` package):

| Role | Font | Notes |
|------|------|-------|
| Display / titles | **Playfair Display** (serif) | Bold. Page titles are *bold italic*. Card titles are bold, upright. |
| Body / UI | **Nunito Sans** (sans) | Regular / SemiBold |

| Style | Font | Size / weight | Color | Used for |
|-------|------|---------------|-------|----------|
| `pageTitle` | Playfair, bold italic | ~34 (Home hero ~40) | textPrimary | "Explore Hanoi", "My Trip", "Profile", "Hanoi Travel Planner" |
| `pageSubtitle` | Playfair, italic | ~14 | textSecondary | "Discover must-visit places in Hanoi" |
| `sectionTitle` | Playfair, bold italic | ~20 | textPrimary | "Popular Places in Hanoi" |
| `cardTitle` | Playfair, bold | ~17–18 | textPrimary | Place name, trip name, stop name |
| `body` | Nunito Sans, regular | ~14 | textPrimary / textSecondary | Descriptions, chat text (chat text ~16) |
| `bodyStrong` | Nunito Sans, semibold | ~14–15 | textPrimary | Menu item titles, chat "Sáng:" labels |
| `caption` | Nunito Sans, regular | ~12–13 | textSecondary | District, duration, dates |
| `button` | Nunito Sans, semibold | ~15 | on primary / primary | All buttons and chips |

### 2.3 Shape, spacing, elevation

| Token | Value |
|-------|-------|
| Page horizontal padding | 16 |
| Card radius | 20–24 |
| Image thumbnail radius | 16 |
| Buttons / chips / search | fully rounded (pill) |
| Spacing scale | 4, 8, 12, 16, 20, 24 |
| Card shadow | soft: `BoxShadow(color: primary @ 8–10%, blurRadius: 16, offset: (0, 4))` |
| Card background | `surface` with a 1 px `divider` border (very subtle) |
| Min tap target | 44 × 44 |

### 2.4 Icons

Outline style, 1.5–2 px stroke, color `primary` (inactive) — closest match is **Material Symbols Rounded / Outlined**. The icon set used in the mockups: search, auto_awesome (sparkles), calendar, location pin, clock, people, edit/pencil, map, info (circle), bookmark, chevron_right, favorite (outline + filled), more_vert, arrow_back, image, send, home, explore (compass), work/luggage (briefcase), person, flight, star, tune (sliders), grid_view, account_balance (Historical), eco (leaf, Nature), theater_comedy (masks, Culture), restaurant (fork/knife, Food), settings, help_outline, history, logout, mail, phone, local_fire_department (flame), payments/savings (money bag), my_location/ads_click (target), description (document with lines).

---

## 3. Shared components

### 3.1 `PageHeader`
Used by Home, Explore, My Trip, Profile, AI Chatbot.

- Full-width banner area (height ~150–200) with a **watercolor illustration**: yellow blossom branch top-left, Hoan Kiem Lake / Turtle Tower on the right (Profile uses a traditional Vietnamese house instead). The illustration fades into the page background.
- Title + subtitle overlaid on the left (see typography).
- Optional leading icon before the title (calendar for My Trip, person for Profile).
- Optional trailing action (e.g. **+ Create Trip** button on My Trip).
- Implement as a `Stack`: background `Image.asset` (aligned top-right, `BoxFit.cover`, with a gradient fade at the bottom to page bg) + `SafeArea` content.

### 3.2 `AppBottomNav` (floating)
- Floating rounded container (radius ~28), `surface` color, soft shadow, inset 8–12 from screen edges and bottom. Height ~72.
- 5 slots, in order: **Home, Explore, AI (center), My Trip, Profile**.
- Normal item: icon (24) above label (12). Inactive = outline icon + `textPrimary` label. **Active** = icon + label inside a rounded `surfaceTint` pill (radius ~20), icon filled/`primary`.
- **Center AI button**: circle ~64 dp, primary gradient, white sparkles icon + white "AI" label under it, raised ~16 dp above the bar, white ring/border (~4) and shadow. It is an action, never "selected".
- Active tab per screen: see §1.

### 3.3 `PrimaryButton`
Pill, primary gradient, white text (semibold 15), optional leading icon (sparkles) and/or trailing icon (arrow). Height 44. Used for: "Generate My Itinerary →", "+ Create Trip", "AI" in search bar (small, height 36).

### 3.4 `OutlinedPillButton`
Pill, transparent/`surface` fill, 1 px `outline` border, `primary` text + `primary` leading icon. Height 36–44. Used for: "Edit", "View on Map", "Xem chi tiết", "Tùy chỉnh", "Lưu trip", "Log Out" (wide).

### 3.5 `ChipTab` (selected / unselected)
- Selected: primary gradient fill, white text/icon.
- Unselected: transparent or `surface` fill, `textPrimary`/`primary` text.
- Used for: Itinerary/Map/Trip Details/Saved tabs, Day 1/2/3 chips, My Trip filters.

### 3.6 `SearchField`
Pill, `surface` fill, soft shadow, height ~48, leading search icon (`primary`), hint text in `textSecondary`. Trailing widget slot (AI button on Home; filter square button on Explore).

### 3.7 `PlaceThumbnail`
Rounded (16) image, `BoxFit.cover`, with a loading placeholder (`surfaceTint`) and error placeholder (icon).

### 3.8 `InfoRow`
Icon (16–18, `primary`) + caption text, 8 dp gap. Variants: location (pin), clock (duration), calendar (dates), people (meta).

---

## 4. Screen: Home (`Main.png`)

Scroll view (single column), page padding 16. Top to bottom:

1. **Hero header** (taller than other headers ~260)
   - Small gold line-art pagoda icon (Khuê Văn Các) above/right of the title.
   - Title: **"Hanoi Travel Planner"** (2 lines, `pageTitle` ~40, bold italic).
   - Subtitle: **"Plan · Explore · Travel with AI"** (Playfair italic).
   - Illustration: blossom branch top-left, Turtle Tower top-right.

2. **AI search bar** (`SearchField`)
   - Hint: `Plan a trip in Hanoi... (e.g., 2 days, culture, food)`
   - Trailing small `PrimaryButton`: sparkles icon + **"AI"**.

3. **AI greeting card**
   - Left: robot mascot (white robot wearing a conical Vietnamese hat *nón lá*, orange "AI" badge on chest, small sparkle lines above head). Asset image, ~100 × 120, overlaps the card's left edge.
   - Right: speech-bubble card (radius ~24, tail pointing left at the mascot).
     - Title: **"👋 Hi! I'm your Hanoi Travel AI"** (`cardTitle`-ish, bold, `primary`/dark brown).
     - Body: `Tell me your travel dates, interests, or time, and I'll create a personalized itinerary for you!`
     - `PrimaryButton`: sparkles + **"Generate My Itinerary"** + arrow →. Full width of the bubble.

4. **Current trip summary card**
   - Left: polaroid-style thumbnail (slightly rotated ~ −5°, white border, paperclip on top) of Old Quarter.
   - Calendar icon, then title **"Your Trip to Hanoi"** (`cardTitle`) and caption **"3 Days · Culture · Sightseeing · Food"**.
   - Right: `OutlinedPillButton` pencil + **"Edit"**.

5. **Tab row**: **Itinerary** (selected, with no icon), **Map** (map icon), **Trip Details** (info icon), **Saved** (bookmark icon). Evenly distributed; a thin divider line below.

6. **Day row**: chips **Day 1** (selected), **Day 2**, **Day 3** (horizontal), and at the far right `OutlinedPillButton` pin + **"View on Map"**.

7. **Timeline** (for the selected day)
   - A vertical **dashed** line on the left (`outline` color) with a hollow circle node (~12, `primary` stroke) per stop.
   - Next to each node: a **time chip** (`surfaceTint`, rounded, e.g. `08:00`).
   - Then a **stop card** (full remaining width, radius ~20): thumbnail left (~116 × 96, radius 16), content right:
     - Title (`cardTitle`)
     - Row: `InfoRow(pin, district)` and `InfoRow(clock, duration)` on the same line
     - Description (`body`, `textSecondary`, max 2 lines)
     - Trailing chevron_right, vertically centered, at the far right.
   - Sample data (Day 1):

     | Time | Title | District | Duration | Description |
     |------|-------|----------|----------|-------------|
     | 08:00 | Hoan Kiem Lake | Hoan Kiem Dist. | ~ 1 hr | Walk around the iconic lake, visit Ngoc Son Temple, and enjoy the morning vibe. |
     | 10:00 | Old Quarter | Hoan Kiem Dist. | ~ 2 hrs | Explore Hanoi's 36 streets, shop for local crafts, and try street food. |
     | 13:30 | Temple of Literature | Dong Da Dist. | ~ 1.5 hrs | Visit Vietnam's first university, a historic and cultural landmark. |

8. **Add a stop**: full-width dashed-border (`outline`) rounded rectangle, centered `add_circle_outline` icon + **"Add a stop"**.

9. Bottom nav, **Home** active. Leave bottom padding so the last item is not hidden by the floating nav.

Behavior:
- Switching Day chips swaps the timeline (animate with `AnimatedSwitcher`).
- Tapping a stop card → place detail (**Not designed**, stub).
- Tabs Map / Trip Details / Saved → stub content (**Not designed**); Itinerary is the default.
- "Add a stop" → stub (e.g. a bottom sheet "Coming soon").
- "Edit" → stub.

---

## 5. Screen: Explore (`ExplorePage.png`)

1. `PageHeader`: title **"Explore Hanoi"**, subtitle **"Discover must-visit places in Hanoi"**.
2. **Search row**: `SearchField` hint **"Search places in Hanoi..."** + a square-ish rounded button (~48 × 48, primary gradient, white `tune` icon) → opens filter sheet (**Not designed**, stub).
3. **Category chips** (horizontal scroll, no scrollbar): each chip is a vertical card ~72 × 64: icon on top, label below, radius ~20.
   - **All** (grid icon, *selected*: primary fill, white), **Historical** (columns/museum icon), **Nature** (leaf), **Culture** (theater masks), **Food** (fork & knife).
   - Unselected: `surface` fill, `primary` icon, `textPrimary` label.
4. **Section header** row: flame icon (`flame`) + **"Popular Places in Hanoi"** (`sectionTitle`), right-aligned **"See All >"** (`primary`, semibold).
5. **Places grid**: 2 columns, 12–16 gap, card aspect ratio ≈ 0.78 (w:h).
   - Card: radius ~20, `surface`, shadow.
   - Top: image (≈ 60% of card height), with a **favorite button** top-right: 32 dp circle, translucent white, heart icon (outline = not saved, filled `primary` = saved).
   - Below: name (`cardTitle`), `InfoRow(pin, district)`, then a bottom row: star icon (`star`) + **rating** semibold + `(reviews)` caption, and at the far right a **category tag** (small pill, `surfaceTint` bg, `primary` text).
   - Sample data:

     | Name | District | Rating | Reviews | Tag |
     |------|----------|--------|---------|-----|
     | Hoan Kiem Lake | Hoan Kiem Dist. | 4.8 | 12.4k | Lake |
     | Temple of Literature | Dong Da Dist. | 4.7 | 8.9k | Culture |
     | Old Quarter | Hoan Kiem Dist. | 4.6 | 15.2k | Culture |
     | Ho Chi Minh Mausoleum | Ba Dinh Dist. | 4.8 | 9.1k | Historical |

6. Bottom nav, **Explore** active.

Behavior:
- Category chip filters the grid (tag/category match). "All" shows everything.
- Search filters by name (client-side, case-insensitive, **diacritic-insensitive** helps Vietnamese input).
- Heart toggles saved state (shared with Profile → Saved Places).
- Card tap → place detail (**Not designed**, stub).
- Web: show hover elevation on cards, `SystemMouseCursors.click`.

---

## 6. Screen: AI Chatbot (`AIChatbot.png`)

Full-screen, **no bottom nav**. Layout: header (fixed) / message list (scrollable) / suggestion chips / input bar (fixed at bottom, rises above the keyboard).

1. **Header** (banner illustration behind):
   - Left: circular back button (~44, `surface`, `arrow_back`).
   - Robot avatar icon (brown robot head, ~44).
   - Title **"AI Travel Planner"** (`cardTitle` ~24, serif bold) and subtitle **"Chat with AI to plan your perfect trip in Hanoi"** (`caption`).
   - Right: circular `more_vert` button (menu: stub).

2. **Messages**
   - **User message**: right-aligned bubble, fill `userBubble`, radius ~22 with a smaller corner on the bottom-right, max width ~75%. A circular avatar (36–44, primary fill, white person icon) sits to the right of the bubble.
     Text: `Hãy tạo cho tôi lịch trình du lịch Hà Nội 2 ngày 1 đêm, yêu thích văn hóa, ẩm thực và chụp ảnh đẹp.`
   - **AI message**: left-aligned bubble, fill `aiBubble` + subtle shadow, radius ~22 with smaller bottom-left corner, max width ~80%. Circular robot avatar (primary fill, white robot icon) to the left.
     Text: `Đã có lịch trình dành cho bạn! Mình đã lên kế hoạch 2 ngày 1 đêm ở Hà Nội, tập trung vào văn hóa, ẩm thực và các điểm chụp ảnh đẹp. Bạn xem chi tiết nhé! 🌿`
   - **Itinerary card** (rich AI message, full width, radius ~24, `surface`):
     - Top row: thumbnail left (~ 140 × 84, radius 16, Hoan Kiem), right side: title **"Hà Nội 2 ngày 1 đêm"** (serif bold ~22) and 3 `InfoRow`s: calendar **"2 ngày 1 đêm"**, pin **"Hà Nội"**, people **"Văn hóa · Ẩm thực · Check-in"**.
     - **Day blocks**, one per day:
       - Day badge: pill, primary fill, white text (**"Ngày 1"**, **"Ngày 2"**).
       - Below: vertical list with small hollow circle bullets connected by a thin vertical line. Each line = bold period label + text: `Sáng: …`.
       - A square-ish image (~110 × 80, radius 16) floats to the right of each day block.
       - Content:

         **Ngày 1** (image: Temple of Literature)
         - Sáng: Hồ Hoàn Kiếm – Đền Ngọc Sơn
         - Trưa: Thưởng thức bún chả & nem rán
         - Chiều: Văn Miếu – Quốc Tử Giám
         - Tối: Phố cổ Hà Nội – Ăn vặt & dạo đêm

         **Ngày 2** (image: Old Quarter lanterns)
         - Sáng: Lăng Chủ tịch Hồ Chí Minh – Quảng trường Ba Đình
         - Trưa: Phở Hà Nội
         - Chiều: Bảo tàng Dân tộc học Việt Nam
         - Tối: Trở về

         Long lines may shrink slightly or wrap; do not let them overlap the image.
     - **Action row** (3 equal `OutlinedPillButton`s): description icon **"Xem chi tiết"**, pencil **"Tùy chỉnh"**, heart **"Lưu trip"**.
   - While waiting for the AI: show a typing indicator bubble (3 animated dots) in the AI bubble style.

3. **Quick suggestion chips**: horizontal scroll row above the input. Pill, `surface` fill, soft shadow, leading icon + label:
   - pencil **"Thay đổi số ngày"**
   - pin **"Thêm địa điểm"**
   - money bag **"Tối ưu chi phí"**
   - target **"Gợi ý khác"**
   Tapping a chip sends its label as a user message.

4. **Input bar**: floating rounded container (radius ~32, `surface`, shadow, padding 8): left `image` icon button (pick image), center rounded text field with hint **"Nhắn tin cho AI..."**, right circular send button (~48, primary gradient, white paper-plane icon).

Behavior:
- Send via button or **Enter** (Shift+Enter = new line on web). Disable send when empty.
- Auto-scroll to the newest message.
- **Lưu trip** → saves the generated trip into My Trip (appears with status derived from dates) and toggles the heart to filled.
- **Xem chi tiết** → trip detail (**Not designed**, stub). **Tùy chỉnh** → stub.
- Image button: use `image_picker` (web-compatible) — attach preview chip above the input. Sending images to the AI is optional (backend decision).
- The AI backend is not specified. Create an abstract `ChatRepository` with a **mock implementation** returning the sample conversation above so the UI works offline. Real LLM integration plugs in later.

---

## 7. Screen: My Trip (`MyTripPage.png`)

1. `PageHeader`: calendar icon + **"My Trip"**, subtitle **"Manage your travel plans in Hanoi"** (italic). Right: `PrimaryButton` **"+ Create Trip"**.
2. **Filter bar**: one rounded container (`surface`, radius pill) holding 4 `ChipTab`s: **All Trips** (selected), **Upcoming**, **Completed**, heart icon + **Favorites**.
3. **Trip list** (vertical, gap 12). Each `TripCard` (radius ~22, `surface`, shadow, padding 12):
   - Left: square thumbnail ~ 96 × 96 (radius 16).
   - Right column:
     - Row: trip name (`cardTitle`, 1–2 lines) … trailing: heart icon (filled `primary` if favorite, else outline) and `more_vert`.
     - `InfoRow(calendar, "Dec 20 – Dec 22, 2026")`
     - `InfoRow(pin, "Hanoi")`
     - Bottom row: `InfoRow(people icon, "3 days · 12 stops")` on the left, **status chip** on the right (pill, small).
   - Status chip: **Upcoming** (`upcomingBg/Fg`) or **Completed** (`completedBg/Fg`).
   - Sample data:

     | Name | Dates | Duration · Stops | Status | Favorite |
     |------|-------|------------------|--------|----------|
     | Hanoi 3 Days Cultural Trip | Dec 20 – Dec 22, 2026 | 3 days · 12 stops | Upcoming | no |
     | Hanoi Weekend Getaway | Nov 28 – Nov 29, 2026 | 2 days · 7 stops | Completed | **yes** |
     | Hanoi Food Tour | Nov 15 – Nov 15, 2026 | 1 day · 6 stops | Completed | no |
     | Historical Hanoi Tour | Oct 10 – Oct 12, 2026 | 3 days · 10 stops | Completed | no |

4. Bottom nav, **My Trip** active.

Behavior:
- Filters: All = everything; Upcoming / Completed = by `status`; Favorites = `isFavorite`.
- Heart toggles favorite. `more_vert` opens a popup menu (Edit / Duplicate / Delete — **suggested**, not in mockup).
- Card tap → opens that trip in the Home itinerary view / trip detail (**Not designed**; suggest reusing the Home itinerary UI).
- **+ Create Trip** → navigate to `/ai` (reasonable default) or stub.
- Empty state for a filter with no results: centered illustration/icon + "No trips yet" text (**suggested**).
- **Data note:** in the mockup, "Hanoi Weekend Getaway (Nov 28–29, 2026)" is marked *Completed*, which is inconsistent with a real clock. In code, **derive status from dates** (`endDate < today → completed`, else `upcoming`) instead of hardcoding it. Use the mock data as-is only inside the mock repository.
- The "people" icon in the duration row looks like a mockup artifact; keep it for visual fidelity, or swap for a `route`/`schedule` icon (acceptable).

---

## 8. Screen: Profile (`ProfilePage.png`)

1. `PageHeader`: person icon + **"Profile"** (bold italic), subtitle **"Your travel account"**. Illustration: traditional Vietnamese tiled-roof house by the lake.
2. **Profile card** (radius ~24, `surface`, shadow):
   - Left: circular avatar ~ 100 (photo of a lantern-lit old street at sunset) with a small round **edit badge** (pencil) at the bottom-right.
   - Right: name **"Quan Nguyen"** (`cardTitle` ~22), `InfoRow(mail, "quan.nguyen@example.com")`, `InfoRow(phone, "+84 987 654 321")`.
   - Top-right: `OutlinedPillButton` pencil + **"Edit"**.
   - Below, inside the card: **stats panel** (rounded rectangle, `surfaceTint`, 3 equal columns separated by 1 px vertical dividers). Each column: icon (`primary`), big number (bold ~22), label (caption).
     - flight icon · **5** · "Trips"
     - pin icon · **42** · "Places Visited"
     - star icon · **4.8** · "Avg. Rating"
3. **Menu list card** (one rounded card, rows separated by `divider`). Row = leading icon (24, `primary`) + title (`bodyStrong`) over subtitle (`caption`) + trailing `chevron_right`. Row height ~64.

   | Icon | Title | Subtitle |
   |------|-------|----------|
   | people/group (preferences) | Travel Preferences | Interests, travel style, budget |
   | favorite (outline) | Saved Places | Your favorite destinations |
   | history (clock with arrow) | Travel History | Past trips and experiences |
   | settings (gear) | Settings | App, notification, language |
   | help_outline (circle ?) | Help & Support | FAQs, contact us |

4. **Log Out**: full-width `OutlinedPillButton` (height ~48), logout icon + **"Log Out"**.
5. Bottom nav, **Profile** active.

Behavior:
- All rows and Edit/avatar-edit → stub pages (**Not designed**). Log Out → confirm dialog, then clear session and go to the root (no login screen is designed; just reset state).
- "Trips" and "Avg. Rating" are static from the mock user for now; "Saved Places" should reflect the Explore heart state.

---

## 9. Flutter Web implementation notes

### 9.1 Suggested stack
- `go_router` (ShellRoute for tabs; `/ai` outside the shell)
- `google_fonts` (Playfair Display, Nunito Sans — runtime fetch OK on web; consider bundling fonts as assets for offline/first-paint)
- State: `flutter_riverpod` (or Provider/Bloc — pick one and keep it consistent)
- `image_picker` (chat attachments)
- Optional: `cached_network_image`

### 9.2 Suggested structure
```
lib/
  main.dart
  app/            router.dart, theme.dart, tokens.dart
  core/widgets/   page_header.dart, app_bottom_nav.dart, primary_button.dart,
                  outlined_pill_button.dart, chip_tab.dart, search_field.dart,
                  place_thumbnail.dart, info_row.dart
  features/
    home/         home_page.dart, widgets/{ai_greeting_card, trip_summary_card, timeline_stop_card}
    explore/      explore_page.dart, widgets/{category_chip, place_card}
    chat/         chat_page.dart, widgets/{message_bubble, itinerary_card, suggestion_chips, chat_input_bar}
    trips/        my_trip_page.dart, widgets/{trip_card, status_chip}
    profile/      profile_page.dart, widgets/{stats_panel, menu_tile}
  data/           models/, repositories/ (mock_*.dart)
assets/images/    (see §9.5)
```

### 9.3 Responsive behavior (important for Web)
- The design is **mobile-first**. On viewports wider than ~480 px, center the app in a column with `maxWidth: 430–480`, with the page background gradient filling the rest of the window. Do not stretch cards across a 1920 px screen.
- The floating bottom nav and chat input bar are positioned within that constrained column, not the full window.
- Optional enhancement (not required): ≥ 900 px → show the column inside a rounded "phone frame".
- Use `LayoutBuilder`/`MediaQuery`; avoid hard-coding pixel widths for text containers so Vietnamese diacritics and longer strings don't overflow. Use `Flexible`/`Expanded`, `maxLines` + `TextOverflow.ellipsis` where specified.
- Test at 360, 390, 430 and a desktop width.

### 9.4 Web-specific polish
- Hover + cursor states on all tappable cards/buttons (`InkWell` + `MouseRegion`), visible keyboard focus ring.
- Enter-to-send in chat; Tab order follows visual order.
- Mouse-drag scrolling for the horizontal lists (category chips, suggestion chips): provide a `ScrollBehavior` that includes `PointerDeviceKind.mouse`.
- Avoid `dart:io`; plugins must support web.
- Set page `<title>` ("Hanoi Travel Planner") and theme-color in `web/index.html`.

### 9.5 Assets needed (the PNG mockups cannot be sliced; supply real files)
| Asset | Used on | Notes |
|-------|---------|-------|
| `header_hoankiem.png/webp` | Home, Explore, My Trip, Chat headers | Watercolor lake + Turtle Tower + blossom branch, transparent or fading left/bottom |
| `header_profile.png/webp` | Profile header | Traditional house by the lake |
| `mascot_ai.png` | Home greeting card | Robot with *nón lá* |
| `place_hoankiem.jpg`, `place_old_quarter.jpg`, `place_temple_literature.jpg`, `place_mausoleum.jpg` | Explore, Home timeline, chat card | Place photos |
| `trip_food.jpg`, `trip_historical.jpg` | My Trip | Thumbnails |
| `avatar_quan.jpg` | Profile | Avatar |
| `ic_pagoda.svg` | Home hero | Gold line icon (Khuê Văn Các) |

Until the real assets exist, use a placeholder (`surfaceTint` box + icon) so the layout can be built and verified.

### 9.6 Data models (minimal)
```dart
class Place { String id, name, district, category /* Lake|Culture|Historical|Nature|Food */, imageUrl;
              double rating; int reviewCount; bool isSaved; }

class TripStop { String time /* "08:00" */, placeId, title, district, durationLabel /* "~ 1 hr" */,
                 description, imageUrl; }

class TripDay { int index; List<TripStop> stops; }

class Trip { String id, name, city, coverImageUrl; DateTime startDate, endDate;
             int stopCount; bool isFavorite; List<TripDay> days; List<String> tags;
             TripStatus get status; /* derived from dates */ }

class ChatMessage { String id; ChatRole role /* user | ai */; String? text;
                    ItineraryPreview? itinerary; DateTime createdAt; }

class UserProfile { String name, email, phone, avatarUrl; int trips, placesVisited; double avgRating; }
```

---

## 10. Localization

The mockups mix languages: **Home, Explore, My Trip, Profile are English; the AI Chatbot screen is Vietnamese** (including the quick-suggestion chips, buttons and input hint).
- Default: **reproduce exactly as shown** (English on the four tab screens, Vietnamese on `/ai`).
- Put all strings in one place (`AppStrings` or `intl` ARB files) so switching/adding a language later is a single change. Settings → language is a stub for now.
- Make sure fonts render Vietnamese diacritics correctly (Playfair Display and Nunito Sans both include the Vietnamese subset).

---

## 11. Not designed (use stubs, do not invent visuals)

- Map tab / "View on Map" (suggest `flutter_map` + OpenStreetMap tiles when implemented; works on Web without an API key)
- Trip Details tab, Saved tab (Home)
- Place detail page, Trip detail page, Create/Edit trip flow
- Filter sheet (Explore), "See All" page
- Trip card `more_vert` menu
- Travel Preferences, Saved Places, Travel History, Settings, Help & Support pages
- Login / onboarding / empty and error states (small suggested ones are noted above)

A stub = a simple page/bottom sheet in the same theme with the title and "Coming soon".

---

## 12. Acceptance checklist

- [ ] 5 screens match the mockups in layout, colors, typography, spacing (side-by-side comparison at 390 px width)
- [ ] Bottom nav shared by Home / Explore / My Trip / Profile with correct active state; center AI button opens `/ai`; `/ai` has no bottom nav
- [ ] All sample data and copy in this spec appear exactly as written
- [ ] Day chips switch the Home timeline; category chips and search filter Explore; filter chips filter My Trip
- [ ] Chat: send message → typing indicator → mock AI reply incl. itinerary card; suggestion chips send messages; Enter sends
- [ ] Heart state is shared (Explore ↔ Profile saved places); trip favorite toggles in My Trip
- [ ] Trip status is derived from dates, not hardcoded
- [ ] Layout is centered and constrained (≤ 480 px) on wide browser windows; no overflow at 360 px
- [ ] Vietnamese text renders correctly everywhere
- [ ] Hover/cursor/focus states present on interactive elements
- [ ] No runtime errors in the browser console; `flutter analyze` is clean
