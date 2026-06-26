# Glowante App Detailed Feature Flow

This document explains the live flows in the current Flutter app. It is written for salon owners and internal handoff, so each section describes what the user fills, what they tap, what the app does, and what happens next.

Scope:
- This is based on the current codebase as of `2026-06-26`.
- Only active flows reachable from the app navigation are included.
- Commented-out and dead code paths are not documented.
- Branch-level Deals are included because they are reachable from Branch Details.

## 1. App Startup and Session Flow

### 1.1 App launch
- User opens the app.
- App loads `.env`, Firebase, Crashlytics, push notification setup, network listener, language listener, session manager, token expiration service, repositories, and blocs.
- App opens `SplashScreen`.
- Splash animation plays and then app checks saved login state.

### 1.2 Session result after splash
- If no valid token exists -> app opens login.
- If token exists and profile is complete -> app routes by role.
- If token exists but profile is incomplete -> app opens profile completion.
- If token is expired -> app clears session and returns to login with a session-expired message.
- If the saved role is owner -> app opens owner shell or salon onboarding depending on salon availability.
- If the saved role is stylist -> app opens stylist shell.

### 1.3 Global behavior
- User taps outside a text field -> keyboard closes.
- Network listener wraps the app and can show offline/online state.
- Language listener supports English and Hindi.
- Push notification tap can navigate into bookings.
- Logout or delete account clears session and returns to login.

### 1.4 Language support
- App supports English and Hindi.
- Owner and stylist profile screens expose language change.
- User selects a language.
- App updates the language listener.
- Visible translated strings update through `context.t(...)` and `translateText(...)`.
- Selected language remains active across supported screens.
- Terms, privacy, labels, snackbars, buttons, and validation messages use the translation helper where implemented.

## 2. Guest and Login Flow

### 2.1 Splash screen
- User sees animated intro with expanding circle, flower animation, and Glowante logo reveal.
- When animation completes, app checks login state.
- Next screen is onboarding, login, profile completion, owner shell, or stylist shell based on stored state.

### 2.2 Onboarding
- User swipes through onboarding pages.
- User can tap next arrow to move forward.
- User can use page indicator dots to understand progress.
- On final page, user taps `Get Started`.
- App opens login.

### 2.3 Login screen
- User fills mobile number.
- App expects a 10-digit Indian mobile number.
- User taps `Continue`.
- App validates number.
- If invalid -> app blocks submission and shows validation.
- If valid -> app saves phone number locally, fetches device push token, and sends login request.
- On login request success -> app opens OTP screen.
- On login request failure -> app stays on login and shows the error.

### 2.4 OTP verification
- User fills 6-digit OTP.
- SMS retriever can auto-read and auto-fill OTP.
- When all digits are filled, app can auto-submit.
- User can tap resend after timer allows it.
- On OTP success -> app saves token, phone, user id, roles, salons, branches, permissions, and profile completion flags.
- On OTP failure -> app clears OTP boxes, refocuses input, and shows invalid OTP/error feedback.
- After success -> app continues into role routing.

### 2.5 Role routing
- Current login flow automatically continues with the resolved primary role.
- If owner profile is incomplete -> app opens profile completion.
- If owner has no salon -> app opens add salon onboarding.
- If owner has salon -> app opens owner shell.
- If stylist -> app opens stylist shell.
- Role selection screen exists in code but is not the normal live login step after OTP.

### 2.6 Profile completion / update profile
- Screen title is `Create Profile`.
- User fills `First Name`.
- User fills `Last Name`.
- User fills `Email`.
- User can tap outside fields or scroll to dismiss keyboard.
- User taps save/continue.
- App capitalizes name words before saving.
- App validates first name is required, at least 2 characters, and uses only letters, spaces, hyphens, apostrophes, or periods.
- App validates last name is required, at least 2 characters, and uses only letters, spaces, hyphens, apostrophes, or periods.
- App validates email is required and has valid email format.
- If validation fails -> app shows field-level errors and user stays on profile form.
- If request is running -> app shows loading state and prevents duplicate submit.
- On success -> app saves first name, last name, email, and profile completion flags locally.
- If stylist -> app opens stylist shell on bookings tab.
- If owner -> app opens add salon onboarding with owner profile data and location fields passed into the salon form.
- If API returns validation errors -> app shows `Profile Update Failed` dialog with the returned errors and `OK` button.
- If network/server fails -> app shows a friendly profile service or internet error and keeps user on the form.

## 3. Owner Shell

### 3.1 Bottom navigation
- Tabs are `Home`, `Bookings`, `Salons`, `Catalog`, and `More`.
- User taps a tab.
- App checks branch/module permission.
- If allowed -> app changes tab.
- If blocked -> app shows unauthorized snackbar and stays on the current tab.

### 3.2 Bottom tab behavior
- `Home` -> opens dashboard with branch/date reporting, appointments, staff live status, drawer menu, notifications, and booking shortcut.
- `Bookings` -> opens owner booking module with team members, schedule, recent bookings, booking details, and add booking.
- `Salons` -> opens salon/branch management with add/edit/delete/activate/deactivate actions.
- `Catalog` -> opens category, subcategory, service, and predefined service management for selected branch.
- `More` -> opens quick links for Team members, Deals, Packages, and Gallery.

### 3.3 Owner profile entry
- User taps the profile/avatar area in the owner shell.
- App opens owner profile.

### 3.4 Push notification routing
- User taps a booking-related push notification.
- App switches to bookings context when possible.

### 3.5 Owner menu map
- `Bookings` -> same as Bookings bottom tab; opens booking list/schedule/recent flow and add booking.
- `Sales & Reports > Revenue & Sales` -> opens revenue report for selected branch/date range.
- `Sales & Reports > Staff Performance` -> opens staff performance report.
- `Sales & Reports > Operations` -> opens operations report.
- `Dashboard` -> same as Home bottom tab; shows owner dashboard.
- `AI Insights` -> opens AI insights cards and filters.
- `Salons` -> same as Salons bottom tab; opens salon and branch management.
- `Catalog` -> same as Catalog bottom tab; opens categories, subcategories, services, and predefined services.
- `Team` or `Team members` -> opens team list, add/edit/view/assign team member.
- `Packages` -> opens package list and add/edit/view/delete package.
- `Membership` -> opens membership plans, current subscription, upgrade/payment history.
- `Roles` -> opens roles and permissions.
- `Deals` -> opens deal list and add/edit/view/delete deal.
- `Vendor` -> opens vendor management.
- `Inventory > Store` -> opens store management.
- `Inventory > Inventory Item` -> opens inventory item management.
- `Inventory > Purchase Order` -> opens purchase order management.
- `Inventory > Goods Receipt Note` -> opens GRN management.
- `Gallery` -> opens branch gallery image management.
- `Clients` -> opens branch client list, search, purchases, import/export.
- `Reviews` -> opens owner/branch reviews.
- `Payroll > Payroll` -> opens payroll setup, generation, and review.
- `Payroll > Commission Setup` -> opens service and staff commission rules.
- `Payroll > Advance` -> opens employee advance management.
- `Advertisement` -> opens ad preview and PDF share/download.
- `Attendance` -> opens branch attendance module.
- `Leaves` -> opens leave module.
- `Holidays Calendar` -> opens holiday calendar.
- Menu items can be hidden or blocked by branch permissions.

