// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import '../utils/colors.dart';
// import '../services/language_listener.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';
// import 'package:flutter/services.dart';

// class AddLocationScreen extends StatefulWidget {
//   const AddLocationScreen({
//     Key? key,
//     required this.buildingName,
//     required this.city,
//     required this.pincode,
//     required this.state,
//   }) : super(key: key);

//   final String buildingName;
//   final String city;
//   final String pincode;
//   final String state;

//   @override
//   _AddLocationScreenState createState() => _AddLocationScreenState();
// }

// class _AddLocationScreenState extends State<AddLocationScreen> {
//   double? latitude;
//   double? longitude;

//   late FlutterGooglePlacesSdk _places;
//   List<AutocompletePrediction> predictions = [];
//   OverlayEntry? overlayEntry;
//   final LayerLink _searchFieldLink = LayerLink();
//   final FocusNode _searchFocus = FocusNode();
//   Duration _debounceDuration = const Duration(milliseconds: 150);
//   DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
//   String _latestQuery = '';
//   bool _isLoading = false;

//   // 🔒 Editable state for each field individually
//   bool _cityLocked = false;
//   bool _stateLocked = false;
//   bool _pincodeLocked = false;
//   bool _buildingLocked = false;

//   final _formKey = GlobalKey<FormState>();

//   final TextEditingController buildingNameController = TextEditingController();
//   final TextEditingController cityController = TextEditingController();
//   final TextEditingController pincodeController = TextEditingController();
//   final TextEditingController stateController = TextEditingController();
//   final TextEditingController completeAddressController = TextEditingController();
//   final TextEditingController searchLocationController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");

//     // Pre-fill if returning from previous screen
//     buildingNameController.text = widget.buildingName;
//     cityController.text = widget.city;
//     pincodeController.text = widget.pincode;
//     stateController.text = widget.state;

//     _updateCompleteAddress();

//     // Watch address fields to update complete address dynamically
//     buildingNameController.addListener(_updateCompleteAddress);
//     cityController.addListener(_updateCompleteAddress);
//     pincodeController.addListener(_updateCompleteAddress);
//     stateController.addListener(_updateCompleteAddress);

//     _searchFocus.addListener(() {
//       if (!_searchFocus.hasFocus) _removeOverlay();
//     });
//   }

//   void _updateCompleteAddress() {
//     final building = buildingNameController.text.trim();
//     final city = cityController.text.trim();
//     final state = stateController.text.trim();
//     final pin = pincodeController.text.trim();

//     String addr = '';
//     if (building.isNotEmpty) addr += building;
//     if (city.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + city;
//     if (state.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + state;
//     if (pin.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + 'Pincode: $pin';

//     completeAddressController.text = addr;
//   }

//   @override
//   void dispose() {
//     _removeOverlay();
//     _searchFocus.dispose();
//     buildingNameController.dispose();
//     cityController.dispose();
//     pincodeController.dispose();
//     stateController.dispose();
//     completeAddressController.dispose();
//     searchLocationController.dispose();
//     super.dispose();
//   }

//   Future<void> _getCurrentLocation() async {
//     setState(() => _isLoading = true);
//     searchLocationController.clear();
//     try {
//       final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 translateText(
//                     'Turn on location services to use your current location'),
//               ),
//             ),
//           );
//         }
//         await Geolocator.openLocationSettings();
//         return;
//       }

//       var permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.unableToDetermine) {
//         permission = await Geolocator.requestPermission();
//       }

//       if (permission == LocationPermission.denied) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 translateText(
//                     'Allow location access to autofill your address details'),
//               ),
//             ),
//           );
//         }
//         return;
//       }

//       if (permission == LocationPermission.deniedForever) {
//         if (!mounted) return;
//         final openSettings = await showDialog<bool>(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text(translateText('Allow location access')),
//             content: Text(
//               translateText(
//                   'Enable location permissions in Settings to use your current location.'),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(false),
//                 child: Text(translateText('Cancel')),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: Text(translateText('Open Settings')),
//               ),
//             ],
//           ),
//         );
//         if (openSettings == true) {
//           await Geolocator.openAppSettings();
//         }
//         return;
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       await _getAddressFromCoordinates(pos.latitude, pos.longitude);
//     } catch (e) {
//       debugPrint("Location error: $e");
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _getAddressFromCoordinates(double lat, double lng) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(lat, lng);
//       if (placemarks.isEmpty) return;
//       final place = placemarks.first;
//       final parts = <String?>[
//         place.name,
//         place.subLocality,
//         place.locality,
//         place.administrativeArea,
//         place.country,
//         place.postalCode,
//       ];
//       final formattedAddress = parts
//           .where((value) => value != null && value!.trim().isNotEmpty)
//           .map((value) => value!.trim())
//           .join(', ');

//       _removeOverlay();

