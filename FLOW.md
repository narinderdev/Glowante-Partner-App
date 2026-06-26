# Glowante App Feature Flow

This document is a code-based feature inventory of the current Flutter app in this repository.

Purpose:
- Give salon owners a complete view of what the app currently supports.
- Describe the actual user flows, buttons, actions, and operational modules visible in code.
- Separate Owner flows from Stylist flows.

Notes:
- This is based on the current codebase as of `2026-06-26`.
- Some modules are permission-gated by branch permissions.
- Some flows are role-gated.
- Some secondary screens are reachable from dashboard drawers, profile menus, branch tabs, booking details, or quick actions.

## 1. Global App Behavior

### 1.1 Startup and app shell
- App boot loads `.env`, Firebase, Crashlytics, push notifications, network listener, language listener, auth session manager, token expiration service, and repositories/blocs.
- App launches into `SplashScreen`.
- In debug builds, a Crashlytics debug button exists for manual test logging.

### 1.2 Session handling
- If token exists and is valid, app routes into Owner shell or Stylist shell based on persisted role.
- If token exists but profile is incomplete, app routes to profile completion.
- If token is expired, app force-logs out and returns to login with a session-expired snackbar.
- Logout clears role/session context and returns to login.
- Delete account also exits the app shell and returns to login.

### 1.3 App-wide behaviors
- Push notifications can redirect into bookings.
- Network listener wraps the entire app.
- Language switching is supported using the in-app language listener.
- English and Hindi locales are supported.
- Tapping outside input fields dismisses the keyboard globally.

## 2. Guest / Pre-Login Flow

### 2.1 Splash screen
- Plays animated intro:
  - expanding circle
  - flower animation
  - Glowante logo reveal
- After animation, login state is checked automatically.

### 2.2 Onboarding flow
- Full-screen swipeable onboarding.
- Intro pages use artwork plus marketing copy.
- Controls:
  - page swipe
  - page indicator dots
  - next arrow
  - `Get Started` button on final page
- Completing onboarding routes to login.

### 2.3 Login flow
- Login screen accepts Indian mobile number input.
- Features:
  - restores saved phone number from local storage
  - validates 10-digit phone format
  - blocks invalid number submission
  - stores number before auth request
  - fetches device token for push notifications
- Main button:
  - continue / login request trigger

### 2.4 OTP verification flow
- OTP screen supports:
  - 6-digit OTP entry
  - auto-read via SMS retriever
  - auto-fill
  - auto-submit when all digits are filled
  - resend timer
  - resend OTP
  - invalid OTP error handling
  - clearing and refocusing OTP boxes when verification fails
- On success:
  - token is saved
  - phone and user data are persisted
  - roles, salons, branches, and permissions are persisted
  - profile completion state is derived
  - app continues into role routing

### 2.5 Role routing
- Code supports a role-selection screen with visible roles.
- Roles can route to:
  - Owner shell
  - Stylist shell
- Current login flow auto-continues with the resolved primary role.
- If owner has no salon yet, onboarding continues into salon creation.

### 2.6 Profile completion flow
- Profile completion screen collects:
  - first name
  - last name
  - email
- Validation:
  - required fields
  - minimum name length
  - allowed name characters
  - valid email
- Results:
  - stylist goes directly to stylist shell
  - owner is routed into add salon onboarding flow

## 3. Owner Shell Overview

Owner bottom navigation tabs:
- Home
- Bookings
- Salons
- Catalog
- More

Permission handling:
- Tab access can be restricted by branch permissions.
- Unauthorized access shows a snackbar instead of navigating.

## 4. Owner Home / Dashboard Flow

### 4.1 Dashboard top area
- Dashboard title
- Menu button opens the owner operations drawer
- Notification button
- Branch selector
- Date picker
- Greeting header
- Profile access via header actions

### 4.2 Branch context
- Dashboard loads all accessible salons and branches.
- User can change active branch from selector.
- Selected branch is persisted.
- Branch-specific dashboard data reloads when branch changes.

### 4.3 Date context
- Date picker allows changing the dashboard report day.
- Dashboard reloads for selected date.

### 4.4 Dashboard content blocks
- Revenue overview
- Revenue by source
- Today’s appointments
- Appointment filters
- Appointment details modal
- Staff live status
- Notification/status paging
- Empty states when no salon, no branch, or no appointments exist
- Refresh and retry states

### 4.5 Home screen actions
- `View All` on appointments
- `Book Now`
- Open booking details
- Open live staff status
- Open notifications
- Open more/profile surfaces

### 4.6 Dashboard drawer modules