## 4. Owner Dashboard Flow

### 4.1 Dashboard header
- User sees dashboard title, menu button, notification button, branch selector, date picker, greeting header, and profile access.
- User taps menu -> app opens owner operations drawer.
- User taps notification button -> app opens notification surface.
- User taps branch selector -> app shows accessible branch options.
- User selects branch -> app persists branch context and reloads dashboard data.
- User taps date picker -> app opens date selector.
- User selects date -> app reloads revenue, appointments, and status for that date.

### 4.2 Dashboard cards and actions
- Revenue cards show revenue overview and source breakdown.
- Today appointments area shows appointment cards and filters.
- User taps appointment -> app opens appointment detail.
- User taps `View All` -> app opens full bookings list.
- User taps `Book Now` -> app opens owner add booking flow.
- Staff live status section shows team status.
- Empty/retry states appear if no salon, no branch, no appointments, or API error exists.

## 5. Owner Dashboard Drawer Modules

### 5.1 Drawer behavior
- User taps dashboard menu.
- App opens drawer with groups and individual modules.
- User taps a module.
- App checks permissions where applicable.
- If allowed -> app opens that module.
- If blocked -> app shows snackbar and stays on dashboard.

### 5.2 Sales and reports group
- `Revenue & Sales` -> opens sales report screen.
- `Staff Performance` -> opens staff performance report.
- `Operations` -> opens operations report.

### 5.3 Individual modules
- `AI Insights` -> opens AI insights dashboard.
- `Membership` -> opens membership and subscription management.
- `Roles` -> opens roles and permission management.
- `Vendor` -> opens vendor management.
- `Clients` -> opens branch client management.
- `Reviews` -> opens reviews.
- `Advertisement` -> opens advertisement module.
- `Attendance` -> opens branch attendance module.
- `Leaves` -> opens leave module.
- `Holidays Calendar` -> opens holiday calendar.

### 5.4 Inventory group
- `Store` -> opens store tab in operations.
- `Inventory Item` -> opens inventory item tab.
- `Purchase Order` -> opens purchase order tab.
- `Goods Receipt Note` -> opens GRN tab.

### 5.5 Payroll group
- `Payroll` -> opens payroll module.
- `Commission Setup` -> opens commission setup module.
- `Advance` -> opens advance module.

## 6. Membership Module

### 6.1 Opening membership
- User taps `Membership` from dashboard drawer.
- App loads salon list, selected salon, membership plans, and current subscription.
- If no salon exists -> app shows `No salon found` and tells user to create a salon first.
- If loading fails -> app shows error card with `Try Again`.
- User pulls to refresh -> app reloads membership data.

### 6.2 Salon selector
- If owner has multiple salons, user sees salon selector.
- User taps selector -> app shows salon options with branch count and address.
- User selects salon -> app saves selected salon id and reloads subscription for that salon.

### 6.3 Current membership card
- Card shows salon name, current plan, billing cycle, payment status, membership status, start date, expiry date, and days remaining.
- Usage cards show branches used, staff used, and storage used.
- If usage is over limit -> card turns warning style and tells user backend additions may be rejected.
- If membership has 30 or fewer days remaining -> expiry banner appears.
- If membership has expired -> banner tells user to renew to continue service.

### 6.4 Membership actions
- `Renew Plan` is currently disabled in the action list and shows a disabled message.
- `Upgrade Plan` -> opens available plans only if subscription allows upgrade.
- If upgrade is not allowed -> app shows membership message.
- `Activate Upgrade` appears when there is an upcoming membership.
- `View Available Plans` -> opens available plans dialog.
- `Payment History` -> opens payment history dialog.

### 6.5 Plan list and billing switch
- User sees `Choose Your Membership Plan`.
- User can switch between `Monthly` and `Yearly`.
- Yearly shows `Save 20%`.
- If monthly is blocked in future config -> app shows monthly blocked message.
- Each plan card shows plan name, description, price, branch limit, staff limit, storage limit, and included features.
- Recommended plan shows `Popular`.
- Current active plan button shows `Current Plan`.
- Ineligible plan button shows `Not Eligible`; tapping it shows the disabled reason.
- Eligible plan button shows `Choose {Plan Name}`.

### 6.6 Purchase dialog
- User taps an eligible plan.
- App validates selected salon exists.
- If user tries a lower-tier plan while active membership exists -> app blocks purchase and shows message.
- App opens `Complete Purchase` dialog.
- Dialog shows selected plan, salon, valid-until date, billing duration, start date, and amount payable.
- User toggles Monthly/Yearly -> app recalculates amount and validity.
- User taps `Cancel` -> dialog closes and no payment starts.
- User taps `Pay with Razorpay` -> app opens Razorpay checkout.
- If Razorpay is cancelled -> app shows payment cancelled.
- If Razorpay fails -> app shows payment failed.
- If Razorpay succeeds -> app sends subscription create/update API with payment id, order id, signature, amount, cycle, renew/upgrade flags, and start date.
- On API success -> app shows membership updated successfully and reloads membership.
- On API failure -> app shows API message or unable-to-update message.

### 6.7 Immediate upgrade activation
- If an upcoming membership exists, user taps `Activate Upgrade`.
- App opens confirmation dialog `Replace current plan now?`.
- Dialog explains that remaining days from current plan will be discarded.
- User taps `Cancel` -> no change.
- User taps `Replace Now` -> app calls activate subscription now API.
- On success -> app shows success message and reloads membership.
- If forfeited days are returned -> app includes forfeited days in the success message.
- On failure -> app shows unable-to-activate message.