//       setState(() {
//         buildingNameController.text = place.name ?? '';
//         cityController.text = place.locality ?? '';
//         stateController.text = place.administrativeArea ?? '';
//         pincodeController.text = place.postalCode ?? '';
//         searchLocationController.text = formattedAddress;
//         completeAddressController.text = formattedAddress;
//         latitude = lat;
//         longitude = lng;

//         _buildingLocked = buildingNameController.text.isNotEmpty;
//         _cityLocked = cityController.text.isNotEmpty;
//         _stateLocked = stateController.text.isNotEmpty;
//         _pincodeLocked = pincodeController.text.isNotEmpty;
//       });

//       _updateCompleteAddress();
//     } catch (e) {
//       debugPrint("Error fetching address: $e");
//     }
//   }

//   Future<void> _getPredictions(String input) async {
//     final query = input.trim();
//     if (query.isEmpty) {
//       setState(() {
//         predictions = [];
//       });
//       _removeOverlay();
//       return;
//     }

//     final now = DateTime.now();
//     if (now.difference(_lastType) < _debounceDuration) return;
//     _lastType = now;

//     try {
//       _latestQuery = query;
//       final result =
//           await _places.findAutocompletePredictions(query, countries: ['IN']);
//       final preds = result.predictions ?? [];
//       if (_latestQuery != query || searchLocationController.text.isEmpty) return;

//       setState(() => predictions = preds);
//       if (preds.isNotEmpty) _showOverlay();
//     } catch (e) {
//       debugPrint("Error fetching predictions: $e");
//     }
//   }

// void _showOverlay() {
//   _removeOverlay();

//   final screenWidth = MediaQuery.of(context).size.width;
//   final overlay = Overlay.of(context);
//   if (overlay == null) return;

//   overlayEntry = OverlayEntry(
//     builder: (context) => Positioned(
//       left: 16, // ✅ margin from left edge
//       right: 16, // ✅ equal margin from right edge
//       child: CompositedTransformFollower(
//         link: _searchFieldLink,
//         showWhenUnlinked: false,
//         offset: const Offset(0, 60), // small vertical gap below TextField
//         child: Material(
//           elevation: 6,
//           borderRadius: BorderRadius.circular(10),
//           clipBehavior: Clip.hardEdge,
//           color: Colors.white,
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxHeight: 250),
//             child: ListView.separated(
//               padding: EdgeInsets.zero,
//               shrinkWrap: true,
//               itemCount: predictions.length,
//               separatorBuilder: (_, __) => const Divider(
//                 height: 1,
//                 color: Color(0xFFE0E0E0),
//               ),
//               itemBuilder: (context, index) {
//                 final p = predictions[index];
//                 return ListTile(
//                   dense: true,
//                   visualDensity: const VisualDensity(vertical: -1),
//                   contentPadding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   title: Text(
//                     p.fullText ?? '',
//                     style: const TextStyle(fontSize: 14, color: Colors.black87),
//                   ),
//                   onTap: () async {
//                     await _onPredictionSelected(p.placeId);
//                     searchLocationController.clear();
//                     _removeOverlay();
//                   },
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     ),
//   );

//   overlay.insert(overlayEntry!);
// }

//   void _removeOverlay() {
//     overlayEntry?.remove();
//     overlayEntry = null;
//   }

//   Future<void> _onPredictionSelected(String placeId) async {
//     try {
//       final details = await _places.fetchPlace(
//         placeId,
//         fields: [
//           PlaceField.Name,
//           PlaceField.Address,
//           PlaceField.AddressComponents,
//           PlaceField.Location,
//         ],
//       );
//       final comps = details.place?.addressComponents ?? [];
//       final model = AddressComponentsModel.fromGoogleComponents(comps);

//       final lat = details.place?.latLng?.lat;
//       final lng = details.place?.latLng?.lng;

//       if (!mounted) return;
//       setState(() {
//         // Fill only available data
//         buildingNameController.text =
//             model.buildingOrFlat.isNotEmpty ? model.buildingOrFlat : '';
//         cityController.text = model.city;
//         stateController.text = model.state;
//         pincodeController.text = model.postalCode;

//         latitude = lat;
//         longitude = lng;

//         // Lock only filled ones
//         _buildingLocked = buildingNameController.text.isNotEmpty;
//         _cityLocked = cityController.text.isNotEmpty;
//         _stateLocked = stateController.text.isNotEmpty;
//         _pincodeLocked = pincodeController.text.isNotEmpty;
//       });
//     } catch (e) {
//       debugPrint("Error fetching place details: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     context.watch<LanguageListener>();

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(color: Colors.white),
//         title: Text(
//           translateText('Add location'),
//           style: const TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [AppColors.starColor, AppColors.getStartedButton],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: GestureDetector(
//         onTap: () {
//           FocusScope.of(context).unfocus();
//           _removeOverlay();
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 10),
//                CompositedTransformTarget(
//   link: _searchFieldLink,
//   child: TextFormField(
//     controller: searchLocationController,
//     focusNode: _searchFocus,
//     decoration: InputDecoration(
//       labelText: translateText('Search Location'),
//       hintText: translateText('Search for a location'),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),

