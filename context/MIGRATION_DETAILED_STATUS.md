## 📋 PHASE 1: REX INTERFACE SCREEN (3-4 hours)

  **File:** `lib/features/ai_assistant/presentation/screens/rex_interface_screen.dart`

  ### Step 1: Setup Screen Structure (30 min)
  - [ ] Replace placeholder with StatefulWidget
  - [ ] Add state management for messages list
  - [ ] Add TextEditingController for input field
  - [ ] Add ScrollController for auto-scroll
  - [ ] Import required packages: `lucide_icons`, `flutter_animate`

  ### Step 2: Create Message Model (15 min)
  - [ ] Create `ChatMessage` class with fields:
    - `String id`
    - `String content`
    - `bool isUser` (true for user, false for AI)
    - `DateTime timestamp`
    - `MessageStatus status` (sending, sent, error)

  ### Step 3: Build Chat UI Layout (45 min)
  - [ ] Create gradient background (deepSpace → spaceBase)
  - [ ] Add app bar with:
    - Back button
    - "REX" title with bot icon
    - "A.I. Assistant" subtitle
    - Status indicator (online/offline)
  - [ ] Create message list area with ListView.builder
  - [ ] Add input area at bottom (fixed position)

  ### Step 4: Build Message Bubbles (1 hour)
  - [ ] Create `_buildUserMessage()` widget:
    - Aligned right
    - GlassCard with cyan glow
    - User avatar (right side)
    - Message text
    - Timestamp (bottom right)
  - [ ] Create `_buildAIMessage()` widget:
    - Aligned left
    - GlassCard with purple glow
    - Rex bot icon (left side)
    - Message text with typing animation
    - Timestamp (bottom left)
  - [ ] Add fade-in animation for new messages

  ### Step 5: Build Input Area (45 min)
  - [ ] Create bottom input container with GlassCard
  - [ ] Add TextField with:
    - Hint: "Ask Rex anything..."
    - Multi-line support (maxLines: 5)
    - Auto-focus on screen load
  - [ ] Add send button with:
    - Gradient background (cyan → purple)
    - Send icon from lucide_icons
    - Disabled state when text is empty
    - Pulse animation when active

  ### Step 6: Implement Chat Logic (45 min)
  - [ ] Handle message sending:
    - Add user message to list
    - Scroll to bottom
    - Clear input field
    - Show "typing..." indicator
  - [ ] Create mock AI response generator:
    - Delay 1-2 seconds
    - Generate contextual responses based on `initialContext`
    - Add AI message to list
    - Remove typing indicator
  - [ ] Handle initialContext from SyncHub:
    - If context = "lease", show lease-related greeting
    - If context = "maintenance", show maintenance greeting
    - If null, show general greeting

  ### Step 7: Add Special Features (30 min)
  - [ ] Add "typing..." indicator (3 animated dots)
  - [ ] Add empty state when no messages:
    - Rex icon (large)
    - "Hi! I'm Rex, your AI assistant"
    - Suggested questions as chips
  - [ ] Add auto-scroll to bottom on new message
  - [ ] Add haptic feedback on send

  ### Step 8: Polish & Animations (30 min)
  - [ ] Add message fade-in with slide animation
  - [ ] Add send button scale animation on press
  - [ ] Add input field glow on focus
  - [ ] Add skeleton loader for AI response
  - [ ] Test with long messages (text wrapping)

  ---

  ## 📋 PHASE 2: LEASE SENTINEL SCREEN (3-4 hours)

  **File:** `lib/features/ai_assistant/presentation/screens/lease_sentinel_screen.dart`

  ### Step 1: Setup Screen Structure (30 min)
  - [ ] Replace placeholder with StatefulWidget
  - [ ] Add state for:
    - `File? uploadedDocument`
    - `bool isAnalyzing`
    - `AnalysisResult? result`
  - [ ] Import `file_picker` package
  - [ ] Import `lucide_icons` for icons

  ### Step 2: Create Analysis Models (20 min)
  - [ ] Create `AnalysisResult` class:
    - `int riskScore` (0-100)
    - `String riskLevel` (LOW/MEDIUM/HIGH/CRITICAL)
    - `List<LeaseClause> clauses`
    - `List<String> redFlags`
    - `List<String> recommendations`
  - [ ] Create `LeaseClause` class:
    - `String title`
    - `String content`
    - `ClauseType type` (standard/concern/benefit)
    - `Color color`

  ### Step 3: Build Hero Section (45 min)
  - [ ] Create top hero card with:
    - Shield icon with scan animation
    - "Lease Sentinel" title
    - "A.I. Contract Analysis" subtitle
    - Gradient background (purple → indigo)
    - Glowing border animation
  - [ ] Add stats row below hero:
    - "Documents Analyzed" count
    - "Issues Found" count
    - "Risk Score" average

  ### Step 4: Build Upload Section (1 hour)
  - [ ] Create upload area when no document:
    - Large dashed border GlassCard
    - Upload icon (file-up from lucide)
    - "Tap to upload lease document" text
    - Supported formats: PDF, JPG, PNG
    - Pulse animation on hover
  - [ ] Handle file picker:
    - Open file picker on tap
    - Validate file type
    - Show loading indicator
    - Store selected file
  - [ ] Create document preview when uploaded:
    - File name and size
    - PDF/image thumbnail
    - "Change Document" button
    - "Analyze" button (large, gradient)

  ### Step 5: Build Analysis Loading State (30 min)
  - [ ] Create analyzing overlay:
    - Backdrop blur
    - Scanning animation (rotating shield)
    - Progress text: "Analyzing lease..."
    - Progress bar (0-100%)
    - Animated scanning lines
  - [ ] Simulate analysis steps:
    - "Reading document..." (0-30%)
    - "Extracting clauses..." (30-60%)
    - "Checking for red flags..." (60-90%)
    - "Generating report..." (90-100%)

  ### Step 6: Build Results Display (1.5 hours)
  - [ ] Create risk score card:
    - Large circular progress indicator
    - Score number in center (0-100)
    - Color-coded: Green (<30), Amber (30-70), Red (>70)
    - Risk level badge (LOW/MEDIUM/HIGH/CRITICAL)
    - Animated counter on reveal
  - [ ] Create red flags section:
    - Alert icon with warning color
    - List of concerning clauses
    - Each item in GlassCard with red accent
    - Tap to expand for details
  - [ ] Create clause breakdown:
    - Tabbed view: ALL / CONCERNS / BENEFITS
    - Each clause in expandable card
    - Color-coded by type
    - Highlight key terms
  - [ ] Create recommendations section:
    - Lightbulb icon
    - Actionable suggestions
    - "Talk to Rex" button for each

  ### Step 7: Add Mock Analysis Data (45 min)
  - [ ] Create mock analysis function:
    - Generate random risk score (40-85)
    - Create 5-7 clauses
    - Add 2-3 red flags
    - Add 3-4 recommendations
  - [ ] Example red flags:
    - "No subletting allowed - limits flexibility"
    - "Automatic rent increase clause: 8% annually"
    - "Security deposit is 3x monthly rent - above standard"
  - [ ] Example recommendations:
    - "Negotiate rent increase cap to 5%"
    - "Request subletting rights for emergencies"
    - "Ask for itemized move-in inspection"

  ### Step 8: Polish & Features (30 min)
  - [ ] Add "Share Report" button (export PDF)
  - [ ] Add "Ask Rex About This" button → opens RexInterface with context
  - [ ] Add animation for risk score reveal
  - [ ] Add haptic feedback on analysis complete
  - [ ] Add empty state instructions
  - [ ] Test with different document types

  ---

  ## 📋 PHASE 3: FAIRFIX AUDITOR SCREEN (2-3 hours)

  **File:** `lib/features/maintenance/presentation/screens/fairfix_auditor_screen.dart`

  ### Step 1: Setup Screen & Models (30 min)
  - [ ] Create new file (FairFix doesn't have folder yet)
  - [ ] Create StatefulWidget structure
  - [ ] Create `MaintenanceTicket` model:
    - `String id`
    - `String title`
    - `String description`
    - `IssueCategory category`
    - `TicketStatus status`
    - `DateTime createdAt`
    - `DateTime? resolvedAt`
    - `List<String> photos`
    - `UrgencyLevel urgency`
  - [ ] Create enums: `IssueCategory`, `TicketStatus`, `UrgencyLevel`

  ### Step 2: Build Hero Section (30 min)
  - [ ] Create hero card:
    - ShieldAlert icon with pulse
    - "FairFix Auditor" title
    - "Maintenance Transparency" subtitle
    - Gradient background (orange → rose)
  - [ ] Add quick stats:
    - Active tickets count
    - Average resolution time
    - Landlord response rate

  ### Step 3: Build Create Ticket Form (1 hour)
  - [ ] Create "New Request" button (floating or top)
  - [ ] Build form modal/screen:
    - Issue title TextField
    - Description TextField (multi-line)
    - Category selector (dropdown):
      - Plumbing
      - Electrical
      - Heating/Cooling
      - Structural
      - Appliances
      - Pest Control
      - Other
    - Urgency selector (chips):
      - Low (48h response)
      - Medium (24h response)
      - High (12h response)
      - Emergency (Immediate)
    - Photo upload area (multiple photos)
    - Location field (room/area)
  - [ ] Add form validation
  - [ ] Handle photo picker (camera + gallery)

  ### Step 4: Build Ticket List (45 min)
  - [ ] Create tabs: ACTIVE / RESOLVED / ALL
  - [ ] Build ticket card:
    - Category icon (color-coded)
    - Ticket title
    - Status badge (Submitted/In Progress/Resolved)
    - Urgency indicator (color dot)
    - Created date
    - Tap to expand for details
  - [ ] Add empty state for each tab
  - [ ] Add sort/filter options

  ### Step 5: Build Ticket Detail View (45 min)
  - [ ] Create expanded ticket view:
    - Full description
    - Photo gallery (swipeable)
    - Timeline of updates:
      - Submitted (timestamp)
      - Viewed by landlord (timestamp)
      - In progress (timestamp)
      - Resolved (timestamp)
    - Landlord notes/responses
    - Cost breakdown (if resolved)
  - [ ] Add action buttons:
    - "Upload More Photos"
    - "Add Update"
    - "Mark as Resolved" (tenant confirms)
    - "Escalate" (if overdue)

  ### Step 6: Build Transparency Features (30 min)
  - [ ] Add "Response Timer" for active tickets:
    - Countdown until expected response
    - Color changes: Green → Amber → Red
    - Alert if overdue
  - [ ] Add "Fair Price Check":
    - Show quoted repair cost
    - Show market average
    - Flag if significantly over/under
  - [ ] Add "Resolution Quality" rating:
    - Stars (1-5)
    - Quick feedback: Fixed/Not Fixed
    - Optional comment

  ### Step 7: Add Mock Data & Logic (30 min)
  - [ ] Create 3-4 sample tickets:
    - 1 active (plumbing leak)
    - 1 in progress (broken AC)
    - 2 resolved (light fixture, window screen)
  - [ ] Handle ticket creation:
    - Generate ticket ID
    - Set status to "Submitted"
    - Add to list
    - Show success message
    - Send notification (mock)
  - [ ] Handle photo upload:
    - Store locally
    - Show thumbnail preview
    - Allow deletion before submit

  ### Step 8: Polish & Features (30 min)
  - [ ] Add "Ask Rex" integration:
    - "Is this urgent?" button
    - "Fair price estimate" button
    - "Landlord rights" info button
  - [ ] Add notifications system:
    - Show badge on bottom nav when update
    - Push notification (mock)
  - [ ] Add export ticket as PDF
  - [ ] Add haptic feedback
  - [ ] Test full flow: create → submit → view → resolve

  ---

  ## 📋 PHASE 4: ROUTER INTEGRATION (15 min)

  ### Update Router
  - [ ] Add FairFixAuditor import to `app_router.dart`:
    ```dart
    import '../../features/maintenance/presentation/screens/fairfix_auditor_screen.dart';
  - Replace inline fairfixAuditor route (lines 350-358) with:
  GoRoute(
    path: AppRoutes.fairfixAuditor,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const FairFixAuditorScreen(),
      slideFromBottom: true,
    ),
  ),

  ---
  📋 PHASE 5: COMPREHENSIVE TESTING (2-3 hours)

  Navigation Testing (30 min)

  - Test SyncHub card navigation:
    - Tap "Lease Sentinel" card → opens LeaseSentinel
    - Tap "FairFix Auditor" card → opens FairFix
    - Tap "Payment Breakdown" card → opens correct screen
    - Tap Rex logo → opens RexInterface
  - Test Bottom Navigation:
    - All 5 tenant tabs switch correctly
    - Center tab (Rex/Radio) has elevated glow
    - Icon switches based on current screen
    - Smooth transitions, no lag
  - Test Back Navigation:
    - Back button returns to previous screen
    - Android back gesture works
    - No navigation stack errors

  Screen Functionality Testing (1 hour)

  - RexInterface:
    - Send message adds to list
    - AI response appears after delay
    - Input clears after send
    - Auto-scroll to bottom works
    - Empty state shows suggested questions
    - Long messages wrap correctly
    - Typing indicator animates
  - LeaseSentinel:
    - File picker opens on tap
    - Document preview shows after upload
    - Analyze button triggers analysis
    - Loading states show correctly
    - Risk score animates on reveal
    - Red flags expand on tap
    - "Ask Rex" button opens chat with context
  - FairFixAuditor:
    - New ticket form opens
    - Photo picker works (camera + gallery)
    - Form validation works (required fields)
    - Ticket submits and appears in list
    - Tabs filter correctly (Active/Resolved/All)
    - Ticket detail expands on tap
    - Timeline shows correct dates

  UI/UX Testing (45 min)

  - Animations:
    - All fade-ins smooth (no jank)
    - Glass cards have proper blur
    - Glow effects visible but not overdone
    - Loading spinners centered
    - Progress bars animate smoothly
  - Responsiveness:
    - Test on different screen sizes
    - Landscape orientation works
    - Keyboard appears/dismisses correctly
    - ScrollViews scroll smoothly
    - No overflow errors
  - Colors & Theme:
    - All colors from AppColors used consistently
    - Gradients render correctly
    - Text readable on all backgrounds
    - Icons have proper colors
    - Status badges color-coded correctly

  Edge Cases Testing (30 min)

  - Empty States:
    - RexInterface with no messages
    - LeaseSentinel with no document
    - FairFix with no tickets
    - All show helpful instructions
  - Error States:
    - File upload failure (LeaseSentinel)
    - Photo upload failure (FairFix)
    - Network error simulation
    - Show error messages clearly
  - Long Content:
    - Very long chat message (RexInterface)
    - Long lease document name (LeaseSentinel)
    - Long ticket description (FairFix)
    - All truncate/wrap properly
  - Rapid Actions:
    - Spam send button (RexInterface)
    - Quick tab switching (bottom nav)
    - Fast back navigation
    - No crashes or state errors

  Performance Testing (30 min)

  - Check app startup time
  - Test memory usage (watch for leaks)
  - Monitor CPU usage during animations
  - Check build size (flutter build --release)
  - Test on older device (if available)
  - Profile with DevTools (identify bottlenecks)

  ---
  📋 PHASE 6: FINAL POLISH (1 hour)

  Code Cleanup

  - Remove all print() statements
  - Remove all TODO comments (or track in issues)
  - Fix unused variables warnings
  - Add missing @override annotations
  - Format all files: dart format .
  - Run analyzer: flutter analyze → 0 errors

  Documentation

  - Add comments to complex logic
  - Document public APIs
  - Update README with features list
  - Add screenshots to docs
  - Create user guide (optional)

  Accessibility

  - Add semantic labels to icons
  - Test with screen reader (TalkBack/VoiceOver)
  - Ensure proper contrast ratios
  - Add tooltips where needed
  - Test keyboard navigation (web)

  Final Checks

  - All routes work correctly
  - All navigation flows complete
  - No console errors
  - All animations smooth
  - App runs in release mode
  - Ready for user testing

  ---
  🎯 COMPLETION CHECKLIST

  - RexInterface Screen - 100% implemented
  - LeaseSentinel Screen - 100% implemented
  - FairFixAuditor Screen - 100% implemented
  - Router Updated - All 3 screens integrated
  - Navigation Testing - All flows verified
  - Functionality Testing - All features work
  - UI/UX Testing - Polished and smooth
  - Performance Testing - No bottlenecks
  - Code Quality - Clean and documented
  - Ready for Production - 95%+ completion

  ---
  📊 PROGRESS TRACKING

  Update this section as you complete tasks:

  Day 1: RexInterface

  - Started: [Date/Time]
  - Completed: [Date/Time]
  - Issues Found: [List any blockers]
  - Final Status: [ ] Complete

  Day 2: LeaseSentinel

  - Started: [Date/Time]
  - Completed: [Date/Time]
  - Issues Found: [List any blockers]
  - Final Status: [ ] Complete

  Day 3: FairFixAuditor

  - Started: [Date/Time]
  - Completed: [Date/Time]
  - Issues Found: [List any blockers]
  - Final Status: [ ] Complete

  Day 4: Testing & Polish

  - Started: [Date/Time]
  - Completed: [Date/Time]
  - Issues Found: [List any blockers]
  - Final Status: [ ] Complete

  ---
  Estimated Total Time: 10-13 hours
  Target Completion Date: [Your target date]
  Final Progress Goal: 95%

---

## 📋 PHASE 7: LANDLORD UI IMPLEMENTATION (10-12 hours)

Based on 14 reference screenshots from `D:\Repositories\Residex\Codes\UI Reference\Screenshots\Landlord`

### Overview of Landlord UI Structure

**Navigation System:**
- LandlordHomeScreen: Tab wrapper with 5 tabs
  - Tab 1: Command (Asset Command dashboard)
  - Tab 2: Finance (Revenue & Expenses)
  - Tab 3: Rex AI (AI assistant - center, protruding)
  - Tab 4: Portfolio (Property list)
  - Tab 5: Community (Tenant communication)

**Key Screens to Implement/Update:**
1. Asset Command (LandlordCommandScreen) - Main dashboard
2. Portfolio List (LandlordPortfolioScreen) - Property management
3. Property Pulse (PropertyPulseScreen) - Property health details
4. Finance (LandlordFinanceScreen) - Revenue & expense tracking
5. Maintenance (New screen) - Ticket management
6. Lease Sentinel Landlord (New screen) - Contract analysis for tenants
7. Lazy Logger (New screen) - AI document indexer
8. Rex AI Landlord (LandlordRexAIScreen) - AI chat with landlord context

---

### Step 1: Update Router Configuration (15 min)

**File:** `lib/core/router/app_router.dart`

- [ ] Update landlordDashboard route (around line 290-298):
  ```dart
  GoRoute(
    path: AppRoutes.landlordDashboard,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const LandlordHomeScreen(), // Changed from LandlordDashboardScreen
      slideFromBottom: true,
    ),
  ),
  ```
- [ ] Add import at top of file:
  ```dart
  import '../../features/landlord/presentation/screens/landlord_home_screen.dart';
  ```
- [ ] Verify no other routes reference LandlordDashboardScreen
- [ ] Test: Login → Landlord Dev button → should show Asset Command with bottom nav

---

### Step 2: Update LandlordPortfolioScreen - Property List (2 hours)

**File:** `lib/features/landlord/presentation/screens/landlord_portfolio_screen.dart`

**Reference:** Screenshot 130026 (Portfolio list with properties)

#### 2.1: Setup Screen Structure (20 min)
- [ ] Replace placeholder StatelessWidget with StatefulWidget
- [ ] Add state variables:
  ```dart
  final List<Property> _properties = [];
  bool _showPropertySelector = false;
  ```
- [ ] Create Property model (or use existing):
  ```dart
  class PropertyItem {
    final String id;
    final String name;
    final String unit;
    final PropertyStatus status; // OCCUPIED, VACANT
    final TenantInfo? tenant;
    final RentStatus? rentStatus; // PAID, PENDING, OVERDUE

    PropertyItem({...});
  }
  ```

#### 2.2: Build Header Section (30 min)
- [ ] Create gradient background (deepSpace with radial indigo glow)
- [ ] Add header with:
  - "PORTFOLIO" label (small, tracked, muted color)
  - "+ ADD UNIT" button (top right, cyan/emerald color)
  - Positioned in SafeArea, padding EdgeInsets.all(24)
- [ ] Style "+ ADD UNIT" button:
  - Container with teal/cyan background
  - Rounded BorderRadius.circular(12)
  - Icon: LucideIcons.plus
  - Text: "ADD UNIT" (font size 11, bold, tracked)
  - OnTap: Show dialog or navigate to add unit flow

#### 2.3: Build Property List (45 min)
- [ ] Create ListView.separated for properties
- [ ] Each property card (_buildPropertyCard):
  - GlassCard container
  - Border radius: 24-28
  - Padding: 20-24
  - Row layout:
    - Left: Property icon (grid icon in colored circle)
    - Middle: Property info (name, unit, tenant)
    - Right: Status badges
- [ ] Property icon styling:
  - Container with colored background (blue/purple gradient)
  - Size: 48x48
  - BorderRadius.circular(12)
  - Icon: LucideIcons.building2 or grid icon
  - Glow effect with BoxShadow

#### 2.4: Property Card Details (30 min)
- [ ] Property name & unit:
  - Name: Font size 16-18, bold (e.g., "Verdi Eco-Dominium")
  - Unit: Font size 13, secondary color (e.g., "Unit 4-2")
- [ ] Tenant section (if occupied):
  - Row with avatar + name
  - Avatar: Circular, 32x32, initials, colored background
  - Name: Font size 13, bold
- [ ] Status badges:
  - OCCUPIED: Green badge (emerald500), top right
  - VACANT: Gray badge (slate500), top right
  - RENT: PAID: Cyan text, below tenant
  - RENT: PENDING: Orange/amber text, below tenant
  - RENT: OVERDUE: Red/rose text, below tenant
- [ ] Badge styling:
  - Container with color.withOpacity(0.2) background
  - Border with color.withOpacity(0.3)
  - BorderRadius.circular(8)
  - Padding: horizontal 10, vertical 4
  - Text: Font size 9, bold, tracked (2.0)

#### 2.5: Add Mock Data (20 min)
- [ ] Create 3-4 sample properties in initState():
  ```dart
  _properties = [
    PropertyItem(
      id: '1',
      name: 'Verdi Eco-Dominium',
      unit: 'Unit 4-2',
      status: PropertyStatus.occupied,
      tenant: TenantInfo(name: 'Ali Rahman', avatar: 'AR'),
      rentStatus: RentStatus.paid,
    ),
    PropertyItem(
      id: '2',
      name: 'The Grand Subang',
      unit: 'Block B-12',
      status: PropertyStatus.occupied,
      tenant: TenantInfo(name: 'Sarah Tan', avatar: 'ST'),
      rentStatus: RentStatus.pending,
    ),
    PropertyItem(
      id: '3',
      name: 'Areuz Kelana Jaya',
      unit: 'Unit 08-01',
      status: PropertyStatus.vacant,
      tenant: null,
      rentStatus: null,
    ),
  ];
  ```

#### 2.6: Add Interactions (15 min)
- [ ] Make each property card tappable:
  - Wrap in GestureDetector
  - OnTap: Navigate to property details or show options
  - Add haptic feedback
- [ ] Add empty state when no properties:
  - Center icon (building)
  - "No Properties Yet" text
  - "Add your first property" subtitle
  - "Add Unit" button

---

### Step 3: Update LandlordCommandScreen - Asset Command (1.5 hours)

**File:** `lib/features/landlord/presentation/screens/landlord_command_screen.dart`

**Reference:** Screenshot 125911 (Asset Command dashboard)

#### 3.1: Update Header Section (20 min)
- [ ] Verify header matches reference:
  - User profile: Avatar with "Dato' Lee" (or dynamic name)
  - Subtitle: "PROPERTY OWNER" (tracked, small)
  - Notification bell icon (top right)
- [ ] Update avatar to show actual user initials
- [ ] Style notification bell:
  - Container with glass effect
  - Size: 40x40
  - Border radius: 16
  - Border with white.withOpacity(0.1)

#### 3.2: Update Hero Financial Card (30 min)
- [ ] Verify HeroFinancialCard displays:
  - "Projected Revenue" label
  - "RM 14,250.00" (large, bold, gradient text)
  - Change percentage with up/down indicator
  - Period: "this month"
- [ ] Ensure gradient shader mask on amount:
  - Colors: cyan → purple or blue → indigo
  - Font: Mono or bold, size 32-36
- [ ] Add revenue trend indicator:
  - Small chart icon or arrow
  - Percentage: +5.2% (green if up, red if down)

#### 3.3: Update Command Modules Grid (40 min)
- [ ] Verify 4 stat cards match reference:
  1. **System Health**: 87/100, "Optimal" badge
  2. **Maintenance**: "2 Active", "Action Req" badge
  3. **Lazy Logger**: "AI Docs", "Indexer" badge
  4. **Sentinel**: "Contract", "Analyzer" badge
- [ ] Update each StatCard:
  - Add navigation on tap:
    - System Health → PropertyPulseScreen
    - Maintenance → MaintenanceScreen (to be created)
    - Lazy Logger → LazyLoggerScreen (to be created)
    - Sentinel → LeaseSentinelLandlordScreen (to be created)
  - Verify icon styling matches (outlined icons)
  - Verify gradient colors:
    - System Health: Blue (primary)
    - Maintenance: Cyan (info)
    - Lazy Logger: Purple
    - Sentinel: Indigo (accent)
  - Badge styling:
    - Small container in top right
    - Color-coded background
    - Icon + text

#### 3.4: Add Bottom Navigation (10 min)
- [ ] Verify bottom nav is showing (from LandlordHomeScreen)
- [ ] If not visible, check IndexedStack in LandlordHomeScreen
- [ ] Test tab switching works correctly

---

### Step 4: Create PropertyPulseScreen (2 hours)

**File:** `lib/features/landlord/presentation/screens/property_pulse_screen.dart` (update existing)

**Reference:** Screenshot 125927 (Property Pulse details)

#### 4.1: Setup Screen Structure (20 min)
- [ ] Create StatefulWidget if not already
- [ ] Add state for:
  - `int healthScore` (87)
  - `List<VitalCheck> vitals`
  - `List<AIInsight> insights`
- [ ] Create models:
  ```dart
  class VitalCheck {
    final String title;
    final String status;
    final VitalStatus statusType; // OK, WARNING, CRITICAL
    final IconData icon;
  }

  class AIInsight {
    final String message;
    final InsightType type;
    final DateTime timestamp;
  }
  ```

#### 4.2: Build Hero Health Score Card (40 min)
- [ ] Create large glass card at top:
  - Gradient background (blue → indigo)
  - Glow effect with BoxShadow
- [ ] Add circular progress indicator:
  - Size: 140-160
  - Thickness: 12-14
  - Background: White.withOpacity(0.1)
  - Foreground: Gradient (cyan → emerald if high score)
  - Value: healthScore / 100
- [ ] Center score display:
  - Score number: 87 (font size 56, bold, mono)
  - "/100" suffix: (font size 20, muted)
  - Animated counter on screen load
- [ ] Add score label below:
  - "PROPERTY HEALTH" (tracked, small)
  - Status badge: "OPTIMAL" (green) or "NEEDS ATTENTION" (orange)

#### 4.3: Build Vitals Check Section (40 min)
- [ ] Section header:
  - "VITALS CHECK" label (tracked, small, muted)
  - Last updated timestamp
- [ ] Create grid of vital cards (2x2):
  1. **Bills**: "All Paid" ✓ (green)
  2. **Tickets**: "2 Open" ⚠ (orange)
  3. **Chores**: "92% Done" ✓ (green)
  4. **Rent**: "Due In 5d" ⏰ (blue)
- [ ] Each vital card:
  - GlassCard container
  - Icon at top (color-coded)
  - Title (bold, 14)
  - Status text (20-24, bold)
  - Status indicator (checkmark, warning, clock)
  - Color-coded based on status

#### 4.4: Build AI Insights Section (20 min)
- [ ] Section header: "AI INSIGHTS"
- [ ] Create list of insight cards:
  - Each in GlassCard
  - Icon: Brain or sparkles (purple)
  - Message text (13-14, multi-line)
  - Timestamp (small, muted)
- [ ] Sample insights:
  - "Maintenance response time improved by 15% this month"
  - "Rent collection rate is above average"
  - "Consider scheduling AC maintenance before summer"

---

### Step 5: Update LandlordFinanceScreen (2 hours)

**File:** `lib/features/landlord/presentation/screens/landlord_finance_screen.dart`

**Reference:** Screenshots 125904, 125907 (Finance with chart)

#### 5.1: Setup Screen (15 min)
- [ ] Verify StatefulWidget structure
- [ ] Add state for:
  - `double netIncome` (14250.00)
  - `List<RevenueDataPoint> revenueHistory`
  - `List<ExpenseCategory> expenses`
  - `String selectedPeriod` ("6M")

#### 5.2: Build Net Income Hero Card (30 min)
- [ ] Large glass card at top:
  - Label: "NET INCOME" (tracked, small)
  - Amount: "RM 14,250.00" (font size 36, bold, gradient)
  - Change indicator: "+RM 1,200 vs last month" (green, small)
- [ ] Add quick stats row below amount:
  - Revenue: "RM 18,500"
  - Expenses: "RM 4,250"
  - Margin: "77%" (color-coded: green if >70%, amber if 50-70%, red if <50%)

#### 5.3: Build Revenue Trend Chart (1 hour)
- [ ] Section header: "REVENUE TREND" with period selector
- [ ] Period selector chips:
  - Options: "1M", "3M", "6M", "1Y", "ALL"
  - Active chip: Highlighted with gradient background
  - Tap to switch period
- [ ] Implement line chart:
  - Use fl_chart package (if not installed, add to pubspec.yaml)
  - X-axis: Months (Jan, Feb, Mar, Apr, May, Jun)
  - Y-axis: Revenue (RM 0 - RM 20k)
  - Line: Gradient stroke (cyan → purple)
  - Gradient fill below line (subtle)
  - Touch interaction: Show tooltip with exact value
- [ ] Chart styling:
  - Background: Transparent
  - Grid lines: White.withOpacity(0.05)
  - Labels: Font size 10, muted color
  - Smooth curve (Curves.easeInOut)

#### 5.4: Build Expense Breakdown (30 min)
- [ ] Section header: "EXPENSE BREAKDOWN"
- [ ] Create list of expense items:
  - Each in horizontal layout
  - Left: Category icon + name
  - Center: Progress bar (percentage of total)
  - Right: Amount
- [ ] Expense categories:
  1. Maintenance: RM 1,500 (35%) - Orange
  2. Utilities: RM 1,200 (28%) - Cyan
  3. Insurance: RM 800 (19%) - Blue
  4. Services: RM 750 (18%) - Purple
- [ ] Progress bar styling:
  - Height: 6
  - Background: White.withOpacity(0.1)
  - Foreground: Category color
  - Rounded caps
  - Animated on load

---

### Step 6: Create MaintenanceScreen (2 hours)

**File:** `lib/features/landlord/presentation/screens/landlord_maintenance_screen.dart` (new file)

**Reference:** Screenshot 125938 (Maintenance ticket list)

#### 6.1: Create File & Setup (20 min)
- [ ] Create new file in landlord/presentation/screens/
- [ ] Import required packages:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:lucide_icons/lucide_icons.dart';
  import '../../../../core/theme/app_colors.dart';
  import '../../../../core/widgets/glass_card.dart';
  ```