### 6.8 Payment history
- User taps `Payment History`.
- App opens payment history dialog.
- Dialog lists plan name, billing cycle, amount, payment status, start date, expiry date, membership status, and payment reference.
- If history is empty -> app shows no payment history.
- User taps close icon -> dialog closes.

## 7. Sales Reports, AI Insights, Clients, Roles

### 7.1 Sales reports
- User opens `Revenue & Sales`, `Staff Performance`, or `Operations`.
- User selects branch.
- User selects range such as Today, This Week, This Month, or This Year.
- App loads matching report data.
- User taps `Export` -> app currently shows `Export is coming soon`.
- User taps report drilldown actions such as view all services -> app opens the related detailed report view where wired.

### 7.2 AI Insights
- User opens `AI Insights`.
- User selects branch and reporting range.
- App loads insight cards such as revenue, service, customer, and performance-oriented insights.
- User changes filters/category -> app updates visible insights.
- Retry/empty states appear when data is unavailable.

### 7.3 Clients
- User opens `Clients`.
- User selects branch.
- App loads branch clients with pagination.
- User searches by user name -> app filters visible clients.
- User taps `Export` -> app exports client data to a local file and shows exported file path.
- User taps `Import` where available -> app opens import dialog.
- In import dialog, user can download template, choose file, remove chosen file, and upload.
- Upload success -> app shows clients imported successfully and reloads client list.
- User taps `Purchases` on a client row -> app opens client purchases modal.
- Client purchases modal loads purchases, shows empty/error/loading states, and closes from close button.

### 7.4 Roles and permissions
- User opens `Roles`.
- User selects branch.
- App loads roles and permissions.
- User searches roles -> role table filters.
- User filters by all/system/custom role.
- User taps `Add Role` -> app opens role editor dialog.
- User fills role name and selects permissions in the permission matrix.
- Permission toolbar actions:
  - `Select All` selects all permission ids.
  - `View Only` selects only view permissions.
  - `Clear All` clears selection.
- User taps `Create Role` -> app validates role name and creates role.
- User taps edit icon on a role -> app opens same editor with existing name and permissions.
- User taps `Save Changes` -> app updates role and reloads list.
- User taps view icon -> app opens read-only role details.

## 8. Owner Salons Tab

### 8.1 Salon list
- User opens `Salons`.
- App loads accessible salons and branches.
- User searches by salon name, branch name, or address.
- App filters the list.
- User clears search -> full list returns.
- User pulls to refresh -> app reloads salons.
- Notification button opens notification surface.

### 8.2 Salon row actions
- User expands a salon -> app shows branch list.
- User taps `Edit Salon` -> app opens edit salon form.
- User taps `Activate Salon` -> app activates salon.
- User taps `Deactivate Salon` -> app warns that branches will also deactivate, then applies action after confirmation.
- User taps `Delete Salon` -> app confirms and deletes after confirmation.
- Loading overlay prevents duplicate actions.

### 8.3 Branch row actions
- User taps branch row -> app opens branch details.
- User taps `Edit Branch` -> app opens edit branch form.
- User taps `Activate Branch` or `Deactivate Branch` -> app updates branch status.
- User taps `Delete Branch` -> app confirms and deletes after confirmation.

### 8.4 Floating quick actions
- User taps floating quick action button.
- App expands quick actions.
- `Team Members` opens team module.
- `Deals` opens deals module.
- `Packages` opens packages module.

## 9. Add or Edit Salon

### 9.1 Salon form fields
- User fills `Salon Name`.
- User fills `Phone Number`.
- User selects `Start Time`.
- User selects `End Time`.
- User fills `Description`.
- User taps `Add Location` -> app opens location screen.
- Location result stores full address and coordinates.
- User can add up to 10 salon photos.
- User can remove selected photo from the photo grid.
- User configures booking buffers:
  - Booking buffer/opening buffer.
  - First visible slot.
  - Last visible slot.
  - Last slot overflow grace.

### 9.2 Salon form button behavior
- User taps `Save Changes` in edit mode -> app validates form and updates salon.
- User taps next/continue in add mode -> app validates form and opens weekly schedule setup.
- Validation checks required name, phone, start/end time, end time after start time, description limits, address, coordinates, and image count.
- If validation fails -> app shows field error or snackbar and stays on form.
- If add flow passes validation -> app sends user to weekly schedule screen.

### 9.3 After weekly schedule
- User saves weekly schedule -> app opens service/specialty setup.
- User chooses salon services/specialties.
- User taps final submit such as `Finish & Launch Salon`.
- App creates salon and routes to owner catalog tab.

### 9.4 Add location screen
- User taps `Add Location` from salon, branch, or team member address forms.
- App opens `Add Location`.
- User can search location in `Search your location...`.
- While typing, app fetches Google Places suggestions.
- User selects a suggestion -> app fills complete address and stores latitude/longitude.
- User can tap clear icon in the search field -> app clears search, complete address, predictions, and coordinates.
- User can tap `Use Current Location`.
- App checks location services and permission.
- If location service is off -> app asks user to turn it on and opens location settings.
- If permission is denied -> app asks for permission.
- If permission is permanently denied -> app shows dialog with `Cancel` and `Open Settings`.
- If current location succeeds -> app reverse-geocodes coordinates and fills address.
- User can manually fill `House/Flat No`, `Street/Area`, and required `Complete Address`.
- User taps `Confirm Location`.
- App validates required complete address.
- If coordinates are missing, app tries geocoding the composed address.
- If coordinates still cannot be found -> app asks user to use current location or choose a more specific suggestion.
- On success -> app returns complete address, base address, house/flat, street/area, latitude, and longitude to the calling form.

## 10. Add or Edit Branch

### 10.1 Branch form fields
- User fills `Branch Name`.
- User fills `Phone Number`.
- User selects `Start Time`.
- User selects `End Time`.
- User fills `Description`.
- User taps `Add Location` -> app opens location screen.
- Location result stores full address and coordinates.
- User can add up to 10 branch photos.
- User can remove selected branch photo.
- User configures booking buffers:
  - Booking buffer/opening buffer.
  - First visible slot.
  - Last visible slot.
  - Last slot overflow grace.

### 10.2 Branch form button behavior
- User taps `Save Changes` in edit mode -> app validates and updates branch.
- User taps next/continue in add mode -> app validates and opens weekly schedule setup.
- Missing address or missing edit branch id blocks submission.
- If validation passes -> app moves to weekly schedule then branch service setup.
- Final branch service submit creates branch, saves selected branch context, and routes to owner catalog tab.

## 11. Weekly Schedule Setup