#### Sales & Reports group
- Revenue & Sales
- Staff Performance
- Operations

#### Individual drawer modules
- AI Insights
- Membership
- Roles
- Vendor
- Clients
- Reviews
- Advertisement
- Attendance
- Leaves
- Holidays Calendar

#### Inventory group
- Store
- Inventory Item
- Purchase Order
- Goods Receipt Note

#### Payroll group
- Payroll
- Commission Setup
- Advance

## 5. Owner Bookings Flow

Owner bookings reuse the bookings module with owner mode enabled.

### 5.1 Main booking tabs
- Team Members
- Schedule
- Recent

### 5.2 Shared booking controls
- Branch selector
- Date strip with weekly navigation
- Pull to refresh
- Empty states
- Booking filters by status/date
- Booking cards
- Booking details screen/modal

### 5.3 Booking lifecycle actions
- Accept booking
- Start job
- Finish job
- No Show
- Confirm certain actions through dialogs
- Enforce appointment-time conditions before start/finish
- OTP entry for job completion where applicable
- Add review/comment after service completion

### 5.4 Customer contact actions
- Call customer
- Open messages / phone app for customer

### 5.5 Staff-facing appointment actions exposed in bookings
- View assigned team member
- View schedule
- View salon hours
- View working hours

### 5.6 Add booking CTA
- `Add Booking`
- `Schedule a Client`
- Disabled when branch/salon conditions do not allow booking

## 6. Owner Add Booking Flow

This is one of the most operationally important flows in the app.

### 6.1 Customer selection
- User must select customer before selecting services.
- Customer area supports:
  - `Select Customer`
  - search existing customer
  - select existing branch customer
  - create new customer
  - clear selected customer using cross icon
- Clearing customer resets UI to the initial empty-customer state.

### 6.2 Customer search modal
- Search field
- Existing customer list
- Tap customer to select
- Close modal
- Add customer action from modal flow

### 6.3 New customer creation
- Required customer fields:
  - first name
  - last name
  - phone
  - optional email
- Customer validation and verification flow exists before save.

### 6.4 Service selection rules
- Services cannot be selected until customer is selected.
- Services are loaded branch-wise.
- Duplicate item protection exists:
  - if same service/cart item is added again, user gets an "already present in your cart" style response instead of quantity increment flow
- `+` and `-` quantity model is intentionally not used for this cart behavior

### 6.5 Customer cart behavior
- Customer cart is branch-specific and user-specific.
- Open cart appears in a centered modal, not as a bottom sheet.
- `Open Cart` button shows current item count.
- Cart loads selected customer cart through branch cart API.
- Cart hides unnecessary totals when there are no items.
- Cart modal shows:
  - service rows
  - duration
  - price
  - service count summary
  - total amount
- Branch timing note is shown in the inline booking summary above the final schedule button, not inside the modal.

### 6.6 Remove service from cart
- Remove service uses cart item id, branch id, and selected customer user id.
- Removal now shows:
  - row-level loader
  - `Deleting...` state
  - spinner in place of the close icon
  - tap lock to prevent double delete

### 6.7 Inline selected services summary
- After service selection, inline summary above `Schedule Appointment` shows:
  - each selected service
  - duration
  - amount
  - remove icon
  - service count
  - total
  - branch timing note

### 6.8 Schedule appointment action
- `Schedule Appointment` button opens the schedule/time step.

## 7. Owner Booking Schedule Flow

### 7.1 Schedule screen
- Month header
- previous week arrow
- next week arrow
- date chips
- selected date state

### 7.2 Team assignment
- Each selected service can be assigned a team member.
- Dropdown per service:
  - select team member
  - show selected team member state
  - show message when no team member exists
- Availability refreshes after team assignment changes.

### 7.3 Slot availability
- Available Slots section
- Empty state when no team member selected
- Empty state when no slots found
- Loading state during availability fetch
- Tap slot to select time

### 7.4 Salon schedule context
- Salon/branch working-hours card shown in schedule step
- Branch/salon closure logic is respected

### 7.5 Confirm schedule step
- Continue to summary
- Back navigation

## 8. Owner Booking Summary / Confirmation Flow

### 8.1 Summary content
- customer info
- service list
- assigned professionals
- selected date
- start and end time
- price total
- duration summary

### 8.2 Final action
- confirm booking
- booking create request
- success return and cleanup
- booked cart items are deleted after success

## 9. Owner Salons Tab Flow

### 9.1 Top-level salon list
- Search salons
- Search branches by salon/branch/address-related text
- Clear search
- Pull to refresh
- Notification button
- Inline loading banner
- Inline error banner
- Empty state
- Retry action