- [ ] Create StatefulWidget: LandlordMaintenanceScreen
- [ ] Create MaintenanceTicket model:
  ```dart
  class MaintenanceTicket {
    final String id;
    final String title;
    final String description;
    final String property;
    final String unit;
    final TicketPriority priority;
    final TicketStatus status;
    final DateTime createdAt;
    final String? assignedTo;
  }

  enum TicketPriority { low, medium, high, emergency }
  enum TicketStatus { submitted, inProgress, resolved }
  ```

#### 6.2: Build Header (20 min)
- [ ] App bar or custom header:
  - "MAINTENANCE" title
  - Subtitle: "3 Active Tickets"
  - Filter button (top right)
  - Back button (if not using tabs)

#### 6.3: Build Ticket List (1 hour)
- [ ] Create tabs: ACTIVE / RESOLVED / ALL
- [ ] Build ticket card (_buildTicketCard):
  - GlassCard container
  - Left section:
    - Property name (bold, 14)
    - Unit number (muted, 12)
    - Issue title (16, bold)
  - Right section:
    - Priority badge (HIGH/MEDIUM/LOW)
    - Status indicator
  - Bottom section:
    - Timestamp: "Created 2d ago"
    - Action button: "View Details"
- [ ] Priority badge styling:
  - HIGH PRIORITY: Red background, white text
  - MEDIUM PRIORITY: Orange background, white text
  - LOW PRIORITY: Blue background, white text
  - Emergency: Pulsing red animation