### 11.1 Fields and controls
- Screen shows Monday through Sunday.
- Each day can be marked open or closed.
- User sets open time and close time for each open day.
- User can copy Monday's timing to other days.
- User can adjust buffer values passed from salon/branch flow.

### 11.2 Buttons
- `Back` returns current schedule result to the previous form.
- `Save` or `Save & Continue` validates schedule and returns it to the salon/branch flow.
- If submitting, buttons disable and loader appears.

## 12. Salon or Branch Service Setup

### 12.1 Service selection
- User selects specialties.
- User selects services under those specialties.
- Branch flow can show copy-from-branch when source branches exist.
- User can select branch to copy from.
- User can clear selection.

### 12.2 Final submit
- If no service is selected -> app blocks submit.
- User taps final submit -> app creates salon/branch with selected services.
- On success -> app persists selected salon/branch and routes to catalog.

## 13. Branch Details

### 13.1 Header
- User opens branch details from Salons tab.
- App shows branch image, branch name, and branch address.

### 13.2 Tabs
- `Services` shows branch services.
- `Packages` shows branch packages.
- `Deals` shows branch deals.
- `Team Member` shows team members for branch.
- `Reviews` shows branch reviews.
- `About` shows branch about details.

## 14. Owner Bookings List

### 14.1 Main controls
- User opens Bookings tab.
- App shows branch selector, weekly date strip, and tabs `Team Members`, `Schedule`, and `Recent`.
- User changes branch -> bookings reload for selected branch.
- User changes date -> bookings reload for selected date.
- User uses previous/next week arrows -> date strip moves by week.
- Pull to refresh -> app reloads appointments.

### 14.2 Add booking entry points
- User taps `Add Booking` or `Schedule a Client`.
- App checks branch/salon/date availability.
- If branch is inactive, salon inactive, no team members exist, salon closed, or booking window is over -> app blocks add booking and shows message.
- If allowed -> app opens add booking flow.

### 14.3 Booking card actions
- User taps booking card -> app opens booking details.
- User taps call icon -> app opens phone action.
- User taps message icon -> app opens messaging/phone handler.

## 15. Owner Add Booking

### 15.1 Customer selection
- Screen starts by requiring customer.
- User taps `Select Customer`.
- App opens customer search modal.
- User searches by customer text.
- User taps a customer -> app sets selected customer and returns to booking screen.
- User taps close -> modal closes without selection.
- User taps clear/cross on selected customer -> app clears customer, clears selected services, clears cart mappings, and resets schedule defaults.

### 15.2 Add new customer
- User taps `Add New Customer`.
- App opens add customer dialog.
- User fills first name, last name, phone, and optional email when shown.
- User taps save/continue.
- App validates names and phone.
- App registers customer and opens OTP verification.
- User enters OTP.
- If OTP is valid -> app verifies customer, links customer to branch when needed, fills selected customer fields, and loads customer cart.
- If OTP invalid -> app shows invalid OTP and keeps dialog open.
- User taps cancel/close -> dialog closes.

### 15.3 Service selection
- Services are disabled until customer is selected.
- User taps service picker.
- App opens `Select Services` modal.
- User searches services.
- User expands categories/subcategories.
- User selects one or more services.
- Modal footer shows selected total.
- User taps `Add Services`.
- App syncs selected services to the branch/customer cart.
- If the service already exists in cart -> app blocks duplicate with already-present message.

### 15.4 Cart
- User taps `Open Cart`.
- App opens centered cart dialog.
- Cart loads selected customer cart for selected branch.
- Cart shows service rows, duration, price, service count, and total.
- User taps remove icon on a service row.
- App shows row-level loader, changes row to `Deleting...`, prevents double tap, and removes item using cart item id, branch id, and selected customer user id.
- If cart is empty -> unnecessary totals are hidden.

### 15.5 Inline selected service summary
- After services are selected, screen shows selected services above final schedule button.
- Summary shows service name, duration, amount, remove icon, service count, total, and branch timing note.
- User removes a service from inline summary -> app removes it from selected services/cart.

### 15.6 Move to schedule
- User taps `Schedule Appointment`.
- App checks customer and selected services.
- If missing customer/services -> app blocks and shows message.
- If valid -> app opens schedule step.

## 16. Booking Schedule and Summary

### 16.1 Schedule screen
- User sees month header, previous week arrow, next week arrow, and date chips.
- User taps date chip -> app selects date.
- Each selected service has team member dropdown.
- User selects team member per service.
- If no team member exists for service -> app shows message.
- App refreshes available slots after assignment.
- User taps available slot -> app selects start time.
- User taps continue/confirm time -> app opens summary.
- Back returns to previous booking step.

### 16.2 Summary screen
- User sees customer details, selected services, assigned professionals, selected date, start/end time, total duration, and total price.
- User taps `Confirm Booking`.
- App sends manual booking create request.
- On success -> app clears/deletes booked cart items and returns to bookings.
- On failure -> app shows error and keeps user on summary.

## 17. Booking Details and Job Lifecycle

### 17.1 Open detail
- User taps a booking card or schedule appointment block.
- App opens booking details with customer, service, date/time, staff, price, and status.

### 17.2 Status buttons
- `Accept` or `Confirm` -> app confirms appointment and refreshes data.
- `Start Job` -> app checks appointment time rules, can require OTP, then starts job.
- `Finish Job` -> app checks job state/time rules, can request OTP/review/rating/comment, then completes appointment.
- `No Show` -> app allows only after configured delay from appointment start; otherwise shows message.
- `Refresh` -> app reloads booking detail.

### 17.3 Extra appointment actions
- `Add Services` -> app opens services dialog for the appointment and adds selected service segments locally.
- `Add Items` -> app opens item entry choice dialog.
- Call/message buttons open phone or messaging handler.

### 17.4 Add items used in appointment
- User taps `Add Items`.
- App opens `Add items used` dialog.
- User taps `Scan` -> app opens camera scanner for barcode or QR code.
- Scanner screen has back button and torch toggle.
- When scanner detects a barcode/QR code -> app opens product detail form with scanned code read-only.
- User can tap `Enter Manually` from scanner -> app opens manual item detail form.
- User taps `Enter Details` from the first dialog -> app opens manual item detail form directly.
- Manual/scanned item form fields are `Category`, `Brand`, `Item name`, and `Barcode / QR code`.
- `Item name` is required.
- User taps `Save Item` or `Use This Item`.
- App validates item name, returns the item to booking detail, and shows snackbar that the item was added locally for this booking.
- User taps `Cancel` in the first dialog -> no item is added.