### 9.2 Floating quick actions
- Expand/collapse quick actions
- Team members
- Deals
- Packages

### 9.3 Add main salon
- `Add Salon`
- `Add New Main Salon`
- extra empty-state CTA for first salon creation

### 9.4 Per-salon actions
- Expand/collapse salon branch list
- Edit salon
- Activate salon
- Deactivate salon
- Delete salon
- Add branch

### 9.5 Per-branch actions
- Open branch details
- Edit branch
- Activate branch
- Deactivate branch
- Delete branch

### 9.6 Activation/deactivation logic
- Salon deactivation warns that all branches will deactivate.
- Action loading overlay prevents duplicate salon/branch actions.

## 10. Add / Edit Salon Flow

### 10.1 Main salon form
- Salon Name
- Phone Number
- Start Time
- End Time
- Description
- Salon Images
- Add Location

### 10.2 Buffer configuration
- Booking Buffer Time section
- First Visible Slot
- Last Visible Slot
- Last Slot Overflow Grace

### 10.3 Validation
- required fields
- valid phone number
- max word limits
- start/end time checks
- end time must be greater than start time
- address required
- image limit checks

### 10.4 Service/category setup step
- After base salon details, flow moves into service/specialty selection
- Add Salon Services screen is part of this flow

### 10.5 Save actions
- Add salon
- Edit salon
- Cancel when available
- success snackbar

## 11. Add / Edit Branch Flow

### 11.1 Branch form
- Branch Name
- Phone Number
- Start Time
- End Time
- Description
- Branch Images
- Add Location

### 11.2 Buffer configuration
- Booking Buffer Time section
- First Visible Slot
- Last Visible Slot
- Last Slot Overflow Grace

### 11.3 Validation
- start/end required
- location required
- missing branch id checks in edit flows
- image count restriction

### 11.4 Service/category setup
- Branch creation continues into branch service/specialty selection flow

### 11.5 Save actions
- Add branch
- Edit branch
- success snackbar

## 12. Salon / Branch Service Selection During Onboarding

### 12.1 AddSalonServices flow
- Choose salon specialties
- Select services
- Copy from branch
- Select branch to copy from
- Clear selection
- branch selection dialog
- validation that at least one service is selected

### 12.2 End result
- Branch or salon is created with selected specialties/services

## 13. Branch Detail Flow

Opening a branch from Salons tab routes into `Branch Details`.

### 13.1 Branch hero area
- Branch image
- Branch name
- Branch address

### 13.2 Branch tabs
- Services
- Packages
- Deals
- Team Member
- Reviews
- About

## 14. Catalog Tab Flow

### 14.1 Catalog main controls
- Select Branch
- Search services/categories
- category filter chips
- expand/collapse categories
- expand/collapse subcategories
- refresh from selected salon/branch context

### 14.2 Category-level actions
- Add category
- Edit category
- Delete category

### 14.3 Subcategory-level actions
- Add subcategory
- Edit subcategory
- Delete subcategory

### 14.4 Service-level actions
- Add service
- Edit service
- Delete service

### 14.5 Service information visible in catalog
- name
- price
- duration
- commission tag
- passive wait tag
- active/inactive state

## 15. Add / Edit Service Flow

### 15.1 Service core fields
- Service Name
- Description
- Category/Subcategory
- Price
- Duration

### 15.2 Commission configuration
- Commission on/off
- Commission Type
- Percentage
- Fixed amount
- Max commission amount

### 15.3 Timing behavior configuration
- Passive wait enable
- Passive wait minutes
- Busy start
- Busy end

### 15.4 Validation
- service name required
- initial capital validation
- positive price
- positive duration
- commission constraints
- category/subcategory required

### 15.5 Save actions
- Add Service
- Edit Service

## 16. Owner More Tab

Quick links:
- Team members
- Deals
- Packages
- Gallery

Each item opens the corresponding management module if permissions allow.

## 17. Team Members Management Flow

### 17.1 Team screen main controls
- Select Branch
- Add Member
- Refresh data

### 17.2 Team list content
- team member count
- experience
- rating
- active/inactive tag
- empty state

### 17.3 Team member actions
- View
- Edit
- Delete
- Activate / Deactivate
- Assign

### 17.4 Add/Edit member related flows
- Add team member
- Edit team member
- Choose services for member
- Choose time slots
- Assign user / assigned branches
- View full member details

## 18. Deals Management Flow

There are both owner-level and branch-level deal flows.

### 18.1 Deal list actions
- Select branch
- Add Deal
- Edit
- Delete
- status actions where applicable
- view included services