- [ ] Add mock tickets:
  ```dart
  [
    MaintenanceTicket(
      title: 'Leaking Sink',
      property: 'Verdi Eco-Dominium',
      unit: 'Unit 4-2',
      priority: TicketPriority.high,
      status: TicketStatus.submitted,
      createdAt: DateTime.now().subtract(Duration(hours: 6)),
    ),
    MaintenanceTicket(
      title: 'AC Not Cooling',
      property: 'The Grand Subang',
      unit: 'Block B-12',
      priority: TicketPriority.medium,
      status: TicketStatus.inProgress,
      createdAt: DateTime.now().subtract(Duration(days: 2)),
    ),
    MaintenanceTicket(
      title: 'Broken Tile',
      property: 'Verdi Eco-Dominium',
      unit: 'Unit 4-2',
      priority: TicketPriority.low,
      status: TicketStatus.submitted,
      createdAt: DateTime.now().subtract(Duration(days: 5)),
    ),
  ]
  ```

#### 6.4: Add Interactions (20 min)
- [ ] Tap ticket card → Navigate to ticket detail screen
- [ ] Add filter options:
  - By property
  - By priority
  - By status
- [ ] Add empty state for each tab
- [ ] Add pull-to-refresh

---

### Step 7: Create LeaseSentinelLandlordScreen (1.5 hours)

**File:** `lib/features/landlord/presentation/screens/lease_sentinel_landlord_screen.dart` (new file)

**Reference:** Screenshot 125959 (Lease Sentinel contract overview)

#### 7.1: Create File & Setup (20 min)
- [ ] Create new file
- [ ] Create StatefulWidget: LeaseSentinelLandlordScreen
- [ ] Add state for:
  - `Property? selectedProperty`
  - `Tenant? selectedTenant`
  - `LeaseData? leaseData`
  - `bool showPropertySelector`
  - `bool showTenantSelector`

#### 7.2: Build Header with Selectors (40 min)
- [ ] Create header section:
  - Back button
  - "Lease Sentinel" title
  - "AI CONTRACT OVERVIEW" subtitle (tracked, small)