## 18. Catalog

### 18.1 Catalog controls
- User opens Catalog tab.
- User selects branch.
- App loads categories, subcategories, and services for the branch.
- User searches by service/category text -> app filters catalog.
- User taps category header -> expands/collapses category.
- User taps subcategory header -> expands/collapses subcategory.
- User taps add predefined services -> app opens predefined service import modal.

### 18.2 Predefined services
- User taps predefined services icon/button from Catalog.
- App loads current branch services and master service catalog.
- App opens right-side `Add predefined services` panel.
- Panel shows predefined top-level services with image/icon and checkbox.
- Services already present in branch are preselected.
- User taps a row or checkbox -> app selects or unselects that predefined service code.
- User taps close icon -> panel closes without import.
- User taps `Submit`.
- App sends selected service codes and unselected/removed service codes to predefined service import API.
- While importing, close and submit actions are disabled and loader is shown.
- On success -> app shows `Predefined services updated successfully`, clears active category filter, and refreshes catalog.
- On failure -> app shows error toast and keeps panel usable again.

### 18.3 Category actions
- User taps `Add Category`.
- Dialog asks category name.
- User taps `Add Category` -> app validates and creates category.
- User taps edit on category -> same dialog opens with existing name.
- User taps `Update Category` -> app saves changes.
- User taps delete category -> confirmation dialog opens.
- User confirms delete -> app deletes category and refreshes catalog.

### 18.4 Subcategory actions
- User taps `Add Subcategory` under a category.
- Dialog asks subcategory name.
- User taps `Add Subcategory` -> app validates and creates subcategory.
- User taps edit subcategory -> same dialog opens with existing name.
- User taps `Update Subcategory` -> app saves changes.
- User taps delete subcategory -> confirmation dialog opens.
- User confirms delete -> app deletes subcategory and refreshes catalog.

### 18.5 Service actions
- User taps `Add Service`.
- App opens service form.
- User taps edit service -> app opens service form with existing service.
- User taps delete service -> confirmation dialog opens.
- User confirms delete -> app deletes service and refreshes catalog.

## 19. Add or Edit Service

### 19.1 Service fields
- User fills service name.
- User fills description where shown.
- User selects category and subcategory.
- User fills duration in minutes.
- User fills price in rupees.
- User can enable commission.
- User selects commission type, percentage/fixed value, and max commission where supported.
- User can enable passive wait.
- User fills passive wait minutes.
- User can set busy start and busy end timing behavior.

### 19.2 Save behavior
- User taps `Add Service`, `Save`, or `Update Service`.
- App validates service name, initial capital rules, positive price, positive duration, category/subcategory, and commission constraints.
- If validation fails -> app stays on form with errors.
- If save succeeds -> app closes form and refreshes catalog.

## 20. Team Members

### 20.1 Team list
- User opens Team Members from More, quick action, or branch tab.
- User selects branch.
- App loads team list for branch.
- List shows member count, experience, rating, active/inactive status, and empty state.
- User taps refresh -> app reloads team.

### 20.2 Team row actions
- `View` -> opens full member details.
- `Edit` -> opens edit member form.
- `Delete` -> confirms and deletes member.
- `Activate` or `Deactivate` -> changes member status.
- `Assign` -> opens assignment/branch relation flow.

### 20.3 View team member
- User taps `View` on a team member.
- App opens `View Member`.
- Screen shows member initials/photo placeholder, name, primary role, active/inactive badge, rating, and review count.
- Screen shows facts for role, experience, joined date, and assigned branch count.
- Screen shows specializations as chips.
- If no specialization exists -> app shows `No specializations added`.
- Screen shows assigned branches with branch name and salon name.
- Deleted/inactive branch records are filtered from assigned branch display.
- If no branches are assigned -> app shows `No branches assigned`.
- User taps back -> app returns to team list.

### 20.4 Add or edit member form
- In the live app, `Add Member` is the active add stylist/team member flow.
- The older `AddStylistScreen` file exists in code, but no active navigation path opens it from the current owner flow.
- Owner should use `Add Member` to add a stylist.
- User fills first name, last name, phone, email, gender, experience, brief/about, address, joining date, and role/specialty details.
- User taps address field -> app opens location screen.
- User can upload/select photo.
- Phone verification can ask for OTP.
- User taps next/save -> app validates required fields, phone, email, address, and profile data.
- App moves to service selection.

### 20.5 Add stylist/team member phone verification
- User enters stylist/team member phone number.
- User taps verify/check action where shown.
- App checks whether a user already exists and sends OTP.
- If user exists -> app can prefill first name, last name, and email from returned user data.
- If user does not exist -> app keeps form empty and shows no-user message where implemented.
- OTP field is filled/used by the verification response in the team creation flow.
- User must complete phone verification before final validation passes.

### 20.6 Team service selection
- User selects services assigned to the team member.
- User can select categories/services using checkboxes.
- User taps continue -> app opens online availability/time slot setup.
- If no service is selected where required -> app blocks continue.

### 20.7 Team time slots
- User configures day-wise working slots.
- User can use salon hours or custom hours.
- User can add slot, remove slot, and choose start/end time.
- User can toggle days with checkboxes.
- User taps `Save & Continue` -> app moves to online availability.

### 20.8 Team online availability
- App opens `Online Availability` as the final member setup step.
- User chooses whether the team member should be available for online booking.
- User taps `Previous` -> app returns to previous step without final submit.
- User taps `Add` in add-member mode -> app creates team member with profile, schedule, services, and online availability.
- User taps `Save` in edit-member mode -> app updates team member.
- While submitting, app disables buttons and shows loader.
- On success -> app returns to team list and refreshes data.
- On failure -> app shows the API error message.

### 20.9 Assign existing team member to branch
- User taps `Assign` on a team member.
- App opens `Assign User` multi-step flow.
- Step 1 is `Select Branches`.
- App shows member summary and available branches under the selected salon.
- Already assigned branches are not shown as available.
- If no branch is left -> app shows empty state.
- User selects a branch card.
- User taps `Continue`.
- If member does not belong to the salon -> app blocks and shows message to add the member to the salon first.
- If valid -> app opens service assignment step.
- Step 2 is `Choose Services`.
- App loads branch services grouped by category/subcategory.
- User can expand groups and select services.
- User can tap `Select all` or `Clear all`.
- User taps `Continue`.
- If services are selected -> app opens schedule step.
- Step 3 is `Schedule`.
- App loads branch operating schedule.
- User can choose same as branch timings.
- User can add slots, delete slots, mark day off, mark day working, choose start/end time, and copy Monday schedule to all days.
- If Monday has no slots, copy Monday action is blocked with message.
- User taps `Save & Continue`.
- App opens final `Assign User` completion step.
- User selects joining date.
- User chooses whether the user is available for online booking.
- User taps `Submit`.
- App submits selected branch, service ids, schedule assignment, joining date, and online booking flag.
- On success -> app returns to team list and refreshes assignment state.