//       // ✅ clear (X) icon on the right
//       suffixIcon: searchLocationController.text.isNotEmpty
//           ? IconButton(
//               icon: const Icon(Icons.close, color: Colors.grey),
//               splashRadius: 18,
//               onPressed: () {
//                 FocusScope.of(context).unfocus(); // hide keyboard
//                 searchLocationController.clear();
//                 setState(() {
//                   predictions.clear(); // clear search results
//                 });
//                 _removeOverlay(); // remove dropdown overlay
//               },
//             )
//           : null,
//     ),

//     onChanged: (val) async {
//       setState(() {}); // rebuild to show/hide clear icon dynamically
//       if (val.trim().isEmpty) {
//         // ✅ if empty, instantly clear predictions & hide overlay
//         _removeOverlay();
//         setState(() => predictions.clear());
//         return;
//       }
//       await _getPredictions(val);
//     },
//   ),
// ),

//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Divider(color: Colors.grey.shade300, thickness: 1),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 12),
//                         child: Text(
//                           translateText('Or'),
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.darkGrey,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Divider(color: Colors.grey.shade300, thickness: 1),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: _isLoading ? null : _getCurrentLocation,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(double.infinity, 48),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: _isLoading
//                         ? const SizedBox(
//                             width: 22,
//                             height: 22,
//                             child: CircularProgressIndicator(
//                                 color: Colors.white, strokeWidth: 2),
//                           )
//                         : Text(translateText('Use Current Location')),
//                   ),
//                   const SizedBox(height: 20),