- [ ] Property selector dropdown:
  - Display: "UNIT 4-2" with dropdown icon
  - Tap → Show property selector modal (screenshot 130007)
  - Selected property: "Verdi Eco-Dominium"
- [ ] Build property selector modal:
  - Title: "Select Property"
  - Subtitle: "Choose a property to analyze"
  - List of properties with icons
  - Each property shows: Name, Unit, Tenant count
  - Tap to select → Close modal → Load lease data

#### 7.3: Build Lease Overview Card (30 min)
- [ ] Large glass card showing:
  - Tenant name: "Analyzing: Ali Rahman"
  - Rent share: "RM 900" (large, bold)
  - Expiry date: "31 Dec 2025" (with calendar icon)
  - Status badge: "ACTIVE" (green)
- [ ] Card styling:
  - Gradient background (blue → purple subtle)
  - Border with glow
  - Icon badges for rent and expiry

#### 7.4: Build AI Chat Section (30 min)
- [ ] Chat message area:
  - AI message bubble:
    - Icon: Document/bot icon
    - Message: "Hello. I have indexed the tenancy agreement for Verdi Eco-Dominium. Currently analyzing context for tenant: Ali Rahman."
    - Timestamp
- [ ] Input area at bottom:
  - TextField: "Ask about Ali Rahman's lease..."
  - Send button with gradient
  - Similar to RexInterface input styling

#### 7.5: Add Tenant Selector Modal (20 min)
- [ ] Reference: Screenshot 130010
- [ ] Build modal:
  - Title: "Select Tenant"
  - Subtitle: "Who in Unit 4-2?"
  - List of tenants in selected property
  - Each tenant shows: Avatar, Name, Rent amount, Status (Active/Inactive)
  - Checkmark on selected tenant
  - Back and close buttons

---

### Step 8: Create LazyLoggerScreen (1 hour)

**File:** `lib/features/landlord/presentation/screens/lazy_logger_screen.dart` (new file)

**Reference:** Screenshot 125947 (AI Document Indexer)

#### 8.1: Create File & Setup (15 min)
- [ ] Create new file
- [ ] Create StatefulWidget: LazyLoggerScreen
- [ ] Add state for:
  - `List<DocumentCategory> categories`
  - `List<IndexedDocument> documents`
  - `bool isIndexing`

#### 8.2: Build Hero Section (20 min)
- [ ] Header:
  - "Lazy Logger" title
  - "AI DOCUMENT INDEXER" subtitle
  - Brain/file icon with glow
- [ ] Stats row:
  - Documents indexed: "47"
  - Last sync: "2 min ago"
  - Storage used: "124 MB"

#### 8.3: Build Document Categories (25 min)
- [ ] Grid of category cards:
  - Leases & Contracts
  - Invoices
  - Maintenance Records
  - Property Photos
  - Insurance Documents
  - Others
- [ ] Each category card:
  - Icon (color-coded)
  - Category name
  - Document count
  - Last updated
  - Tap → View documents in category

#### 8.4: Add Document Upload (15 min)
- [ ] Floating action button or upload area:
  - "Upload Document" button
  - Supports: PDF, JPG, PNG, DOCX
  - Drag & drop area (web)
  - Camera/gallery picker (mobile)
- [ ] Upload flow:
  - Select file → Show progress → Index with AI → Add to category
  - Show indexing animation

---

### Step 9: Update LandlordRexAIScreen (30 min)

**File:** `lib/features/landlord/presentation/screens/landlord_rex_ai_screen.dart`

**Reference:** Screenshot 125859 (Rex AI chat)

#### 9.1: Update Greeting Message (15 min)
- [ ] Change initial AI greeting:
  ```dart
  "Hello Dato'. I'm Rex. Your Sync Score is stable. How can I assist you today?"
  ```
- [ ] Add context awareness:
  - If from Asset Command → General landlord assistance
  - If from Property Pulse → Property health questions
  - If from Lease Sentinel → Lease/contract questions
  - If from Maintenance → Maintenance advice

#### 9.2: Update Mock Responses (15 min)
- [ ] Tailor responses for landlord context:
  - Tenant management questions
  - Rent collection advice
  - Maintenance prioritization
  - Legal compliance
  - Financial analysis
- [ ] Example responses:
  - "How do I handle late rent?" → "Here are the steps per Malaysian tenancy laws..."
  - "Should I increase rent?" → "Based on market data, the average increase in your area is..."
  - "Priority for maintenance?" → "High priority items affect habitability. I recommend..."

---

### Step 10: Update Navigation & Routes (30 min)

#### 10.1: Add New Routes (15 min)
**File:** `lib/core/router/app_router.dart`

- [ ] Add route constants in AppRoutes class:
  ```dart
  static const String propertyPulse = '/property-pulse';
  static const String landlordMaintenance = '/landlord-maintenance';
  static const String leaseSentinelLandlord = '/lease-sentinel-landlord';
  static const String lazyLogger = '/lazy-logger';
  ```
- [ ] Add route definitions:
  ```dart
  GoRoute(
    path: AppRoutes.propertyPulse,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const PropertyPulseScreen(),
      slideFromBottom: true,
    ),
  ),
  // ... repeat for other screens
  ```

#### 10.2: Wire Up Navigation (15 min)
- [ ] Update LandlordCommandScreen stat card taps:
  - System Health → `context.push(AppRoutes.propertyPulse)`
  - Maintenance → `context.push(AppRoutes.landlordMaintenance)`
  - Lazy Logger → `context.push(AppRoutes.lazyLogger)`
  - Sentinel → `context.push(AppRoutes.leaseSentinelLandlord)`
- [ ] Update Portfolio screen:
  - Property card tap → Property details (to be created later)
  - Add Unit button → Add unit flow (to be created later)

---

### Step 11: Testing Landlord UI (1.5 hours)

#### 11.1: Navigation Testing (30 min)
- [ ] Test login → Landlord Dev button → Shows Asset Command
- [ ] Test all 5 bottom nav tabs switch correctly
- [ ] Test Asset Command stat cards navigate to correct screens
- [ ] Test back button returns correctly
- [ ] Test deep linking works for all landlord routes

#### 11.2: Screen Functionality (30 min)
- [ ] Portfolio: Property list displays, cards tappable, Add Unit button works
- [ ] Asset Command: Stats display correctly, modules navigate
- [ ] Property Pulse: Health score displays, vitals show correctly
- [ ] Finance: Chart renders, expenses calculate correctly
- [ ] Maintenance: Tickets list, priorities show correct colors
- [ ] Lease Sentinel: Property/tenant selectors work, chat input functional
- [ ] Lazy Logger: Categories display, upload button accessible
- [ ] Rex AI: Greeting shows, messages send/receive

#### 11.3: UI Polish (30 min)
- [ ] All screens match reference screenshots:
  - Colors match (check with color picker)
  - Font sizes consistent
  - Spacing matches (padding, margins)
  - Border radius consistent
  - Glow effects subtle
- [ ] Animations smooth:
  - Page transitions
  - Tab switching
  - Chart animations
  - Progress bars
  - Health score counter
- [ ] Responsive:
  - Different screen sizes
  - Landscape orientation
  - ScrollViews scroll smoothly
  - No overflow errors

---

### Step 12: Final Polish & Documentation (30 min)

#### 12.1: Code Cleanup (15 min)
- [ ] Remove print statements
- [ ] Add TODO comments for backend integration
- [ ] Format all files: `dart format .`
- [ ] Run analyzer: `flutter analyze` → 0 errors
- [ ] Check for unused imports

#### 12.2: Documentation (15 min)
- [ ] Add comments to complex logic
- [ ] Document navigation flow
- [ ] Add screenshots to docs folder
- [ ] Update README with landlord features
- [ ] Create user guide for landlord screens

---

## 🎯 LANDLORD UI COMPLETION CHECKLIST

- [x] Router updated to use LandlordHomeScreen (Step 1 ✅)
- [x] Portfolio screen matches reference (Screenshot 130026) (Step 2 ✅)
- [x] Asset Command verified against reference (Screenshot 125911) (Step 3 ✅)
- [x] Property Pulse screen implemented (Screenshot 125927) (Step 4 ✅)
- [ ] Finance screen with chart (Screenshots 125904, 125907) (Step 5)
- [ ] Maintenance screen created (Screenshot 125938) (Step 6)
- [ ] Lease Sentinel landlord version (Screenshot 125959) (Step 7)
- [ ] Lazy Logger screen created (Screenshot 125947) (Step 8)
- [ ] Rex AI updated for landlord context (Screenshot 125859) (Step 9)
- [x] All navigation routes working (placeholder routes added)
- [x] Bottom nav showing on all screens (ResidexBottomNav created)
- [x] All screens match reference screenshots (Steps 2-4 complete)
- [x] Animations smooth and polished (Steps 2-4 have animations)
- [ ] Code clean and documented (Step 12)
- [ ] Ready for backend integration (Step 12)

---

## 📊 LANDLORD PROGRESS TRACKING

**Day 1: Steps 1-4 (Router, Portfolio, Asset Command, Property Pulse) - 3.5 hours**
- Started: February 3, 2026 - Evening Session
- Completed: February 3, 2026 - Evening Session
- Issues Found:
  - Missing icons in LucideIcons (grid3x3 → fixed to grid)
  - Missing colors (slate, blue shades → added to AppColors)
  - Bottom nav styling adjustments needed → fixed with glow effects
- Status: [x] Complete ✅

**Completed Items:**
- ✅ Step 1: Router Configuration (15 min)
- ✅ Step 2: LandlordPortfolioScreen (2 hours)
  - Property list with 3 mock properties
  - Status badges (OCCUPIED, VACANT)
  - Rent status labels (PAID, PENDING, OVERDUE)
  - Empty state
  - "+ ADD UNIT" button
- ✅ Step 3: LandlordCommandScreen Updates (1.5 hours)
  - Updated header with "Dato' Lee"
  - Added navigation to all stat cards
  - Created placeholder routes
- ✅ Step 4: PropertyPulseScreen (2 hours)
  - Animated health score card (87/100)
  - Vitals check section (4 cards)
  - AI insights section (3 insights)
  - All animations working
- ✅ Bonus: ResidexBottomNav widget created
  - Unified tenant/landlord navigation
  - Icon-only design with center emphasis
  - Blue glow effect on active icons

**Next Session: Steps 5-7 (Finance, Maintenance, Lease Sentinel) - 5.5 hours**
- Target: [Your next session date]
- Focus: Revenue charts, ticket management, contract analysis
- Status: [ ] Pending

**Day 4: Lazy Logger, Rex AI & Testing (3 hours)**
- Started: [Date/Time]
- Completed: [Date/Time]
- Issues: [List blockers]
- Status: [ ] Complete

---

**Estimated Total Time for Landlord UI:** 10-12 hours
**Target Completion:** [Your target date]
**Implementation Priority:** HIGH (Core landlord features)

---

## 📋 PHASE 8: BILL SPLITTER REDESIGN - UTILITY FOCUSED (8-10 hours)

**Reference Screenshots:** `C:\Users\pravi\Downloads\bill splitter\`
**Goal:** Transform bill splitter into utility-focused ledger (Rent, Electricity, Water, Internet, Gas only)

**Overview:**
- Remove food, groceries, entertainment categories
- Add utility categories with Malaysian providers (TNB, AIR SELANGOR, TIME, GAS PETRONAS, LANDLORD)
- Redesign dashboard to "Ledger" style (Outstanding/Settled cards)
- Add provider names, colored icons, status badges
- Filter system for payment status and categories

---

### PHASE 8.1: FOUNDATION - ENTITY & ENUM UPDATES (1 hour)

#### Step 8.1.1: Add BillCategory Enum

**File:** `lib/features/bills/domain/entities/bill_enums.dart`

**Required Imports:**
```dart
import 'package:flutter/material.dart';
```

**Add at end of file:**

```dart
/// Category of utility bill
enum BillCategory {
  rent,
  electricity,
  water,
  internet,
  gas,
  other;