## 21. Deals

### 21.1 Deal list
- User opens Deals from More, salon quick action, or Branch Details.
- App loads branch deals.
- User selects branch if needed.
- Deal cards show offer name, pricing, discount, status, and included services.
- User taps status action -> app updates offer active/inactive status.
- User taps edit -> app opens deal form with existing data.
- User taps delete -> confirmation dialog opens.
- User confirms delete -> app deletes deal and refreshes list.

### 21.2 View deal
- User views deals from the Deals list or Branch Details deal tab.
- Each deal card acts as the view surface.
- Card shows deal/offer name.
- Card shows current status such as active/inactive.
- Card shows pricing mode and calculated pricing.
- Card shows original price, discounted/final price, discount type, discount value, and max discount where available.
- Card shows included services.
- User taps `Make Live` or `Deactivate` -> app updates deal status and refreshes the card/list.
- While status update is running -> app prevents duplicate status clicks.
- User taps `Edit` -> app opens the edit deal form with existing values.
- User taps `Delete` -> app asks for confirmation.
- User confirms delete -> app deletes deal and removes it from the list.

### 21.3 Add or edit deal
- User taps `Add Deal`.
- User selects services.
- User chooses pricing mode: `Fixed` or `Discount`.
- If `Fixed` -> user enters discounted/final price.
- If `Discount` -> user selects discount type `Flat` or `Percent`.
- For flat discount -> user enters flat amount.
- For percent discount -> user enters percent off and max discount amount.
- App recalculates discounted price.
- User taps `Review Summary`.
- App validates selected services, discounted price, max discount, and discount rules.
- Review summary shows pricing mode, discount type, max discount, discounted price, original price, and selected services.
- User taps final create/update button.
- App creates or updates deal and returns to list.

## 22. Packages

### 22.1 Package list
- User opens Packages from More, salon quick action, or Branch Details.
- App loads branch packages.
- Package cards show actual price, discounted price, duration, taxes label, included services, and status.
- User taps edit -> opens package form.
- User taps delete -> confirmation dialog opens.
- User confirms delete -> app deletes package and refreshes list.
- User taps status action -> app activates/deactivates package.

### 22.2 View package
- User views packages from the Packages list or Branch Details package tab.
- Each package card acts as the view surface.
- Card shows package title/name.
- Card shows active/inactive status.
- Card shows actual price and discounted price.
- Card shows duration and duration unit.
- Card shows taxes label where available.
- Card shows selected/included services.
- User taps `Make Live` or `Deactivate` -> app updates package status and refreshes the card/list.
- User taps `Edit` -> app opens the edit package form with existing values.
- User taps `Delete` -> app asks for confirmation.
- User confirms delete -> app deletes package and removes it from the list.

### 22.3 Add or edit package
- User taps `Add Package`.
- User selects services.
- User fills package pricing using fixed or discount mode.
- User selects gender: male, female, or others.
- User fills duration and duration unit.
- App recalculates discounted price.
- User taps `Review Summary`.
- App validates services, package gender, duration, discount, and price.
- Review summary shows package details and selected services.
- User taps final create/update button.
- App saves package and returns to list.

## 23. Gallery

### 23.1 Gallery list
- User opens Gallery from More.
- User selects branch where needed.
- App loads gallery images.
- User pulls refresh or taps retry/check again -> app reloads gallery.

### 23.2 Gallery image actions
- User taps image -> app opens enlarged view.
- User taps upload/add image action -> app opens upload/add flow.
- User taps delete/close action -> confirmation appears.
- User confirms -> image is removed and gallery refreshes.

## 24. Owner More Tab

### 24.1 Quick links
- User opens More tab.
- App shows `Team members`, `Deals`, `Packages`, and `Gallery`.
- User taps item -> app checks permission.
- If allowed -> app opens module.
- If blocked -> app shows permission snackbar.

## 25. Owner Profile

### 25.1 Profile actions
- User opens Profile.
- User changes language -> app updates language listener and visible text.
- User pulls to refresh -> app reloads profile data.
- User taps `Logout` -> app opens logout bottom sheet.
- User taps cancel -> bottom sheet closes.
- User taps `Yes, log out` -> app calls logout, clears session, and returns to login.
- User taps `Delete Account` -> app opens confirmation dialog.
- User taps cancel -> dialog closes.
- User taps `Yes, delete` -> app calls delete account API, clears session, and returns to login.

### 25.2 Account security
- User taps `Account Security`.
- App opens account security placeholder screen for passwords/2FA/security.

### 25.3 Bank details
- User taps `Bank Details`.
- App opens add bank details screen.
- User fills account holder name, bank name, account number, confirm account number, and IFSC code.
- User taps `Save Bank Details`.
- App validates required fields, matching account numbers, and valid IFSC.
- On success -> app currently saves locally/shows message that API integration is pending.

### 25.4 Web documents
- User taps `Privacy Policy`.
- App opens in-app web document screen titled `Privacy Policy`.
- WebView loads `https://glowante.com/privacy-policy`.
- User taps `Terms & Conditions`.
- App opens in-app web document screen titled `Terms & Conditions`.
- WebView loads `https://glowante.com/terms-of-services`.
- While page is loading -> app shows star-colored progress loader.
- If the page loads successfully -> user reads the document inside the app.
- If WebView fails -> app shows wifi/error icon, failed-to-load message, and `Try again`.
- User taps `Try again` -> app reloads the same URL.
- User taps back -> app returns to profile.

## 26. Compensation and Payroll

### 26.1 Compensation module selector
- User opens Payroll/Commission/Advance/Attendance/Leaves/Holidays from drawer.
- App shows module selector with Payroll, Commission Setup, Advance, Attendance, Leaves, Holidays Calendar, and Leaves & Holidays.
- User selects branch.
- If no branch is selected -> app shows empty state that payroll and commission need a branch.

### 26.2 Payroll dashboard
- Payroll shows payroll runs and setup status.
- User taps `Manage Team Setup` or `Setup Payroll`.
- App opens payroll setup screen.
- If all team members are configured, `Generate Payroll` becomes available.
- User taps a payroll run -> app opens payroll review.