//                   Card(
//                     elevation: 1,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 8,
//                         horizontal: 12,
//                       ),
//                       child: Column(
//                         children: [
//                           _buildTextField(
//                             controller: buildingNameController,
//                             label: 'Building Name and Flat No',
//                             hint: 'Enter building name and flat number',
//                           ),
//                           _buildTextField(
//                             controller: cityController,
//                             label: 'City',
//                             hint: 'Enter city',
//                             regex: RegExp(r'^[a-zA-Z\s.-]+$'),
//                             enabled: !_cityLocked,
//                           ),
//                           _buildTextField(
//                             controller: pincodeController,
//                             label: 'Pincode',
//                             hint: 'Enter pincode',
//                             keyboardType: TextInputType.number,
//                             maxLength: 6,
//                             regex: RegExp(r'^\d{6}$'),
//                             inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                             enabled: !_pincodeLocked,
//                           ),
//                           _buildTextField(
//                             controller: stateController,
//                             label: 'State',
//                             hint: 'Enter state',
//                             regex: RegExp(r'^[a-zA-Z\s.-]+$'),
//                             enabled: !_stateLocked,
//                           ),
//                           _buildTextField(
//                             controller: completeAddressController,
//                             label: 'Complete Address',
//                             hint: 'Full address will appear here',
//                             enabled: false,
//                             isRequired: false,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       if (_formKey.currentState?.validate() ?? false) {
//                         Navigator.pop(context, {
//                           'buildingName': buildingNameController.text,
//                           'city': cityController.text,
//                           'pincode': pincodeController.text,
//                           'state': stateController.text,
//                           'latitude': latitude,
//                           'longitude': longitude,
//                         });
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                             content: Text(translateText(
//                                 'Please fill all required fields correctly'))));
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(double.infinity, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: Text(translateText('Submit Location')),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
// Widget _buildTextField({
//   required TextEditingController controller,
//   required String label,
//   required String hint,
//   bool enabled = true,
//   bool isRequired = true,
//   int? maxLength,
//   RegExp? regex,
//   TextInputType keyboardType = TextInputType.text,
//   List<TextInputFormatter>? inputFormatters,
//   TextCapitalization textCapitalization = TextCapitalization.words,
// }) {
//   // ✅ Normalize label (strip any * to handle consistently)
//   final baseLabel = label.replaceAll('*', '').trim();
//   final translatedLabel = translateText(baseLabel);
//   final translatedHint = translateText(hint.trim());

//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 8),
//     child: TextFormField(
//       controller: controller,
//       readOnly: !enabled,
//       maxLength: maxLength,
//       keyboardType: keyboardType,
//       inputFormatters: inputFormatters,
//       textCapitalization: textCapitalization,
//       autovalidateMode: AutovalidateMode.onUserInteraction,
//       validator: (value) {
//         final v = value?.trim() ?? '';

//         // ✅ Required validation
//         if (isRequired && v.isEmpty) {
//           final errorTemplate = translateText('{field} is required');
//           return errorTemplate.replaceAll('{field}', translatedLabel);
//         }

//         // ✅ Regex validation (localized)
//         if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
//           final errorTemplate = translateText('Invalid {field}');
//           return errorTemplate.replaceAll('{field}', translatedLabel);
//         }

//         return null;
//       },
//       decoration: InputDecoration(
//         counterText: '',
//         hintText: translatedHint,
//         label: RichText(
//           text: TextSpan(
//             text: translatedLabel,
//             style: const TextStyle(
//               color: AppColors.darkGrey,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//             children: isRequired
//                 ? const [
//                     TextSpan(
//                       text: ' *',
//                       style: TextStyle(
//                         color: Colors.red,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ]
//                 : null,
//           ),
//         ),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: Colors.grey, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.red, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.red, width: 1),
//         ),
//         errorStyle: const TextStyle(color: AppColors.red),
//       ),
//     ),
//   );
// }


// class AddressComponentsModel {
//   String name;
//   String city;
//   String state;
//   String country;
//   String postalCode;
//   String buildingOrFlat;
//   double? latitude;
//   double? longitude;

//   AddressComponentsModel({
//     required this.name,
//     required this.city,
//     required this.state,
//     required this.country,
//     required this.postalCode,
//     required this.buildingOrFlat,
//     this.latitude,
//     this.longitude,
//   });

//   factory AddressComponentsModel.fromGoogleComponents(
//       List<AddressComponent> comps) {
//     String getType(String type) => comps
//         .firstWhere(
//           (e) => e.types.contains(type),
//           orElse: () => AddressComponent(name: '', shortName: '', types: []),
//         )
//         .name;

//     return AddressComponentsModel(
//       name: getType('premise'),
//       buildingOrFlat: getType('street_address').isNotEmpty
//           ? getType('street_address')
//           : getType('route'),
//       city: getType('locality'),
//       state: getType('administrative_area_level_1'),
//       country: getType('country'),
//       postalCode: getType('postal_code'),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import '../utils/colors.dart';
// import '../services/language_listener.dart';
// import 'package:bloc_onboarding/utils/localization_helper.dart';
// import 'package:flutter/services.dart';

// class AddLocationScreen extends StatefulWidget {
//   const AddLocationScreen({
//     Key? key,

//     // Kept old params optional for backward compatibility (no longer used)
//     this.buildingName = '',
//     this.city = '',
//     this.pincode = '',
//     this.state = '',

//     // New (optional) initial values
//     this.initialCompleteAddress,
//     this.initialScoFlatHouse,
//     this.initialStreetSectorArea,
//   }) : super(key: key);

//   // Old (unused now)
//   final String buildingName;
//   final String city;
//   final String pincode;
//   final String state;

//   // New (optional) initial values
//   final String? initialCompleteAddress;
//   final String? initialScoFlatHouse;
//   final String? initialStreetSectorArea;

//   @override
//   _AddLocationScreenState createState() => _AddLocationScreenState();
// }

// class _AddLocationScreenState extends State<AddLocationScreen> {
//   double? latitude;
//   double? longitude;

//   late FlutterGooglePlacesSdk _places;
//   List<AutocompletePrediction> predictions = [];
//   OverlayEntry? overlayEntry;
//   final LayerLink _searchFieldLink = LayerLink();
//   final FocusNode _searchFocus = FocusNode();
//   Duration _debounceDuration = const Duration(milliseconds: 150);
//   DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
//   String _latestQuery = '';
//   bool _isLoading = false;

//   final _formKey = GlobalKey<FormState>();

//   // 🆕 Controllers we keep
//   final TextEditingController completeAddressController = TextEditingController();
//   final TextEditingController scoFlatHouseController = TextEditingController();
//   final TextEditingController streetSectorAreaController = TextEditingController();
//   final TextEditingController searchLocationController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");

//     // Prefill new fields if provided
//     if (widget.initialCompleteAddress?.isNotEmpty == true) {
//       completeAddressController.text = widget.initialCompleteAddress!;
//     }
//     if (widget.initialScoFlatHouse?.isNotEmpty == true) {
//       scoFlatHouseController.text = widget.initialScoFlatHouse!;
//     }
//     if (widget.initialStreetSectorArea?.isNotEmpty == true) {
//       streetSectorAreaController.text = widget.initialStreetSectorArea!;
//     }

//     _searchFocus.addListener(() {
//       if (!_searchFocus.hasFocus) _removeOverlay();
//     });
//   }

//   @override
//   void dispose() {
//     _removeOverlay();
//     _searchFocus.dispose();
//     completeAddressController.dispose();
//     scoFlatHouseController.dispose();
//     streetSectorAreaController.dispose();
//     searchLocationController.dispose();
//     super.dispose();
//   }

//   Future<void> _getCurrentLocation() async {
//     setState(() => _isLoading = true);
//     searchLocationController.clear();
//     try {
//       final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 translateText('Turn on location services to use your current location'),
//               ),
//             ),
//           );
//         }
//         await Geolocator.openLocationSettings();
//         return;
//       }

//       var permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.unableToDetermine) {
//         permission = await Geolocator.requestPermission();
//       }

//       if (permission == LocationPermission.denied) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 translateText('Allow location access to autofill your address details'),
//               ),
//             ),
//           );
//         }
//         return;
//       }

//       if (permission == LocationPermission.deniedForever) {
//         if (!mounted) return;
//         final openSettings = await showDialog<bool>(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text(translateText('Allow location access')),
//             content: Text(
//               translateText('Enable location permissions in Settings to use your current location.'),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(false),
//                 child: Text(translateText('Cancel')),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: Text(translateText('Open Settings')),
//               ),
//             ],
//           ),
//         );
//         if (openSettings == true) {
//           await Geolocator.openAppSettings();
//         }
//         return;
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       await _getAddressFromCoordinates(pos.latitude, pos.longitude);
//     } catch (e) {
//       debugPrint("Location error: $e");
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _getAddressFromCoordinates(double lat, double lng) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(lat, lng);
//       if (placemarks.isEmpty) return;
//       final place = placemarks.first;
//       final parts = <String?>[
//         place.name,
//         place.subLocality,
//         place.locality,
//         place.administrativeArea,
//         place.country,
//         place.postalCode,
//       ];
//       final formattedAddress = parts
//           .where((value) => value != null && value!.trim().isNotEmpty)
//           .map((value) => value!.trim())
//           .join(', ');

//       _removeOverlay();

//       setState(() {
//         // 👉 Fill full address into Complete Address
//         completeAddressController.text = formattedAddress;
//         searchLocationController.text = formattedAddress;

//         latitude = lat;
//         longitude = lng;
//       });
//     } catch (e) {
//       debugPrint("Error fetching address: $e");
//     }
//   }

//   Future<void> _getPredictions(String input) async {
//     final query = input.trim();
//     if (query.isEmpty) {
//       setState(() {
//         predictions = [];
//       });
//       _removeOverlay();
//       return;
//     }

//     final now = DateTime.now();
//     if (now.difference(_lastType) < _debounceDuration) return;
//     _lastType = now;

//     try {
//       _latestQuery = query;
//       final result = await _places.findAutocompletePredictions(
//         query,
//         countries: ['IN'],
//       );
//       final preds = result.predictions ?? [];
//       if (_latestQuery != query || searchLocationController.text.isEmpty) return;

//       setState(() => predictions = preds);
//       if (preds.isNotEmpty) _showOverlay();
//     } catch (e) {
//       debugPrint("Error fetching predictions: $e");
//     }
//   }

//   void _showOverlay() {
//     _removeOverlay();

//     final overlay = Overlay.of(context);
//     if (overlay == null) return;

//     overlayEntry = OverlayEntry(
//       builder: (context) => Positioned(
//         left: 16,
//         right: 16,
//         child: CompositedTransformFollower(
//           link: _searchFieldLink,
//           showWhenUnlinked: false,
//           offset: const Offset(0, 60),
//           child: Material(
//             elevation: 6,
//             borderRadius: BorderRadius.circular(10),
//             clipBehavior: Clip.hardEdge,
//             color: Colors.white,
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxHeight: 250),
//               child: ListView.separated(
//                 padding: EdgeInsets.zero,
//                 shrinkWrap: true,
//                 itemCount: predictions.length,
//                 separatorBuilder: (_, __) => const Divider(
//                   height: 1,
//                   color: Color(0xFFE0E0E0),
//                 ),
//                 itemBuilder: (context, index) {
//                   final p = predictions[index];
//                   return ListTile(
//                     dense: true,
//                     visualDensity: const VisualDensity(vertical: -1),
//                     contentPadding:
//                         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     title: Text(
//                       p.fullText ?? '',
//                       style: const TextStyle(fontSize: 14, color: Colors.black87),
//                     ),
//                     onTap: () async {
//                       await _onPredictionSelected(p.placeId);
//                       searchLocationController.clear();
//                       _removeOverlay();
//                     },
//                   );
//                 },
//               ),
//             ),
//           ),
//         ),
//       ),
//     );

//     overlay.insert(overlayEntry!);
//   }

//   void _removeOverlay() {
//     overlayEntry?.remove();
//     overlayEntry = null;
//   }

//   Future<void> _onPredictionSelected(String placeId) async {
//     try {
//       final details = await _places.fetchPlace(
//         placeId,
//         fields: [
//           PlaceField.Name,
//           PlaceField.Address,
//           PlaceField.AddressComponents,
//           PlaceField.Location,
//         ],
//       );

//       final address = details.place?.address ?? details.place?.name ?? '';
//       final lat = details.place?.latLng?.lat;
//       final lng = details.place?.latLng?.lng;

//       if (!mounted) return;
//       setState(() {
//         // 👉 Push full selected address into Complete Address
//         completeAddressController.text = address.trim();
//         latitude = lat;
//         longitude = lng;
//       });
//     } catch (e) {
//       debugPrint("Error fetching place details: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     context.watch<LanguageListener>();

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(color: Colors.white),
//         title: Text(
//           translateText('Add location'),
//           style: const TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [AppColors.starColor, AppColors.getStartedButton],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: GestureDetector(
//         onTap: () {
//           FocusScope.of(context).unfocus();
//           _removeOverlay();
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 10),
//                   CompositedTransformTarget(
//                     link: _searchFieldLink,
//                     child: TextFormField(
//                       controller: searchLocationController,
//                       focusNode: _searchFocus,
//                       decoration: InputDecoration(
//                         labelText: translateText('Search Location'),
//                         hintText: translateText('Search for a location'),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         suffixIcon: searchLocationController.text.isNotEmpty
//                             ? IconButton(
//                                 icon: const Icon(Icons.close, color: Colors.grey),
//                                 splashRadius: 18,
//                                 onPressed: () {
//                                   FocusScope.of(context).unfocus();
//                                   searchLocationController.clear();
//                                   setState(() {
//                                     predictions.clear();
//                                   });
//                                   _removeOverlay();
//                                 },
//                               )
//                             : null,
//                       ),
//                       onChanged: (val) async {
//                         setState(() {}); // to show/hide clear icon
//                         if (val.trim().isEmpty) {
//                           _removeOverlay();
//                           setState(() => predictions.clear());
//                           return;
//                         }
//                         await _getPredictions(val);
//                       },
//                     ),
//                   ),

//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Divider(color: Colors.grey.shade300, thickness: 1),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 12),
//                         child: Text(
//                           translateText('Or'),
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.darkGrey,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Divider(color: Colors.grey.shade300, thickness: 1),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: _isLoading ? null : _getCurrentLocation,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(double.infinity, 48),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: _isLoading
//                         ? const SizedBox(
//                             width: 22,
//                             height: 22,
//                             child: CircularProgressIndicator(
//                                 color: Colors.white, strokeWidth: 2),
//                           )
//                         : Text(translateText('Use Current Location')),
//                   ),
//                   const SizedBox(height: 20),

//                   Card(
//                     elevation: 1,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 8,
//                         horizontal: 12,
//                       ),
//                       child: Column(
//                         children: [
//                           // Optional fields first
//                           _buildTextField(
//                             controller: scoFlatHouseController,
//                             label: 'SCO No / Flat No / House No',
//                             hint: 'Enter SCO/Flat/House No (optional)',
//                             isRequired: false,
//                             maxLength: 60,
//                           ),
//                           _buildTextField(
//                             controller: streetSectorAreaController,
//                             label: 'Street / Sector / Area',
//                             hint: 'Enter Street/Sector/Area (optional)',
//                             isRequired: false,
//                             maxLength: 120,
//                           ),

//                           // Required: Complete Address
//                           _buildTextField(
//                             controller: completeAddressController,
//                             label: 'Complete Address',
//                             hint: 'Full address will appear here',
//                             isRequired: true,
//                             minLines: 2,
//                             maxLines: 4,
//                             textCapitalization: TextCapitalization.sentences,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       if (_formKey.currentState?.validate() ?? false) {
//                         Navigator.pop(context, {
//                           'completeAddress': completeAddressController.text.trim(),
//                           'scoFlatHouse': scoFlatHouseController.text.trim(),
//                           'streetSectorArea': streetSectorAreaController.text.trim(),
//                           'latitude': latitude,
//                           'longitude': longitude,
//                         });
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text(
//                               translateText('Please fill all required fields correctly'),
//                             ),
//                           ),
//                         );
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(double.infinity, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: Text(translateText('Submit Location')),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Reusable text field with validation & options
// Widget _buildTextField({
//   required TextEditingController controller,
//   required String label,
//   required String hint,
//   bool enabled = true,
//   bool isRequired = true,
//   int? maxLength,
//   int? minLines,
//   int? maxLines,
//   RegExp? regex,
//   TextInputType keyboardType = TextInputType.text,
//   List<TextInputFormatter>? inputFormatters,
//   TextCapitalization textCapitalization = TextCapitalization.words,
// }) {
//   final baseLabel = label.replaceAll('*', '').trim();
//   final translatedLabel = translateText(baseLabel);
//   final translatedHint = translateText(hint.trim());

//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 8),
//     child: TextFormField(
//       controller: controller,
//       readOnly: !enabled,
//       maxLength: maxLength,
//       minLines: minLines,
//       maxLines: maxLines ?? 1,
//       keyboardType: keyboardType,
//       inputFormatters: inputFormatters,
//       textCapitalization: textCapitalization,
//       autovalidateMode: AutovalidateMode.onUserInteraction,
//       validator: (value) {
//         final v = value?.trim() ?? '';

//         if (isRequired && v.isEmpty) {
//           final errorTemplate = translateText('{field} is required');
//           return errorTemplate.replaceAll('{field}', translatedLabel);
//         }

//         if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
//           final errorTemplate = translateText('Invalid {field}');
//           return errorTemplate.replaceAll('{field}', translatedLabel);
//         }

//         return null;
//       },
//       decoration: InputDecoration(
//         counterText: '',
//         hintText: translatedHint,
//         label: RichText(
//           text: TextSpan(
//             text: translatedLabel,
//             style: const TextStyle(
//               color: AppColors.darkGrey,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//             children: isRequired
//                 ? const [
//                     TextSpan(
//                       text: ' *',
//                       style: TextStyle(
//                         color: Colors.red,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ]
//                 : null,
//           ),
//         ),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: Colors.grey, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.red, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.red, width: 1),
//         ),
//         errorStyle: const TextStyle(color: AppColors.red),
//       ),
//     ),
//   );
// }

// // NOTE: Model retained for potential future enrichment/parsing.
// // Not strictly required for the new flow (we rely on full address).
// class AddressComponentsModel {
//   String name;
//   String city;
//   String state;
//   String country;
//   String postalCode;
//   String buildingOrFlat;
//   double? latitude;
//   double? longitude;

//   AddressComponentsModel({
//     required this.name,
//     required this.city,
//     required this.state,
//     required this.country,
//     required this.postalCode,
//     required this.buildingOrFlat,
//     this.latitude,
//     this.longitude,
//   });

//   factory AddressComponentsModel.fromGoogleComponents(
//       List<AddressComponent> comps) {
//     String getType(String type) => comps
//         .firstWhere(
//           (e) => e.types.contains(type),
//           orElse: () => AddressComponent(name: '', shortName: '', types: []),
//         )
//         .name;

//     return AddressComponentsModel(
//       name: getType('premise'),
//       buildingOrFlat: getType('street_address').isNotEmpty
//           ? getType('street_address')
//           : getType('route'),
//       city: getType('locality'),
//       state: getType('administrative_area_level_1'),
//       country: getType('country'),
//       postalCode: getType('postal_code'),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/services.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({
    Key? key,

    // Kept old params optional for backward compatibility (no longer used)
    this.buildingName = '',
    this.city = '',
    this.pincode = '',
    this.state = '',

    // New (optional) initial values
    this.initialCompleteAddress,
    this.initialScoFlatHouse,
    this.initialStreetSectorArea,
  }) : super(key: key);

  // Old (unused now)
  final String buildingName;
  final String city;
  final String pincode;
  final String state;

  // New (optional) initial values
  final String? initialCompleteAddress;
  final String? initialScoFlatHouse;
  final String? initialStreetSectorArea;

  @override
  _AddLocationScreenState createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  double? latitude;
  double? longitude;

  late FlutterGooglePlacesSdk _places;
  List<AutocompletePrediction> predictions = [];
  OverlayEntry? overlayEntry;
  final LayerLink _searchFieldLink = LayerLink();
  final FocusNode _searchFocus = FocusNode();
  Duration _debounceDuration = const Duration(milliseconds: 150);
  DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
  String _latestQuery = '';
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  // Controllers we keep
  final TextEditingController completeAddressController = TextEditingController();
  final TextEditingController scoFlatHouseController = TextEditingController();
  final TextEditingController streetSectorAreaController = TextEditingController();
  final TextEditingController searchLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");

    // Prefill new fields if provided
    if (widget.initialCompleteAddress?.isNotEmpty == true) {
      completeAddressController.text = widget.initialCompleteAddress!;
    }
    if (widget.initialScoFlatHouse?.isNotEmpty == true) {
      scoFlatHouseController.text = widget.initialScoFlatHouse!;
    }
    if (widget.initialStreetSectorArea?.isNotEmpty == true) {
      streetSectorAreaController.text = widget.initialStreetSectorArea!;
    }

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchFocus.dispose();
    completeAddressController.dispose();
    scoFlatHouseController.dispose();
    streetSectorAreaController.dispose();
    searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    // Do not fill search when using current location
    searchLocationController.clear();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                translateText('Turn on location services to use your current location'),
              ),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                translateText('Allow location access to autofill your address details'),
              ),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(translateText('Allow location access')),
            content: Text(
              translateText('Enable location permissions in Settings to use your current location.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(translateText('Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(translateText('Open Settings')),
              ),
            ],
          ),
        );
        if (openSettings == true) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _getAddressFromCoordinates(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final place = placemarks.first;
      final parts = <String?>[
        place.name,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.country,
        place.postalCode,
      ];
      final formattedAddress = parts
          .where((value) => value != null && value!.trim().isNotEmpty)
          .map((value) => value!.trim())
          .join(', ');

      _removeOverlay();

      setState(() {
        // ✅ Only fill Complete Address (NOT the search field)
        completeAddressController.text = formattedAddress;

        // Also make sure predictions are not shown
        predictions.clear();

        latitude = lat;
        longitude = lng;
      });
    } catch (e) {
      debugPrint("Error fetching address: $e");
    }
  }

  Future<void> _getPredictions(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      setState(() {
        predictions = [];
      });
      _removeOverlay();
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastType) < _debounceDuration) return;
    _lastType = now;

    try {
      _latestQuery = query;
      final result = await _places.findAutocompletePredictions(
        query,
        countries: ['IN'],
      );
      final preds = result.predictions ?? [];
      if (_latestQuery != query || searchLocationController.text.isEmpty) return;

      setState(() => predictions = preds);
      if (preds.isNotEmpty) _showOverlay();
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        child: CompositedTransformFollower(
          link: _searchFieldLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.hardEdge,
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: predictions.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Color(0xFFE0E0E0),
                ),
                itemBuilder: (context, index) {
                  final p = predictions[index];
                  return ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    title: Text(
                      p.fullText ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    onTap: () async {
                      await _onPredictionSelected(p.placeId);
                      searchLocationController.clear();
                      _removeOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry!);
  }

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  Future<void> _onPredictionSelected(String placeId) async {
    try {
      final details = await _places.fetchPlace(
        placeId,
        fields: [
          PlaceField.Name,
          PlaceField.Address,
          PlaceField.AddressComponents,
          PlaceField.Location,
        ],
      );

      final address = details.place?.address ?? details.place?.name ?? '';
      final lat = details.place?.latLng?.lat;
      final lng = details.place?.latLng?.lng;

      if (!mounted) return;
      setState(() {
        // Push full selected address into Complete Address
        completeAddressController.text = address.trim();
        latitude = lat;
        longitude = lng;
      });
    } catch (e) {
      debugPrint("Error fetching place details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          translateText('Add location'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeOverlay();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  CompositedTransformTarget(
                    link: _searchFieldLink,
                    child: TextFormField(
                      controller: searchLocationController,
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                        labelText: translateText('Search Location'),
                        hintText: translateText('Search for a location'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: searchLocationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                splashRadius: 18,
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  searchLocationController.clear();
                                  setState(() {
                                    predictions.clear();
                                  });
                                  _removeOverlay();
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) async {
                        setState(() {}); // to show/hide clear icon
                        if (val.trim().isEmpty) {
                          _removeOverlay();
                          setState(() => predictions.clear());
                          return;
                        }
                        await _getPredictions(val);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey.shade300, thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          translateText('Or'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGrey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey.shade300, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(translateText('Use Current Location')),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      child: Column(
                        children: [
                          // Optional fields first
                          _buildTextField(
                            controller: scoFlatHouseController,
                            label: translateText('SCO No / Flat No / House No'),
                            hint: 'Enter SCO/Flat/House No (optional)',
                            isRequired: false,
                            maxLength: 60,
                          ),
                          _buildTextField(
                            controller: streetSectorAreaController,
                            label: 'Street / Sector / Area',
                            hint: 'Enter Street/Sector/Area (optional)',
                            isRequired: false,
                            maxLength: 120,
                          ),

                          // Required: Complete Address
                          _buildTextField(
                            controller: completeAddressController,
                            label: 'Complete Address',
                            hint: 'Full address will appear here',
                            isRequired: true,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.pop(context, {
                          'completeAddress': completeAddressController.text.trim(),
                          'scoFlatHouse': scoFlatHouseController.text.trim(),
                          'streetSectorArea': streetSectorAreaController.text.trim(),
                          'latitude': latitude,
                          'longitude': longitude,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              translateText('Please fill all required fields correctly'),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(translateText('Submit Location')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable text field with validation & options
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  bool enabled = true,
  bool isRequired = true,
  int? maxLength,
  int? minLines,
  int? maxLines,
  RegExp? regex,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
  TextCapitalization textCapitalization = TextCapitalization.words,
}) {
  final baseLabel = label.replaceAll('*', '').trim();
  final translatedLabel = translateText(baseLabel);
  final translatedHint = translateText(hint.trim());

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      readOnly: !enabled,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        final v = value?.trim() ?? '';

        if (isRequired && v.isEmpty) {
          final errorTemplate = translateText('{field} is required');
          return errorTemplate.replaceAll('{field}', translatedLabel);
        }

        if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
          final errorTemplate = translateText('Invalid {field}');
          return errorTemplate.replaceAll('{field}', translatedLabel);
        }

        return null;
      },
      decoration: InputDecoration(
        counterText: '',
        hintText: translatedHint,
        label: RichText(
          text: TextSpan(
            text: translatedLabel,
            style: const TextStyle(
              color: AppColors.darkGrey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            children: isRequired
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        errorStyle: const TextStyle(color: AppColors.red),
      ),
    ),
  );
}

// Optional model retained for future parsing
class AddressComponentsModel {
  String name;
  String city;
  String state;
  String country;
  String postalCode;
  String buildingOrFlat;
  double? latitude;
  double? longitude;

  AddressComponentsModel({
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.buildingOrFlat,
    this.latitude,
    this.longitude,
  });

  factory AddressComponentsModel.fromGoogleComponents(
      List<AddressComponent> comps) {
    String getType(String type) => comps
        .firstWhere(
          (e) => e.types.contains(type),
          orElse: () => AddressComponent(name: '', shortName: '', types: []),
        )
        .name;

    return AddressComponentsModel(
      name: getType('premise'),
      buildingOrFlat: getType('street_address').isNotEmpty
          ? getType('street_address')
          : getType('route'),
      city: getType('locality'),
      state: getType('administrative_area_level_1'),
      country: getType('country'),
      postalCode: getType('postal_code'),
    );
  }
}