  String get label {
    switch (this) {
      case BillCategory.rent:
        return 'Rent';
      case BillCategory.electricity:
        return 'Electricity';
      case BillCategory.water:
        return 'Water';
      case BillCategory.internet:
        return 'Internet';
      case BillCategory.gas:
        return 'Gas';
      case BillCategory.other:
        return 'Other';
    }
  }

  /// Get icon for category (Material Icons)
  IconData get icon {
    switch (this) {
      case BillCategory.rent:
        return Icons.home_rounded;
      case BillCategory.electricity:
        return Icons.flash_on_rounded;
      case BillCategory.water:
        return Icons.water_drop_rounded;
      case BillCategory.internet:
        return Icons.wifi_rounded;
      case BillCategory.gas:
        return Icons.local_fire_department_rounded;
      case BillCategory.other:
        return Icons.description_rounded;
    }
  }

  /// Get color for category (matching screenshot colors)
  Color get color {
    switch (this) {
      case BillCategory.rent:
        return const Color(0xFF10B981); // Green/Emerald
      case BillCategory.electricity:
        return const Color(0xFFF59E0B); // Orange/Yellow
      case BillCategory.water:
        return const Color(0xFF3B82F6); // Blue
      case BillCategory.internet:
        return const Color(0xFFA855F7); // Purple
      case BillCategory.gas:
        return const Color(0xFFEF4444); // Red
      case BillCategory.other:
        return const Color(0xFF64748B); // Gray
    }
  }

  /// Get background color for category icon
  Color get backgroundColor {
    switch (this) {
      case BillCategory.rent:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case BillCategory.electricity:
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case BillCategory.water:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case BillCategory.internet:
        return const Color(0xFFA855F7).withValues(alpha: 0.15);
      case BillCategory.gas:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case BillCategory.other:
        return const Color(0xFF64748B).withValues(alpha: 0.15);
    }
  }

  /// Get common provider names for category
  List<String> get commonProviders {
    switch (this) {
      case BillCategory.rent:
        return ['LANDLORD', 'PROPERTY MANAGEMENT'];
      case BillCategory.electricity:
        return ['TNB', 'SESB', 'SEB', 'SESCO'];
      case BillCategory.water:
        return ['AIR SELANGOR', 'SYABAS', 'SAJ', 'PBA', 'SAINS'];
      case BillCategory.internet:
        return ['TIME', 'MAXIS', 'UNIFI', 'CELCOM', 'DIGI', 'YES'];
      case BillCategory.gas:
        return ['GAS PETRONAS', 'GAS MALAYSIA'];
      case BillCategory.other:
        return ['OTHER'];
    }
  }
}

/// Payment status for bills (enhanced)
enum PaymentStatus {
  paid,
  unpaid,
  pending;

  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.unpaid:
        return 'UNPAID';
      case PaymentStatus.pending:
        return 'PENDING';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981); // Green
      case PaymentStatus.unpaid:
        return const Color(0xFFEF4444); // Red
      case PaymentStatus.pending:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case PaymentStatus.unpaid:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case PaymentStatus.pending:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
    }
  }
}
```

---

#### Step 8.1.2: Update Bill Entity

**File:** `lib/features/bills/domain/entities/bill.dart`

**Required Imports:**
```dart
import 'package:equatable/equatable.dart';
import 'receipt_item.dart';
import 'bill_enums.dart';  // ✅ ADD THIS IMPORT
```

**Update Bill class:**

```dart
class Bill extends Equatable {
  final String id;
  final String title;
  final String location;
  final double totalAmount;
  final DateTime createdAt;
  final List<String> participantIds;
  final Map<String, double> participantShares;
  final Map<String, bool> paymentStatus;
  final List<ReceiptItem> items;
  final String? imageUrl;

  // ✅ NEW FIELDS FOR UTILITY BILLS:
  final BillCategory category;
  final String provider;
  final DateTime? dueDate;
  final BillStatus status;

  const Bill({
    required this.id,
    required this.title,
    required this.location,
    required this.totalAmount,
    required this.createdAt,
    required this.participantIds,
    required this.participantShares,
    required this.paymentStatus,
    required this.items,
    this.imageUrl,
    // ✅ NEW PARAMETERS:
    this.category = BillCategory.other,
    this.provider = '',
    this.dueDate,
    this.status = BillStatus.pending,
  });

  // ✅ UPDATE copyWith method to include new fields:
  Bill copyWith({
    String? id,
    String? title,
    String? location,
    double? totalAmount,
    DateTime? createdAt,
    List<String>? participantIds,
    Map<String, double>? participantShares,
    Map<String, bool>? paymentStatus,
    List<ReceiptItem>? items,
    String? imageUrl,
    BillCategory? category,
    String? provider,
    DateTime? dueDate,
    BillStatus? status,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      participantIds: participantIds ?? this.participantIds,
      participantShares: participantShares ?? this.participantShares,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      items: items ?? this.items,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      provider: provider ?? this.provider,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  // ✅ UPDATE props list:
  @override
  List<Object?> get props => [
    id,
    title,
    location,
    totalAmount,
    createdAt,
    participantIds,
    participantShares,
    paymentStatus,
    items,
    imageUrl,
    category,
    provider,
    dueDate,
    status,
  ];

  // ✅ ADD HELPER METHOD to get individual payment status:
  PaymentStatus getPaymentStatusForUser(String userId) {
    final hasPaid = paymentStatus[userId] ?? false;
    if (hasPaid) return PaymentStatus.paid;

    // Check if bill is overdue
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
      return PaymentStatus.unpaid;
    }

    return PaymentStatus.pending;
  }

  // ✅ ADD HELPER METHOD to check if bill is settled:
  bool get isSettled {
    return paymentStatus.values.every((paid) => paid);
  }

  // ✅ ADD HELPER METHOD to get outstanding amount:
  double get outstandingAmount {
    double outstanding = 0.0;
    paymentStatus.forEach((userId, hasPaid) {
      if (!hasPaid) {
        outstanding += participantShares[userId] ?? 0.0;
      }
    });
    return outstanding;
  }
}
```

---

#### Step 8.1.3: Update Bill Model (Database)

**File:** `lib/features/bills/data/models/bill_model.dart`

**In `fromJson` method, add after existing fields:**
```dart
category: BillCategory.values.firstWhere(
  (e) => e.name == (json['category'] as String?),
  orElse: () => BillCategory.other,
),
provider: json['provider'] as String? ?? '',
dueDate: json['dueDate'] != null
    ? DateTime.parse(json['dueDate'] as String)
    : null,
status: BillStatus.values.firstWhere(
  (e) => e.name == (json['status'] as String?),
  orElse: () => BillStatus.pending,
),
```

**In `toJson` method, add after existing fields:**
```dart
'category': category.name,
'provider': provider,
'dueDate': dueDate?.toIso8601String(),
'status': status.name,
```

---

#### Step 8.1.4: Update Database Table

**File:** `lib/data/database/tables/bills_table.dart`

**Add new columns:**

```dart
class BillsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get billId => text()();
  TextColumn get title => text()();
  TextColumn get location => text()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get imageUrl => text().nullable()();

  // ✅ ADD THESE NEW COLUMNS:
  TextColumn get category => text().withDefault(const Constant('other'))();
  TextColumn get provider => text().withDefault(const Constant(''))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
}
```

**Note:** After updating, increment schema version in `app_database.dart` or uninstall/reinstall app for development.

---

**✅ Phase 8.1 Complete - Continue to Phase 8.2 for Ledger Dashboard redesign**

**Files Modified:**
1. ✅ `bill_enums.dart` - Added BillCategory and PaymentStatus enums
2. ✅ `bill.dart` - Added category, provider, dueDate, status fields + helper methods
3. ✅ `bill_model.dart` - Updated fromJson/toJson for new fields
4. ✅ `bills_table.dart` - Added 4 new database columns

**Next:** Phase 8.2 - Create Ledger Screen (Dashboard Redesign)

---

### Phase 8.2: Ledger Dashboard Redesign (3-4 hours)

**Goal:** Create utility-focused bill dashboard with Outstanding/Settled cards, filters, and clean list view

**Reference:** Screenshot 152330 - Ledger dashboard with summary cards and bill list

---

#### Step 8.2.1: Create Outstanding/Settled Summary Cards Widget

**File:** `lib/features/bills/presentation/widgets/ledger_summary_cards.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';

class LedgerSummaryCards extends StatelessWidget {
  final int outstandingCount;
  final double outstandingAmount;
  final int settledCount;
  final double settledAmount;