### 26.3 Payroll setup
- Setup screen lists team members.
- User chooses payroll type per employee.
- Payroll types include salary-only, commission-only, and salary + commission options.
- User fills salary where required.
- User fills commission percent where required.
- User selects effective date.
- User taps `Save` on employee card.
- App validates salary/commission and saves setup for that employee.
- User taps `Review` -> app opens payroll setup review.
- User taps `Go to Payroll Dashboard` from review -> app returns to payroll dashboard.

### 26.4 Generate payroll
- User taps `Generate Payroll`.
- Dialog asks month and year.
- User taps cancel -> dialog closes.
- User taps `Generate Payroll` -> app creates payroll run for selected month/year and reloads payroll.

### 26.5 Payroll review
- Review screen shows payroll period, status, totals, employee rows, and search/filter controls.
- User taps `Refresh Review` -> app fetches latest payroll review data.
- User taps `Cancel Payroll` -> confirmation dialog opens.
- User confirms -> app cancels payroll run.
- User searches employee -> list filters.
- User taps `Review` on employee -> app opens employee payroll review.

### 26.6 Employee payroll review
- Employee review shows salary, commission, additions, deductions, advances, payment details, and final payout.
- User selects payment method.
- User fills transaction/reference id, paid on date, notes, additions, deductions, or adjustment details where shown.
- User taps `Save Payment` -> app saves payment info.
- User taps `Save Adjustment` -> app saves addition/deduction.
- User deletes adjustment -> app confirms and removes adjustment.

### 26.7 Commission setup
- User opens Commission Setup.
- Tabs are `Services` and `Staff Overrides`.
- User searches services.
- User selects a service.
- App shows default commission rule for that service.
- User toggles commission enabled/disabled.
- User chooses rule type: percentage or fixed.
- User fills commission value.
- User selects effective date.
- User adds notes.
- User taps `Save Changes` -> app validates commission and saves rule.
- User taps `Add Override` -> app opens staff override dialog.
- User selects one or more staff members, rule type, value, effective date, and notes.
- User taps save -> app saves staff overrides.
- User can delete override from override list.

### 26.8 Advance
- User opens Advance.
- User taps `Add Advance`.
- User selects employee, fills amount, date, and remarks where shown.
- User taps save -> app stores employee advance.
- Advance list shows employee advances for review.

### 26.9 Attendance, leaves, holidays
- Attendance module shows attendance days and employee attendance summaries.
- Leaves module shows leave days and paid leaves per employee.
- Holidays module shows holiday count and holiday list.
- User selects month -> app reloads month data.
- User taps `Add Holiday` -> fills holiday date/name/details and saves.
- User taps edit holiday -> updates holiday.
- User taps delete holiday -> app confirms and deletes.

## 27. Inventory and Supply Operations

### 27.1 Operations shell
- User opens Vendor, Store, Inventory Item, Purchase Order, or GRN from drawer.
- App opens operations screen on the requested section.
- User selects branch.
- Lists show cards with view/edit/delete actions where supported.
- Retry buttons reload data after errors.

### 27.2 Vendor
- User taps `Add Vendor`.
- User fills vendor name, phone, email, and active status.
- User taps `Save Vendor`.
- App validates vendor name and saves vendor.
- User taps `View` -> app opens vendor detail.
- User taps `Edit` -> form opens with existing data.
- User taps `Update Vendor` -> app saves changes.
- User taps `Delete` -> app confirms and deletes vendor.

### 27.3 Store
- User taps `Add Store`.
- User fills store name, address, bin description, and active toggle.
- User taps `Save Store`.
- App validates store name and address and saves store.
- User taps view/edit/delete from card.
- Edit uses same form and `Update Store`.

### 27.4 Inventory item
- User taps `Add Inventory Item`.
- User fills item id, SKU, item name, category, unit of measure, brand, stock level, reorder point, reorder quantity, cost per unit, min stock, max stock, primary vendor, store, and active toggle.
- If no vendor exists -> app tells user to add vendor first for vendor selection.
- User taps `Save Inventory Item`.
- App validates required fields and saves item.
- User taps `View` -> app opens item detail.
- User taps `Edit` -> app opens item form.
- User taps `Update Inventory Item` -> app saves changes.
- User taps `Delete` -> app confirms and deletes item.

### 27.5 Purchase order
- User taps `Add Purchase Order`.
- User selects vendor.
- User selects delivery address/store.
- User fills created by, required delivery date, department, and remarks.
- User adds item lines.
- For each line, user selects item, fills ordered quantity, unit price, and remarks.
- User taps `Add Line` -> app adds another item row.
- User taps remove line -> app removes that line.
- User taps `Save Purchase Order`.
- App validates vendor and delivery store, then creates purchase order.

### 27.6 Goods receipt note
- User taps `Add GRN`.
- User selects purchase order.
- App can load purchase order details and prefill item lines.
- User fills received by and notes.
- User adds or edits item lines.
- For each line, user fills item, ordered quantity, received quantity, return quantity, and return reason.
- User taps `Add Line` -> app adds row.
- User taps remove line -> app removes row.
- User taps `Save GRN`.
- App creates goods receipt note.

## 28. Reviews and Advertisement

### 28.1 Reviews
- User opens Reviews from drawer or branch details.
- User selects branch/salon context where required.
- App loads review list and summary.
- Empty state appears if no reviews exist.

### 28.2 Advertisement
- User opens Advertisement from drawer.
- App loads branch options and restores selected branch where available.
- If multiple branches exist, user can switch branch from the selector.
- App shows a square advertisement preview card.
- Preview includes beauty salon marketing copy, service lines, sample imagery, phone/address text, and `BOOK NOW` design.
- User taps `SHARE`.
- App captures the ad preview as an image, builds a PDF, and opens platform share for `beauty_salon_ad.pdf`.
- User taps `DOWNLOAD PDF`.
- App captures the ad preview, builds a PDF, and opens the platform print/download PDF flow.
- While exporting, share/download buttons show a loader and are disabled.
- If PDF creation/share/download fails -> app shows a failure snackbar.

## 29. Stylist Shell

### 29.1 Bottom navigation
- Stylist shell has `Bookings` and `Profile`.
- Stylist lands in bookings after login.

## 30. Stylist Bookings