### 18.2 Add Deal flow
- Deal title
- select services
- gender targeting
- discounted pricing / amount off / percentage off
- max discount checks
- duration / package duration rules
- validations dialog
- create offer success snackbar

## 19. Packages Management Flow

There are both owner-level and branch-level package flows.

### 19.1 Package list actions
- Select branch
- Add Package
- Edit
- Delete
- view included services

### 19.2 Package information
- actual price
- discounted price
- duration
- taxes label
- included services

### 19.3 Add Package flow
- package title
- select services
- pricing
- duration and duration unit
- gender rules
- validations

## 20. Gallery Flow

### 20.1 Gallery list controls
- Select Branch
- Refresh
- Retry / check again states

### 20.2 Gallery actions
- View gallery images
- Tap image for enlarged viewing
- upload/add image flows
- delete/close confirmation flows

## 21. Owner Profile Flow

### 21.1 Profile main actions
- change language
- pull to refresh profile data
- logout
- delete account

### 21.2 Profile menu items
- Account Security
- Bank Details
- Privacy Policy
- Terms & Conditions

### 21.3 Logout flow
- confirmation bottom sheet
- cancel
- confirm logout
- loading spinner while logout request is running

### 21.4 Delete account flow
- confirmation dialog
- cancel
- confirm delete
- loading spinner while request is running

## 22. Account Security

Visible as a profile entry point:
- passwords
- 2FA / security placeholder flow

## 23. Bank Details

Owner profile can open bank details.

Expected banking module actions:
- add bank details
- review payout destination details

## 24. Owner Dashboard Secondary Modules

### 24.1 AI Insights
- AI insight dashboard entry from owner drawer

### 24.2 Membership
- Membership screen entry from owner drawer

### 24.3 Roles & Permissions
- Roles screen entry from owner drawer
- permission-oriented owner management

### 24.4 Clients
- Branch clients screen entry from owner drawer
- view all clients / branch clients management

### 24.5 Reviews
- Owner reviews screen entry from drawer and branch tabs

### 24.6 Advertisement
- Advertisement module entry from drawer

### 24.7 Sales & Reports
- Revenue & Sales
- Staff Performance
- Operations

## 25. Owner Compensation / Payroll Modules

The compensation screen is a major owner operations surface.

### 25.1 Module selector
- Payroll
- Commission Setup
- Advance
- Attendance
- Leaves
- Holidays Calendar
- Leaves & Holidays

### 25.2 Shared branch controls
- Select Branch
- refresh content
- empty state if no branch is selected

### 25.3 Payroll module
- Setup Payroll
- Review Payroll
- Generate Payroll
- Refresh Review
- Cancel Payroll
- payroll rows by employee
- payment details
- transaction/reference id
- paid on date
- notes
- additions
- deductions
- advances

### 25.4 Commission Setup module
- Services tab
- Staff Overrides tab
- Search services
- Select a service
- Configure default commission rule
- Add Override
- Edit override
- Save Changes
- Save Override

### 25.5 Advance module
- Add Advance
- review employee advances
- amount
- remarks

### 25.6 Attendance / Leaves / Holidays
- attendance days
- leave days
- holiday count
- add holiday
- edit holiday
- delete holiday
- select month
- paid leaves per employee

## 26. Owner Operations / Inventory Modules

These modules are opened from the owner dashboard drawer.

### 26.1 Vendor module
- Add Vendor
- Edit Vendor
- View Vendor
- active/inactive status
- fields:
  - vendor name
  - phone
  - email

### 26.2 Store module
- Add Store
- Edit Store
- fields:
  - store name
  - address
  - bin description
  - active toggle

### 26.3 Inventory Item module
- Add Inventory Item
- Edit Inventory Item
- View Inventory Item
- fields:
  - Item ID
  - SKU
  - Item Name
  - Category
  - Unit of Measure
  - Brand
  - Stock Level
  - Reorder Point
  - Reorder Qty
  - Cost Per Unit
  - Min Stock
  - Max Stock
  - Primary Vendor
  - Store
  - Active toggle

### 26.4 Purchase Order module
- Add Purchase Order
- fields:
  - Vendor
  - Delivery Address (Store)
  - Created By
  - Required Delivery Date
  - Department
  - Remarks
  - Item Lines
  - Add Line
  - Remove Line
  - Ordered Qty
  - Unit Price
- Save Purchase Order

### 26.5 Goods Receipt Note module
- Add GRN
- fields:
  - Purchase Order
  - Received By
  - Notes
  - Item Lines
  - Add Line
  - Item
  - Ordered Qty
  - Received Qty
  - Return Qty
  - Return Reason
  - Remove Line