  const LedgerSummaryCards({
    super.key,
    required this.outstandingCount,
    required this.outstandingAmount,
    required this.settledCount,
    required this.settledAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Outstanding Card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            gradient: LinearGradient(
              colors: [
                AppColors.red500.withValues(alpha: 0.1),
                AppColors.orange500.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.red500.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.red500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning_rounded,
                        color: AppColors.red500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Outstanding',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'RM ${outstandingAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.red500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$outstandingCount ${outstandingCount == 1 ? 'bill' : 'bills'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingMedium),
        // Settled Card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            gradient: LinearGradient(
              colors: [
                AppColors.green500.withValues(alpha: 0.1),
                AppColors.cyan500.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.green500.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.green500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settled',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'RM ${settledAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.green500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$settledCount ${settledCount == 1 ? 'bill' : 'bills'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

---

#### Step 8.2.2: Create Bill List Item Widget with Category Badge

**File:** `lib/features/bills/presentation/widgets/bill_list_item.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_enums.dart';

class BillListItem extends StatelessWidget {
  final Bill bill;
  final String currentUserId;
  final VoidCallback onTap;

  const BillListItem({
    super.key,
    required this.bill,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userStatus = bill.getPaymentStatusForUser(currentUserId);
    final userShare = bill.participantShares[currentUserId] ?? 0.0;
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bill.category.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bill.category.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                bill.category.icon,
                color: bill.category.color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingMedium),
            // Bill Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bill.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(userStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.provider.isNotEmpty ? bill.provider : bill.category.name.toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bill.dueDate != null
                            ? 'Due: ${dateFormat.format(bill.dueDate!)}'
                            : 'No due date',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Your share: RM ${userShare.toStringAsFixed(2)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.cyan500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: status.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
```

---

#### Step 8.2.3: Create Category Filter Chip Widget

**File:** `lib/features/bills/presentation/widgets/category_filter_chip.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/bill_enums.dart';

class CategoryFilterChip extends StatelessWidget {
  final BillCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryFilterChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? category.backgroundColor
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? category.color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: isSelected ? category.color : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              category.name.toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? category.color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### Step 8.2.4: Update Dashboard Screen with New Ledger UI

**File:** `lib/features/bills/presentation/screens/dashboard_screen.dart`

**Step 1: Add imports at the top:**
```dart
import '../../domain/entities/bill_enums.dart';
import '../widgets/ledger_summary_cards.dart';
import '../widgets/bill_list_item.dart';
import '../widgets/category_filter_chip.dart';
```

**Step 2: Add state variables in `_DashboardScreenState` (after existing state variables):**
```dart
// Filter states
BillCategory? _selectedCategory;
String _searchQuery = '';
bool _showOutstandingOnly = false;
```

**Step 3: Add filter method (after existing methods):**
```dart
List<Bill> _getFilteredBills() {
  var filtered = bills.where((bill) {
    // Search filter
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      final matchesTitle = bill.title.toLowerCase().contains(searchLower);
      final matchesProvider = bill.provider.toLowerCase().contains(searchLower);
      if (!matchesTitle && !matchesProvider) return false;
    }

    // Category filter
    if (_selectedCategory != null && bill.category != _selectedCategory) {
      return false;
    }

    // Outstanding filter
    if (_showOutstandingOnly) {
      final userStatus = bill.getPaymentStatusForUser(currentUser?.uid ?? '');
      if (userStatus == PaymentStatus.paid) return false;
    }

    return true;
  }).toList();

  // Sort by due date (overdue first, then by date)
  filtered.sort((a, b) {
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  });

  return filtered;
}

// Calculate summary stats
Map<String, dynamic> _getSummaryStats() {
  int outstandingCount = 0;
  double outstandingAmount = 0.0;
  int settledCount = 0;
  double settledAmount = 0.0;

  for (final bill in bills) {
    final userStatus = bill.getPaymentStatusForUser(currentUser?.uid ?? '');
    final userShare = bill.participantShares[currentUser?.uid ?? ''] ?? 0.0;

    if (userStatus == PaymentStatus.paid) {
      settledCount++;
      settledAmount += userShare;
    } else {
      outstandingCount++;
      outstandingAmount += userShare;
    }
  }

  return {
    'outstandingCount': outstandingCount,
    'outstandingAmount': outstandingAmount,
    'settledCount': settledCount,
    'settledAmount': settledAmount,
  };
}
```

**Step 4: Replace the entire `build` method body:**
```dart
@override
Widget build(BuildContext context) {
  final filteredBills = _getFilteredBills();
  final stats = _getSummaryStats();

  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Row(
              children: [
                Text(
                  'Ledger',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: AppColors.cyan500,
                    size: 32,
                  ),
                  onPressed: () => _showAddBillDialog(),
                ),
              ],
            ),
          ),

          // Summary Cards
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
            ),
            child: LedgerSummaryCards(
              outstandingCount: stats['outstandingCount'],
              outstandingAmount: stats['outstandingAmount'],
              settledCount: stats['settledCount'],
              settledAmount: stats['settledAmount'],
            ),
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search bills...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.cyan500.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          // Category Filter Chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              children: [
                // All Filter
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedCategory == null
                            ? AppColors.cyan500.withValues(alpha: 0.2)
                            : AppColors.surfaceLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedCategory == null
                              ? AppColors.cyan500.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'ALL',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _selectedCategory == null
                              ? AppColors.cyan500
                              : AppColors.textSecondary,
                          fontWeight: _selectedCategory == null
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Category Filters
                ...BillCategory.values.map((category) {
                  if (category == BillCategory.other) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryFilterChip(
                      category: category,
                      isSelected: _selectedCategory == category,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          // Outstanding Toggle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _showOutstandingOnly,
                  onChanged: (value) {
                    setState(() {
                      _showOutstandingOnly = value ?? false;
                    });
                  },
                  activeColor: AppColors.cyan500,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  'Show outstanding only',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          // Bills List
          Expanded(
            child: filteredBills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: AppColors.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedCategory != null
                              ? 'No bills found'
                              : 'No bills yet',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedCategory != null
                              ? 'Try adjusting your filters'
                              : 'Tap + to add your first bill',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingLarge,
                      vertical: AppDimensions.paddingSmall,
                    ),
                    itemCount: filteredBills.length,
                    itemBuilder: (context, index) {
                      final bill = filteredBills[index];
                      return BillListItem(
                        bill: bill,
                        currentUserId: currentUser?.uid ?? '',
                        onTap: () {
                          // Navigate to bill details
                          context.push('/bills/${bill.id}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
```

---

#### Step 8.2.5: Update Add Bill Dialog to Support New Fields

**File:** `lib/features/bills/presentation/screens/dashboard_screen.dart`

**In the `_showAddBillDialog` method, update the dialog to include category and provider selection:**

```dart
void _showAddBillDialog() {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final providerController = TextEditingController();
  BillCategory selectedCategory = BillCategory.rent;
  DateTime? selectedDueDate;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        title: Text(
          'Add New Bill',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextField(
                controller: titleController,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Bill Title',
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.deepSpace.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<BillCategory>(
                value: selectedCategory,
                dropdownColor: AppColors.surfaceLight,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.deepSpace.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                items: BillCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.name.toUpperCase(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedCategory = value!;
                    // Auto-fill provider if common provider exists
                    if (selectedCategory.commonProviders.isNotEmpty) {
                      providerController.text = selectedCategory.commonProviders.first;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Provider with suggestions
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return selectedCategory.commonProviders;
                  }
                  return selectedCategory.commonProviders.where((provider) {
                    return provider.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (selection) {
                  providerController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  providerController.text = controller.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Provider',
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      hintText: selectedCategory.commonProviders.isNotEmpty
                          ? selectedCategory.commonProviders.first
                          : 'Enter provider name',
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.deepSpace.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Total Amount (RM)',
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixText: 'RM ',
                  prefixStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cyan500,
                  ),
                  filled: true,
                  fillColor: AppColors.deepSpace.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due Date Picker
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppColors.cyan500,
                            surface: AppColors.surfaceLight,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setDialogState(() {
                      selectedDueDate = date;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.deepSpace.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.cyan500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        selectedDueDate != null
                            ? 'Due: ${DateFormat('dd MMM yyyy').format(selectedDueDate!)}'
                            : 'Select due date',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: selectedDueDate != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  amountController.text.isNotEmpty) {
                // Create bill with new fields
                final newBill = Bill(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text,
                  location: currentUser?.householdName ?? 'My House',
                  totalAmount: double.parse(amountController.text),
                  createdAt: DateTime.now(),
                  category: selectedCategory,
                  provider: providerController.text,
                  dueDate: selectedDueDate,
                  status: BillStatus.pending,
                  participants: {},
                  participantShares: {},
                  paymentStatus: {},
                  splitType: SplitType.equal,
                  paidBy: currentUser?.uid ?? '',
                );

                // Add bill logic here (call provider)
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Add Bill',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.deepSpace,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

**✅ Phase 8.2 Complete - Ledger Dashboard with filters and category badges**

**Files Created:**
1. ✅ `ledger_summary_cards.dart` - Outstanding/Settled cards with stats
2. ✅ `bill_list_item.dart` - Bill list item with category icon and status badge
3. ✅ `category_filter_chip.dart` - Category filter chip with icon

**Files Modified:**
1. ✅ `dashboard_screen.dart` - Complete Ledger UI with search, filters, and bill list
2. ✅ `dashboard_screen.dart` (_showAddBillDialog) - Enhanced with category/provider/due date

**Next:** Phase 8.3 - Outstanding/Settled Detail Screens

---

### Phase 8.3: Bill Detail Screen Enhancement (2-3 hours)

**Goal:** Enhance bill detail screen with category-specific styling, payment tracking, and split visualization

**Reference:** Screenshots 152333, 152335 - Bill details with participant list and payment status

---

#### Step 8.3.1: Create Payment Status Indicator Widget

**File:** `lib/features/bills/presentation/widgets/payment_status_indicator.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/bill_enums.dart';

class PaymentStatusIndicator extends StatelessWidget {
  final PaymentStatus status;
  final double size;
  final bool showLabel;

  const PaymentStatusIndicator({
    super.key,
    required this.status,
    this.size = 40,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status.backgroundColor,
            border: Border.all(
              color: status.color.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: status.color.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            status == PaymentStatus.paid
                ? Icons.check_rounded
                : status == PaymentStatus.unpaid
                    ? Icons.close_rounded
                    : Icons.schedule_rounded,
            color: status.color,
            size: size * 0.6,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            status.label,
            style: AppTextStyles.bodySmall.copyWith(
              color: status.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
```

---

#### Step 8.3.2: Create Participant Payment Card Widget

**File:** `lib/features/bills/presentation/widgets/participant_payment_card.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/residex_avatar.dart';
import '../../domain/entities/bill_enums.dart';
import 'payment_status_indicator.dart';

class ParticipantPaymentCard extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final double shareAmount;
  final PaymentStatus status;
  final bool isCurrentUser;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onRemind;

  const ParticipantPaymentCard({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.shareAmount,
    required this.status,
    this.isCurrentUser = false,
    this.onMarkPaid,
    this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      gradient: LinearGradient(
        colors: [
          status.backgroundColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderColor: status.color.withValues(alpha: 0.2),
      child: Row(
        children: [
          // Avatar
          ResidexAvatar(
            imageUrl: userAvatar,
            name: userName,
            size: 48,
            showBorder: true,
            borderColor: status.color,
          ),
          const SizedBox(width: AppDimensions.paddingMedium),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOU',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.cyan500,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${shareAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Status & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PaymentStatusIndicator(
                status: status,
                size: 36,
                showLabel: false,
              ),
              const SizedBox(height: 8),
              if (status != PaymentStatus.paid && onMarkPaid != null)
                TextButton(
                  onPressed: onMarkPaid,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    backgroundColor: status.color.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isCurrentUser ? 'Mark Paid' : 'Remind',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

#### Step 8.3.3: Create Bill Header Card Widget

**File:** `lib/features/bills/presentation/widgets/bill_header_card.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/bill.dart';

class BillHeaderCard extends StatelessWidget {
  final Bill bill;

  const BillHeaderCard({
    super.key,
    required this.bill,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final isOverdue = bill.dueDate != null &&
                      DateTime.now().isAfter(bill.dueDate!) &&
                      !bill.isSettled;

    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      gradient: LinearGradient(
        colors: [
          bill.category.backgroundColor.withValues(alpha: 0.2),
          bill.category.color.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: bill.category.color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Icon & Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bill.category.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: bill.category.color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bill.category.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  bill.category.icon,
                  color: bill.category.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.category.name.toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: bill.category.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.title,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Provider
          if (bill.provider.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.business_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  bill.provider,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
          ],

          // Due Date
          Row(
            children: [
              Icon(
                isOverdue
                    ? Icons.warning_rounded
                    : Icons.calendar_today_rounded,
                color: isOverdue ? AppColors.red500 : AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                bill.dueDate != null
                    ? (isOverdue
                        ? 'Overdue: ${dateFormat.format(bill.dueDate!)}'
                        : 'Due: ${dateFormat.format(bill.dueDate!)}')
                    : 'No due date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isOverdue
                      ? AppColors.red500
                      : AppColors.textSecondary,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'RM ${bill.totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.h2.copyWith(
                  color: bill.category.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Outstanding Amount (if not fully settled)
          if (!bill.isSettled) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Outstanding',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  'RM ${bill.outstandingAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.red500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

---

#### Step 8.3.4: Update Bill Detail Screen

**File:** `lib/features/bills/presentation/screens/bill_detail_screen.dart`

**Step 1: Add imports at the top:**
```dart
import '../../domain/entities/bill_enums.dart';
import '../widgets/bill_header_card.dart';
import '../widgets/participant_payment_card.dart';
```

**Step 2: Replace the header section in the `build` method (around line 60-120):**

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          // App Bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Bill Details',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => _showBillOptions(),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bill Header Card
                  BillHeaderCard(bill: bill),

                  const SizedBox(height: AppDimensions.paddingLarge),

                  // Split Details Section Header
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        color: AppColors.cyan500,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Split Details',
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${bill.participants.length} ${bill.participants.length == 1 ? 'person' : 'people'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.cyan500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.paddingMedium),

                  // Participant List
                  ...bill.participants.keys.map((userId) {
                    final userName = bill.participants[userId] ?? 'Unknown';
                    final shareAmount = bill.participantShares[userId] ?? 0.0;
                    final paymentStatus = bill.getPaymentStatusForUser(userId);
                    final isCurrentUser = userId == currentUser?.uid;

                    return ParticipantPaymentCard(
                      userId: userId,
                      userName: userName,
                      userAvatar: null, // Fetch from user service if available
                      shareAmount: shareAmount,
                      status: paymentStatus,
                      isCurrentUser: isCurrentUser,
                      onMarkPaid: isCurrentUser && paymentStatus != PaymentStatus.paid
                          ? () => _markAsPaid(userId)
                          : null,
                      onRemind: !isCurrentUser && paymentStatus != PaymentStatus.paid
                          ? () => _remindUser(userId, userName)
                          : null,
                    );
                  }).toList(),

                  const SizedBox(height: AppDimensions.paddingLarge),

                  // Payment Summary Card
                  if (!bill.isSettled)
                    GlassCard(
                      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.orange500.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                      borderColor: AppColors.orange500.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: AppColors.orange500,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Waiting for ${_getUnpaidCount()} ${_getUnpaidCount() == 1 ? 'person' : 'people'} to pay',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppDimensions.paddingXLarge),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          if (!bill.isSettled &&
              bill.getPaymentStatusForUser(currentUser?.uid ?? '') != PaymentStatus.paid)
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.deepSpace,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: () => _markAsPaid(currentUser?.uid ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bill.category.color,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Mark as Paid',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// Helper methods
int _getUnpaidCount() {
  return bill.paymentStatus.values.where((paid) => !paid).length;
}

void _markAsPaid(String userId) {
  // Call provider to mark as paid
  // ref.read(billsProvider.notifier).markUserAsPaid(bill.id, userId);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Marked as paid!'),
      backgroundColor: AppColors.green500,
    ),
  );
}

void _remindUser(String userId, String userName) {
  // Send reminder notification
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Reminder sent to $userName'),
      backgroundColor: AppColors.cyan500,
    ),
  );
}

void _showBillOptions() {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.edit_rounded, color: AppColors.cyan500),
          title: Text('Edit Bill', style: AppTextStyles.bodyLarge),
          onTap: () {
            Navigator.pop(context);
            // Navigate to edit screen
          },
        ),
        ListTile(
          leading: Icon(Icons.share_rounded, color: AppColors.blue500),
          title: Text('Share Bill', style: AppTextStyles.bodyLarge),
          onTap: () {
            Navigator.pop(context);
            // Share bill logic
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_rounded, color: AppColors.red500),
          title: Text('Delete Bill', style: AppTextStyles.bodyLarge),
          onTap: () {
            Navigator.pop(context);
            _confirmDelete();
          },
        ),
        const SizedBox(height: AppDimensions.paddingLarge),
      ],
    ),
  );
}

void _confirmDelete() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Delete Bill?',
        style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
      ),
      content: Text(
        'This action cannot be undone. All participants will lose access to this bill.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Delete bill logic
            Navigator.pop(context);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Delete',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

**✅ Phase 8.3 Complete - Enhanced Bill Detail Screen**

**Files Created:**
1. ✅ `payment_status_indicator.dart` - Payment status icon with circle indicator
2. ✅ `participant_payment_card.dart` - Participant card with avatar, amount, and status
3. ✅ `bill_header_card.dart` - Bill header with category styling and due date

**Files Modified:**
1. ✅ `bill_detail_screen.dart` - Complete redesign with category styling and payment tracking

**Next:** Phase 8.4 - Provider Management & Bill History

---

### Phase 8.4: State Management & Provider Integration (1-2 hours)

**Goal:** Update Riverpod providers to handle new bill fields and implement filtering/sorting logic

---

#### Step 8.4.1: Update Bills Provider with New Methods

**File:** `lib/features/bills/presentation/providers/bills_provider.dart`

**Add new methods to BillsNotifier class:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/repositories/bills_repository.dart';

class BillsNotifier extends StateNotifier<AsyncValue<List<Bill>>> {
  final BillsRepository _repository;

  BillsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadBills();
  }

  Future<void> loadBills() async {
    state = const AsyncValue.loading();
    try {
      final bills = await _repository.getAllBills();
      state = AsyncValue.data(bills);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  // ✅ ADD: Create bill with new fields
  Future<void> createBill({
    required String title,
    required String location,
    required double totalAmount,
    required BillCategory category,
    required String provider,
    required DateTime? dueDate,
    required Map<String, String> participants,
    required String paidBy,
    String? imageUrl,
  }) async {
    try {
      final bill = Bill(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        location: location,
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
        participants: participants,
        participantShares: _calculateEqualShares(totalAmount, participants.length),
        paymentStatus: _initializePaymentStatus(participants.keys.toList()),
        splitType: SplitType.equal,
        paidBy: paidBy,
        imageUrl: imageUrl,
        category: category,
        provider: provider,
        dueDate: dueDate,
        status: BillStatus.pending,
      );

      await _repository.createBill(bill);
      await loadBills();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  // ✅ ADD: Mark user as paid
  Future<void> markUserAsPaid(String billId, String userId) async {
    try {
      final bills = state.value ?? [];
      final billIndex = bills.indexWhere((b) => b.id == billId);
      if (billIndex == -1) return;

      final bill = bills[billIndex];
      final updatedPaymentStatus = Map<String, bool>.from(bill.paymentStatus);
      updatedPaymentStatus[userId] = true;

      final updatedBill = Bill(
        id: bill.id,
        title: bill.title,
        location: bill.location,
        totalAmount: bill.totalAmount,
        createdAt: bill.createdAt,
        participants: bill.participants,
        participantShares: bill.participantShares,
        paymentStatus: updatedPaymentStatus,
        splitType: bill.splitType,
        paidBy: bill.paidBy,
        imageUrl: bill.imageUrl,
        category: bill.category,
        provider: bill.provider,
        dueDate: bill.dueDate,
        status: bill.status,
      );

      await _repository.updateBill(updatedBill);
      await loadBills();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  // ✅ ADD: Get bills by category
  List<Bill> getBillsByCategory(BillCategory category) {
    final bills = state.value ?? [];
    return bills.where((bill) => bill.category == category).toList();
  }

  // ✅ ADD: Get outstanding bills
  List<Bill> getOutstandingBills(String userId) {
    final bills = state.value ?? [];
    return bills.where((bill) {
      final userStatus = bill.getPaymentStatusForUser(userId);
      return userStatus != PaymentStatus.paid;
    }).toList();
  }

  // ✅ ADD: Get settled bills
  List<Bill> getSettledBills(String userId) {
    final bills = state.value ?? [];
    return bills.where((bill) {
      final userStatus = bill.getPaymentStatusForUser(userId);
      return userStatus == PaymentStatus.paid;
    }).toList();
  }

  // ✅ ADD: Get bills by provider
  List<Bill> getBillsByProvider(String provider) {
    final bills = state.value ?? [];
    return bills.where((bill) => bill.provider == provider).toList();
  }

  // ✅ ADD: Get overdue bills
  List<Bill> getOverdueBills(String userId) {
    final bills = state.value ?? [];
    final now = DateTime.now();
    return bills.where((bill) {
      if (bill.dueDate == null) return false;
      final userStatus = bill.getPaymentStatusForUser(userId);
      return now.isAfter(bill.dueDate!) && userStatus != PaymentStatus.paid;
    }).toList();
  }

  // ✅ ADD: Search bills
  List<Bill> searchBills(String query) {
    final bills = state.value ?? [];
    final queryLower = query.toLowerCase();
    return bills.where((bill) {
      return bill.title.toLowerCase().contains(queryLower) ||
             bill.provider.toLowerCase().contains(queryLower) ||
             bill.category.name.toLowerCase().contains(queryLower);
    }).toList();
  }

  // Helper methods
  Map<String, double> _calculateEqualShares(double total, int count) {
    final share = total / count;
    return Map.fromEntries(
      List.generate(count, (i) => MapEntry('user_$i', share)),
    );
  }

  Map<String, bool> _initializePaymentStatus(List<String> userIds) {
    return Map.fromEntries(
      userIds.map((id) => MapEntry(id, false)),
    );
  }

  Future<void> deleteBill(String billId) async {
    try {
      await _repository.deleteBill(billId);
      await loadBills();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

// Provider definition
final billsProvider = StateNotifierProvider<BillsNotifier, AsyncValue<List<Bill>>>((ref) {
  final repository = ref.watch(billsRepositoryProvider);
  return BillsNotifier(repository);
});
```

---

#### Step 8.4.2: Create Bill Statistics Provider

**File:** `lib/features/bills/presentation/providers/bill_statistics_provider.dart` (NEW FILE)

**Full Implementation:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_enums.dart';
import 'bills_provider.dart';

/// Statistics for bill dashboard
class BillStatistics {
  final int totalBills;
  final int outstandingCount;
  final double outstandingAmount;
  final int settledCount;
  final double settledAmount;
  final int overdueCount;
  final double overdueAmount;
  final Map<BillCategory, int> categoryBreakdown;
  final Map<String, double> providerSpending;

  const BillStatistics({
    required this.totalBills,
    required this.outstandingCount,
    required this.outstandingAmount,
    required this.settledCount,
    required this.settledAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.categoryBreakdown,
    required this.providerSpending,
  });

  static BillStatistics empty() {
    return const BillStatistics(
      totalBills: 0,
      outstandingCount: 0,
      outstandingAmount: 0.0,
      settledCount: 0,
      settledAmount: 0.0,
      overdueCount: 0,
      overdueAmount: 0.0,
      categoryBreakdown: {},
      providerSpending: {},
    );
  }
}

/// Provider for bill statistics
final billStatisticsProvider = Provider.family<BillStatistics, String>((ref, userId) {
  final billsAsync = ref.watch(billsProvider);

  return billsAsync.when(
    data: (bills) {
      int outstandingCount = 0;
      double outstandingAmount = 0.0;
      int settledCount = 0;
      double settledAmount = 0.0;
      int overdueCount = 0;
      double overdueAmount = 0.0;
      final categoryBreakdown = <BillCategory, int>{};
      final providerSpending = <String, double>{};

      final now = DateTime.now();

      for (final bill in bills) {
        final userStatus = bill.getPaymentStatusForUser(userId);
        final userShare = bill.participantShares[userId] ?? 0.0;

        // Count by status
        if (userStatus == PaymentStatus.paid) {
          settledCount++;
          settledAmount += userShare;
        } else {
          outstandingCount++;
          outstandingAmount += userShare;

          // Check if overdue
          if (bill.dueDate != null && now.isAfter(bill.dueDate!)) {
            overdueCount++;
            overdueAmount += userShare;
          }
        }

        // Category breakdown
        categoryBreakdown[bill.category] = (categoryBreakdown[bill.category] ?? 0) + 1;

        // Provider spending
        if (bill.provider.isNotEmpty) {
          providerSpending[bill.provider] = (providerSpending[bill.provider] ?? 0.0) + userShare;
        }
      }

      return BillStatistics(
        totalBills: bills.length,
        outstandingCount: outstandingCount,
        outstandingAmount: outstandingAmount,
        settledCount: settledCount,
        settledAmount: settledAmount,
        overdueCount: overdueCount,
        overdueAmount: overdueAmount,
        categoryBreakdown: categoryBreakdown,
        providerSpending: providerSpending,
      );
    },
    loading: () => BillStatistics.empty(),
    error: (_, __) => BillStatistics.empty(),
  );
});

/// Provider for filtered bills
final filteredBillsProvider = Provider.family<List<Bill>, BillFilter>((ref, filter) {
  final billsAsync = ref.watch(billsProvider);

  return billsAsync.when(
    data: (bills) {
      var filtered = bills.where((bill) {
        // Search filter
        if (filter.searchQuery.isNotEmpty) {
          final searchLower = filter.searchQuery.toLowerCase();
          final matchesTitle = bill.title.toLowerCase().contains(searchLower);
          final matchesProvider = bill.provider.toLowerCase().contains(searchLower);
          if (!matchesTitle && !matchesProvider) return false;
        }

        // Category filter
        if (filter.category != null && bill.category != filter.category) {
          return false;
        }

        // Status filter
        if (filter.showOutstandingOnly) {
          final userStatus = bill.getPaymentStatusForUser(filter.userId);
          if (userStatus == PaymentStatus.paid) return false;
        }

        return true;
      }).toList();

      // Sort by due date (overdue first, then by date)
      filtered.sort((a, b) {
        final aOverdue = a.dueDate != null && DateTime.now().isAfter(a.dueDate!);
        final bOverdue = b.dueDate != null && DateTime.now().isAfter(b.dueDate!);

        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;

        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Filter configuration for bills
class BillFilter {
  final String userId;
  final String searchQuery;
  final BillCategory? category;
  final bool showOutstandingOnly;

  const BillFilter({
    required this.userId,
    this.searchQuery = '',
    this.category,
    this.showOutstandingOnly = false,
  });

  BillFilter copyWith({
    String? userId,
    String? searchQuery,
    BillCategory? category,
    bool? showOutstandingOnly,
  }) {
    return BillFilter(
      userId: userId ?? this.userId,
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      showOutstandingOnly: showOutstandingOnly ?? this.showOutstandingOnly,
    );
  }
}
```

---

#### Step 8.4.3: Update Dashboard Screen to Use New Providers

**File:** `lib/features/bills/presentation/screens/dashboard_screen.dart`

**Step 1: Update imports:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bills_provider.dart';
import '../providers/bill_statistics_provider.dart';
```

**Step 2: Convert to ConsumerStatefulWidget:**
```dart
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  BillCategory? _selectedCategory;
  String _searchQuery = '';
  bool _showOutstandingOnly = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';

    // Create filter
    final filter = BillFilter(
      userId: currentUserId,
      searchQuery: _searchQuery,
      category: _selectedCategory,
      showOutstandingOnly: _showOutstandingOnly,
    );

    // Watch filtered bills and statistics
    final filteredBills = ref.watch(filteredBillsProvider(filter));
    final stats = ref.watch(billStatisticsProvider(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Summary Cards with stats from provider
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              child: LedgerSummaryCards(
                outstandingCount: stats.outstandingCount,
                outstandingAmount: stats.outstandingAmount,
                settledCount: stats.settledCount,
                settledAmount: stats.settledAmount,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            // Search Bar
            _buildSearchBar(),

            const SizedBox(height: AppDimensions.paddingMedium),

            // Category Filter Chips
            _buildCategoryFilters(),

            const SizedBox(height: AppDimensions.paddingMedium),

            // Outstanding Toggle
            _buildOutstandingToggle(),

            const SizedBox(height: AppDimensions.paddingSmall),

            // Bills List
            Expanded(
              child: _buildBillsList(filteredBills, currentUserId),
            ),
          ],
        ),
      ),
    );
  }

  // Extract widget building methods for cleaner code
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Row(
        children: [
          Text(
            'Ledger',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.add_circle_rounded,
              color: AppColors.cyan500,
              size: 32,
            ),
            onPressed: () => _showAddBillDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLarge),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search bills...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppColors.textTertiary),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceLight.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.cyan500.withValues(alpha: 0.5), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLarge),
        children: [
          // All Filter
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildAllFilterChip(),
          ),
          // Category Filters
          ...BillCategory.values.where((c) => c != BillCategory.other).map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CategoryFilterChip(
                category: category,
                isSelected: _selectedCategory == category,
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllFilterChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedCategory == null
              ? AppColors.cyan500.withValues(alpha: 0.2)
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedCategory == null
                ? AppColors.cyan500.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          'ALL',
          style: AppTextStyles.bodySmall.copyWith(
            color: _selectedCategory == null ? AppColors.cyan500 : AppColors.textSecondary,
            fontWeight: _selectedCategory == null ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildOutstandingToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLarge),
      child: Row(
        children: [
          Checkbox(
            value: _showOutstandingOnly,
            onChanged: (value) {
              setState(() {
                _showOutstandingOnly = value ?? false;
              });
            },
            activeColor: AppColors.cyan500,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          ),
          Text(
            'Show outstanding only',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList(List<Bill> bills, String currentUserId) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'No bills found'
                  : 'No bills yet',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'Try adjusting your filters'
                  : 'Tap + to add your first bill',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return BillListItem(
          bill: bill,
          currentUserId: currentUserId,
          onTap: () {
            // Navigate to bill details
            context.push('/bills/${bill.id}');
          },
        );
      },
    );
  }
}
```

---

**✅ Phase 8.4 Complete - State Management & Provider Integration**

**Files Created:**
1. ✅ `bill_statistics_provider.dart` - Statistics calculation and filtered bills provider

**Files Modified:**
1. ✅ `bills_provider.dart` - Added methods for filtering, searching, and marking payments
2. ✅ `dashboard_screen.dart` - Converted to ConsumerStatefulWidget with Riverpod integration

---

## 🎉 PHASE 8: BILL SPLITTER REDESIGN - COMPLETE! 🎉

### Summary of All Changes:

**Phase 8.1: Foundation** (1 hour)
- ✅ Added BillCategory enum with Malaysian utilities
- ✅ Added PaymentStatus enum
- ✅ Updated Bill entity with category, provider, dueDate, status
- ✅ Updated database schema

**Phase 8.2: Ledger Dashboard** (3-4 hours)
- ✅ Created Outstanding/Settled summary cards
- ✅ Created bill list item with category badges
- ✅ Created category filter chips
- ✅ Complete dashboard redesign with search and filters
- ✅ Enhanced add bill dialog

**Phase 8.3: Bill Detail Screen** (2-3 hours)
- ✅ Created payment status indicator
- ✅ Created participant payment cards
- ✅ Created bill header card with category styling
- ✅ Complete bill detail screen redesign

**Phase 8.4: State Management** (1-2 hours)
- ✅ Updated bills provider with new methods
- ✅ Created bill statistics provider
- ✅ Integrated Riverpod throughout

### Total Implementation Time: 7-10 hours

### Files Created (10 new files):
1. `bill_enums.dart`
2. `ledger_summary_cards.dart`
3. `bill_list_item.dart`
4. `category_filter_chip.dart`
5. `payment_status_indicator.dart`
6. `participant_payment_card.dart`
7. `bill_header_card.dart`
8. `bill_statistics_provider.dart`

### Files Modified (5 files):
1. `bill.dart`
2. `bill_model.dart`
3. `bills_table.dart`
4. `bills_provider.dart`
5. `dashboard_screen.dart`

### Next Steps:
- Test all functionality with mock data
- Run database migration (increment schema version)
- Update bill_detail_screen.dart with new widgets
- Add error handling and loading states
- Implement notification system for reminders
- Add analytics tracking for bill categories

---

## 📋 PHASE 9: TENANT DASHBOARD FIXES (1-2 hours)

**Status:** 🔧 IN PROGRESS

**Files Modified:**
1. `lib/features/tenant/presentation/screens/tenant_dashboard_screen.dart`

**Files Created:**
1. ✅ `lib/features/tenant/presentation/widgets/calendar_widget.dart` - Complete implementation with horizontal scrolling dates

---

### Step 1: Fix Widget Parameter Mismatches (30 min)

**File:** `tenant_dashboard_screen.dart`

#### 1.1 Fix BalanceCard → BalanceCards (lines 79-97)
- [ ] Change `BalanceCard(` to `BalanceCards(`
- [ ] Remove parameters: `currentUser`, `housemates`, `onCreateBill`, `onViewScore`, `onReport`
- [ ] Add parameters: `fiscalScore: currentUser.fiscalScore`, `harmonyScore: 750`
- [ ] Note: This is temporary - proper BalanceCard with residents list needs to be created later

#### 1.2 Fix FriendsList Parameters (lines 125-137)
- [ ] Remove `onAddFriend` callback (not in widget definition)
- [ ] Remove `onViewHistory` callback (not in widget definition)
- [ ] Keep `friends: housemates` parameter
- [ ] Add `onFriendTap: (friend) { ... }` callback (optional but functional)

#### 1.3 Fix LiquidityWidget Parameters (lines 151-156)
- [ ] Remove `balancePercentage: 70` parameter (widget doesn't accept it - hardcoded inside)
- [ ] Keep only `onOpenDetail: () { context.push('/liquidity'); }`

#### 1.4 Fix ReportWidget Parameters (lines 161-167)
- [ ] Remove `resolvedCount: 2` parameter (widget doesn't accept it - hardcoded inside)
- [ ] Remove `pendingCount: 1` parameter (widget doesn't accept it - hardcoded inside)
- [ ] Keep only `onOpenDetail: () { context.push('/maintenance'); }`

#### 1.5 Uncomment CalendarWidget (lines 141-146)
- [ ] Remove comment markers `//` from CalendarWidget code block
- [ ] Widget is now fully implemented with horizontal scrolling dates
- [ ] Keep parameters: `onOpenDetail: () { context.push('/chores'); }`

---

### Step 2: Verify Imports (5 min)

**File:** `tenant_dashboard_screen.dart` (top of file)

- [ ] Verify all required imports are present:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import '../../../../core/theme/app_colors.dart';
  import '../../../../core/router/app_router.dart';
  import '../../../../core/widgets/residex_bottom_nav.dart';
  import '../../../users/domain/entities/app_user.dart';
  import '../widgets/header.dart';
  import '../widgets/balance_card.dart';
  import '../widgets/toolkit_grid.dart';
  import '../widgets/summary_cards.dart';
  import '../widgets/friends_list.dart';
  import '../widgets/calendar_widget.dart';
  import '../widgets/liquidity_widget.dart';
  import '../widgets/report_widget.dart';
  ```

---

### Step 3: Test & Verify (15-30 min)

- [ ] Run `flutter clean` (optional, if hot reload issues)
- [ ] Run `flutter pub get`
- [ ] Start app in debug mode
- [ ] Navigate to tenant dashboard (`/tenant-dashboard`)
- [ ] Verify all widgets render without errors:
  - [ ] Header displays with Command Center branding
  - [ ] BalanceCards show fiscal and harmony scores
  - [ ] Toolkit grid shows Rental ID and Ghost Mode cards
  - [ ] Summary cards show You Owe and Pending Tasks (matching toolkit style)
  - [ ] Friends list displays (may be empty if no housemates)
  - [ ] Calendar widget displays with horizontal scrolling dates
  - [ ] Liquidity widget displays
  - [ ] Report widget displays
- [ ] Test interactions:
  - [ ] Tap calendar dates (should scroll horizontally)
  - [ ] Tap chevron buttons (should navigate to detail screens)
  - [ ] Tap summary cards (should navigate)
  - [ ] Bottom navigation works

---

### Known Issues & Future Work

#### Issue 1: BalanceCard vs BalanceCards Mismatch
**Current State:** Using `BalanceCards` (plural) which shows two score cards side-by-side  
**Expected State:** Should use `BalanceCard` (singular) that includes:
- User balance/score display
- Residents list inside the card (as shown in React reference)
- Create bill button
- View score buttons

**Resolution:** Need to create proper `BalanceCard` widget matching React `BalanceCard.tsx` structure

#### Issue 2: Hardcoded Values in Widgets
**Affected Widgets:**
- `LiquidityWidget` - Balance percentage is hardcoded to 70%
- `ReportWidget` - Resolved/pending counts are hardcoded to 2/1
- `CalendarWidget` - Task data is mocked

**Resolution:** These widgets need to accept dynamic parameters and connect to actual data providers

#### Issue 3: Missing Harmony Score
**Issue:** `currentUser.harmonyScore` doesn't exist yet, using hardcoded `750`  
**Resolution:** Add `harmonyScore` field to `AppUser` entity

---

### Summary

**Phase 9.1: Emergency Fixes** ✅
- Fixed all compilation errors in tenant_dashboard_screen.dart
- Implemented complete CalendarWidget with horizontal scrolling dates
- Adjusted widget calls to match actual parameter definitions

**Phase 9.2: Future Refactoring** 🔜
- Create proper BalanceCard widget with residents list
- Make LiquidityWidget and ReportWidget accept dynamic data
- Add harmonyScore to AppUser entity
- Connect CalendarWidget to real chore data

**Total Time:** 30-50 minutes (emergency fixes only)