### 30.1 Main controls
- Stylist opens bookings.
- App shows branch selector, weekly date strip, previous/next week controls, and tabs `Team Members`, `Schedule`, and `Recent`.
- Stylist selects branch/date -> app reloads assigned appointments.
- Schedule can show no bookings today, no bookings for selected date, no team members, closed salon, inactive branch, or inactive salon messages.

### 30.2 Booking actions
- Stylist taps booking -> app opens booking detail.
- `Accept` confirms booking.
- `Start Job` starts job when time condition allows.
- `Finish Job` completes job, can require OTP/review/rating/comment.
- `No Show` marks no show when allowed.
- Call/message buttons open phone or messaging handler.
- `Add Services` opens service selection for appointment.
- `Add Items` opens the scan/manual item-used flow and stores the item locally on the booking detail.

### 30.3 Add booking
- Stylist can open add booking when branch/salon/date rules allow.
- If branch is closed or inactive -> add booking is blocked.

## 31. Stylist Services and Inventory

### 31.1 Services
- Stylist opens Services module from current branch context.
- App uses selected salon/branch from bookings context.
- If no branch selected -> app shows empty state.
- App shows branch services with active/inactive status, commission labels, and passive wait labels.

### 31.2 Inventory
- Stylist opens Inventory module from current branch context.
- If no branch selected -> app skips API and shows empty state.
- App loads inventory items for branch.
- Screen shows item count, stock information, and empty/error states.

## 32. Stylist Profile

### 32.1 Profile actions
- Stylist opens Profile.
- User can change language.
- User taps logout -> confirmation opens.
- Confirm logout -> app clears session and returns to login.
- User taps delete account -> confirmation opens.
- Confirm delete -> app deletes account and returns to login.

### 32.2 Profile menu
- `Mark Attendance` -> opens attendance flow.
- `Schedule` -> opens read-only schedule screen.
- `Reviews` -> opens stylist reviews.
- `About Salon` -> opens salon/branch about screen.
- `Privacy Policy` and `Terms & Conditions` -> open web document screens.

## 33. Stylist Attendance

### 33.1 Mark attendance screen
- User selects branch.
- App shows face setup status, attendance marked today status, check-in status, check-out status, latest attendance card, and recent attendance list.
- `Attendance History` opens monthly history screen.

### 33.2 Face setup
- If face setup is incomplete, user taps start face setup.
- Camera screen captures five poses: front, left side, right side, up, and down.
- App validates face and pose.
- After all poses are captured, user sees review captured images.
- User taps `Retake` -> app clears sequence and restarts capture.
- User taps store/continue -> app stores enrollment images and returns to attendance screen.

### 33.3 Check in and check out
- User taps `Check In`.
- App opens live face scan.
- App validates face against enrolled user.
- If valid -> app records check-in.
- User taps `Check Out`.
- App opens live face scan and records check-out after validation.
- App blocks check-out before check-in.
- App blocks duplicate check-in/check-out for the same day.
- User taps `Reset Face Setup` -> confirmation opens.
- Confirm reset -> app clears stored face setup.
- User taps `Your Stored Images` -> app opens stored enrollment image viewer.

### 33.4 Attendance history
- User opens history.
- App loads monthly attendance history.
- User changes month -> app reloads month.
- Pull to refresh -> app reloads history.
- Screen shows present/absent labels and monthly summary.

## 34. Stylist Support Screens

### 34.1 Schedule
- User opens Schedule.
- App loads schedules from saved stylist branch context.
- Pull to refresh reloads schedules.
- Empty state appears when no schedules are found.

### 34.2 Reviews
- User opens Reviews.
- App requires salon/branch context from bookings.
- App loads total reviews and review list by customer/appointment/item.
- Pull to refresh reloads reviews.
- Empty state appears when no reviews exist.

### 34.3 About salon
- User opens About Salon.
- App loads selected salon/branch details.
- Screen shows salon/branch name, working hours, phone, address, and photos.

## 35. Notifications and Documents

### 35.1 Notifications
- Owner notification button opens `Notifications`.
- App loads locally stored notifications.
- If loading -> app shows loader.
- If no notifications exist -> app shows `No notifications yet`.
- If notifications exist -> app shows notification cards with title, body, and received time.
- User pulls to refresh -> app reloads notification store.
- User taps `Clear` -> app clears stored notifications and empties the list.
- Push notifications can route to bookings.
- Booking notification tap prioritizes bookings tab/context.

### 35.2 Web document screens
- Owner and stylist can open Privacy Policy.
- Owner and stylist can open Terms & Conditions.
- Owner profile opens `Privacy Policy` and `Terms & Conditions` using the owner web document screen.
- Stylist profile opens `Privacy Policy` and `Terms & Conditions` using the stylist web document screen.
- Privacy Policy URL is `https://glowante.com/privacy-policy`.
- Terms & Conditions URL is `https://glowante.com/terms-of-services`.
- Documents open inside an in-app WebView.
- While loading -> app shows progress loader.
- If loading fails -> app shows error text and `Try again`.
- User taps `Try again` -> app reloads the current document URL.
- User taps back -> app returns to the profile/menu screen that opened the document.

## 36. Important Business Rules

- Owner and stylist shells are separated by role.
- Branch selection is central for dashboard, bookings, catalog, team, payroll, inventory, clients, reports, and stylist context.
- Permissions can hide/block owner modules.
- Add booking requires customer before services.
- Add booking cart is customer-specific and branch-specific.
- Duplicate cart item additions are blocked instead of increasing quantity.
- Cart delete must use cart item id, branch id, and selected customer user id.
- Salon and branch creation both go through base details, weekly schedule, then service setup.
- Booking buffers are configured during salon/branch add/edit.
- Start job, finish job, and no-show are time/state gated.
- Membership purchase uses Razorpay and reloads subscription after success.
- Session expiration logs out automatically.

## 37. High-Level Owner Journey

- Owner launches app.
- Owner logs in with phone and OTP.
- Owner completes profile if required.
- Owner creates salon if first-time.
- Owner configures salon/branch schedule and services.
- Owner manages bookings, catalog, team, deals, packages, gallery, clients, reviews, membership, reports, payroll, inventory, vendors, stores, purchase orders, and GRNs.

## 38. High-Level Stylist Journey

- Stylist launches app.
- Stylist logs in with phone and OTP.
- Stylist lands in bookings.
- Stylist selects branch/date and manages assigned appointments.
- Stylist accepts, starts, finishes, or marks no-show where allowed.
- Stylist marks attendance with face setup and check-in/check-out.
- Stylist views schedule, services, inventory, reviews, and about salon.