- Save GRN

## 27. Stylist Shell Overview

Stylist bottom navigation tabs:
- Bookings
- Profile

## 28. Stylist Bookings Flow

### 28.1 Main tabs
- Team Members
- Schedule
- Recent

### 28.2 Main controls
- Select Branch
- Weekly date strip
- previous/next week navigation
- schedule refresh
- view schedule
- branch picker

### 28.3 Booking list states
- no bookings today
- no bookings for selected date
- no team members available for selected date
- salon closed on selected date
- branch inactive / salon inactive booking disabled

### 28.4 Booking actions
- Accept
- Start Job
- Finish Job
- No Show
- View Details
- Open appointment detail component

### 28.5 Customer contact
- phone actions from booking cards/details
- messaging actions from booking cards/details

### 28.6 Add booking
- Stylists can open add booking from bookings screen when branch/salon/date rules allow.

### 28.7 In-job actions
- OTP confirmation flow for job completion
- review/rating/comment collection after service
- add services to appointment
- add items used
- scan barcode / QR
- enter item details manually

### 28.8 Schedule support actions
- salon hours modal
- working hours modal

## 29. Stylist Services Flow

Reachable as a stylist module tied to currently selected salon/branch context.

### 29.1 Features
- View services for current branch
- view current salon info
- empty state if no salon selected in bookings
- empty state if no services found
- service active/inactive status
- commission labels
- passive wait labels

## 30. Stylist Inventory Flow

Reachable as a stylist module tied to currently selected salon/branch context.

### 30.1 Features
- View inventory items for current branch
- see item counts
- see stock-related information
- empty state if no branch context exists

## 31. Stylist Profile Flow

### 31.1 Main actions
- change language
- logout
- delete account

### 31.2 Menu items
- Mark Attendance
- Schedule
- Reviews
- About Salon
- Privacy Policy
- Terms & Conditions

## 32. Stylist Attendance Flow

### 32.1 Mark Attendance screen
- Select branch requirement
- Attendance history button
- face setup status
- attendance marked today status
- check-in status
- check-out status

### 32.2 Face setup
- start face setup
- guided multi-pose capture:
  - front
  - left side
  - right side
  - up
  - down
- review captured images
- retake
- store images

### 32.3 Attendance actions
- Check In
- Check Out
- reset face setup
- view stored images
- latest attendance card
- recent attendance list

### 32.4 Attendance validations
- cannot check out before check in
- cannot duplicate today’s check-in/check-out
- must complete face setup first

### 32.5 Attendance history
- monthly attendance history
- present/absent state labels
- monthly summary

## 33. Stylist Schedule Flow

### 33.1 Features
- View current schedule
- empty state when no schedules exist
- day-wise schedule presentation

## 34. Stylist Reviews Flow

### 34.1 Features
- Requires salon selection in bookings context
- View total reviews
- review list by customer/appointment/item
- empty state when no reviews exist

## 35. Stylist About Salon Flow

### 35.1 Features
- Requires salon selection in bookings context
- salon name
- working hours
- phone
- address
- photos

## 36. Notifications

### 36.1 Access points
- notification button in owner shells
- push notification redirects into booking screens

### 36.2 Behavior
- tapping relevant push notifications can force bookings tab selection

## 37. Web Document Screens

Owner and stylist flows both expose in-app web/doc pages for:
- Privacy Policy
- Terms & Conditions

## 38. Important Business Rules Currently in Code

- Owner and stylist shells are separated by role.
- Branch selection is central to most operational modules.
- Permissions can hide or block modules.
- Add booking cart is customer-specific and branch-specific.
- Duplicate cart item additions are intentionally prevented rather than quantity-based.
- Service selection is blocked until a customer is selected.
- Cart delete requests must use cart item id and selected customer user id.
- Booking buffers are configured at salon and branch creation/edit time.
- Push notification routing prioritizes bookings.
- Session expiration auto-logs the user out.

## 39. High-Level Owner Journey Summary

Primary owner journey:
- Launch app
- login with phone + OTP
- complete profile if needed
- create salon if first-time owner
- create branch
- configure services/categories
- manage team/deals/packages/gallery
- use dashboard for reports and operational shortcuts
- schedule and manage bookings
- manage payroll/inventory/vendors/clients/reviews

## 40. High-Level Stylist Journey Summary

Primary stylist journey:
- Launch app
- login with phone + OTP
- complete profile if needed
- land in bookings
- review assigned branch schedule
- accept/start/finish appointments
- contact customers
- mark attendance with face setup
- check salon info, services, reviews, and schedule
