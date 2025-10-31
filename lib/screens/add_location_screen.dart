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
//   Duration _debounceDuration = const Duration(milliseconds: 350);
//   DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
//   double? _anchorWidth;
//   String _latestQuery = '';
//   bool _isLoading = false;
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

//     buildingNameController.text = widget.buildingName;
//     cityController.text = widget.city;
//     pincodeController.text = widget.pincode;
//     stateController.text = widget.state;

//     _searchFocus.addListener(() {
//       if (!_searchFocus.hasFocus) {
//         _removeOverlay();
//       }
//     });
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
//     setState(() => _isLoading = true); // start loader

//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) return;

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission != LocationPermission.whileInUse &&
//             permission != LocationPermission.always) {
//           return;
//         }
//       }

//       Position position =
//           await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

//       await _getAddressFromCoordinates(position.latitude, position.longitude);
//     } catch (e) {
//       // ignore: avoid_print
//       print("Error getting location: $e");
//     } finally {
//       if (mounted) setState(() => _isLoading = false); // stop loader
//     }
//   }

//   Future<void> _getAddressFromCoordinates(double lat, double lng) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
//       if (placemarks.isNotEmpty) {
//         Placemark placemark = placemarks[0];
//         if (!mounted) return;
//         setState(() {
//           buildingNameController.text = placemark.name ?? '';
//           cityController.text = placemark.locality ?? '';
//           stateController.text = placemark.administrativeArea ?? '';
//           pincodeController.text = placemark.postalCode ?? '';
//           completeAddressController.text =
//               "${placemark.name}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
//           latitude = lat;
//           longitude = lng;
//         });
//       }
//     } catch (e) {
//       // ignore: avoid_print
//       print("Error fetching address: $e");
//     }
//   }

//   Future<void> _getPredictions(String input) async {
//     final query = input.trim();
//     if (query.isEmpty) {
//       setState(() => predictions = []);
//       _removeOverlay();
//       return;
//     }

//     try {
//       _latestQuery = query;
//       final result = await _places.findAutocompletePredictions(query, countries: ['IN']);
//       if (result.predictions?.isEmpty ?? true) {
//         setState(() => predictions = []);
//         _removeOverlay();
//         return;
//       } else {
//         if (_latestQuery != query || searchLocationController.text.trim().isEmpty) return;
//         setState(() => predictions = result.predictions!);
//       }
//       if (predictions.isNotEmpty && searchLocationController.text.trim().isNotEmpty) {
//         _showOverlay();
//       }
//     } catch (e) {
//       // ignore: avoid_print
//       print('Error fetching predictions: $e');
//     }
//   }

//   void _showOverlay() {
//     _removeOverlay();
//     final double screenW = MediaQuery.of(context).size.width;
//     final double overlayWidth = (screenW * 0.5).clamp(160.0, screenW).toDouble();
//     overlayEntry = OverlayEntry(
//       builder: (context) => CompositedTransformFollower(
//         link: _searchFieldLink,
//         showWhenUnlinked: false,
//         offset: const Offset(0, 62),
//         child: SizedBox(
//           width: overlayWidth,
//           child: Material(
//             elevation: 6,
//             borderRadius: BorderRadius.circular(12),
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxHeight: 300),
//               child: ListView(
//                 padding: EdgeInsets.zero,
//                 shrinkWrap: true,
//                 children: predictions.map((prediction) {
//                   final text = prediction.fullText ?? '';
//                   return ListTile(
//                     title: Text(text),
//                     onTap: () async {
//                       searchLocationController.text = text;
//                       await _onPredictionSelected(prediction.placeId);
//                       _removeOverlay();
//                     },
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//     Overlay.of(context)?.insert(overlayEntry!);
//   }

//   void _removeOverlay() {
//     overlayEntry?.remove();
//     overlayEntry = null;
//   }

//   Future<void> _onPredictionSelected(String placeId) async {
//     final placeDetails = await _places.fetchPlace(
//       placeId,
//       fields: [PlaceField.Name, PlaceField.AddressComponents, PlaceField.Address, PlaceField.Location],
//     );

//     final comps = placeDetails.place?.addressComponents ?? [];
//     final model = AddressComponentsModel.fromGoogleComponents(comps);

//     final lat = placeDetails.place?.latLng?.lat;
//     final lng = placeDetails.place?.latLng?.lng;

//     if (lat != null && lng != null) {
//       model.latitude = lat;
//       model.longitude = lng;
//     }

//     if (!mounted) return;
//     setState(() {
//       buildingNameController.text = model.buildingOrFlat.isNotEmpty
//           ? model.buildingOrFlat
//           : placeDetails.place?.name ?? '';
//       cityController.text = model.city;
//       stateController.text = model.state;
//       pincodeController.text = model.postalCode;
//       latitude = model.latitude;
//       longitude = model.longitude;
//       completeAddressController.text =
//           placeDetails.place?.address ?? searchLocationController.text;
//     });
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
//         iconTheme: const IconThemeData(
//           color: Colors.white,
//         ),
//         title: Text(
//           translateText('Add location'),
//           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.starColor,
//                 AppColors.getStartedButton,
//               ],
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
//           padding: const EdgeInsets.all(16.0),
//           child: SingleChildScrollView(
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 16),
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
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: const BorderSide(color: AppColors.darkGrey),
//                         ),
//                       ),
//                       onChanged: (val) {
//                         final now = DateTime.now();
//                         if (val.trim().isEmpty) {
//                           setState(() => predictions = []);
//                           _removeOverlay();
//                           return;
//                         }
//                         if (now.difference(_lastType) < _debounceDuration) return;
//                         _lastType = now;
//                         _getPredictions(val.trim());
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 20),

//                   // Use Current Location
//                   ElevatedButton(
//                     onPressed: _isLoading ? null : _getCurrentLocation,
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: AppColors.white,
//                     ),
//                     child: _isLoading
//                         ? const SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: CircularProgressIndicator(
//                               color: Colors.white,
//                               strokeWidth: 2,
//                             ),
//                           )
//                         : Text(translateText('Use Current Location')),
//                   ),

//                   const SizedBox(height: 20),

//                   _buildTextField(
//                     controller: buildingNameController,
//                     label: 'Building Name and Flat No',
//                     hint: 'Enter building name and flat number',
//                     textCapitalization: TextCapitalization.words,
//                   ),
//                   _buildTextField(
//                     controller: cityController,
//                     label: 'City',
//                     hint: 'Enter city',
//                     textCapitalization: TextCapitalization.words,
//                   ),
//                   _buildTextField(
//                     controller: pincodeController,
//                     label: 'Pincode',
//                     hint: 'Enter pincode',
//                     maxLength: 6,
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                     textCapitalization: TextCapitalization.none,
//                   ),
//                   _buildTextField(
//                     controller: stateController,
//                     label: 'State',
//                     hint: 'Enter state',
//                     textCapitalization: TextCapitalization.words,
//                   ),
//                   _buildTextField(
//                     controller: completeAddressController,
//                     label: 'Complete Address',
//                     hint: 'Full address will appear here',
//                     enabled: false,
//                     isRequired: false,
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
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text(translateText('Please fill all required fields'))),
//                         );
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       backgroundColor: AppColors.starColor,
//                       foregroundColor: Colors.white,
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

// ///
// /// Standalone field builder (named params)
// ///
// Widget _buildTextField({
//   required TextEditingController controller,
//   required String label,
//   required String hint,
//   bool enabled = true,
//   bool isRequired = true,
//   int? maxLength,
//   TextInputType keyboardType = TextInputType.text,
//   List<TextInputFormatter>? inputFormatters,
//   TextCapitalization textCapitalization = TextCapitalization.sentences,
// }) {
//   final localizedLabel = translateText(label);
//   final localizedHint = translateText(hint);
//   final sanitizedField = localizedLabel.replaceAll('*', '').replaceAll(':', '').trim();
//   final fieldForMessage = sanitizedField.isEmpty ? localizedLabel : sanitizedField;

//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 10),
//     child: TextFormField(
//       controller: controller,
//       enabled: enabled,
//       maxLength: maxLength,
//       keyboardType: keyboardType,
//       inputFormatters: inputFormatters,
//       textCapitalization: textCapitalization,
//       autovalidateMode: AutovalidateMode.onUserInteraction,
//       cursorColor: Colors.orange,
//       validator: (value) {
//         if (isRequired && (value == null || value.trim().isEmpty)) {
//           return translateText('{field} is required', params: {'field': fieldForMessage});
//         }
//         return null;
//       },
//       decoration: InputDecoration(
//         labelText: localizedLabel,
//         hintText: localizedHint,
//         counterText: '',
//         labelStyle: const TextStyle(color: AppColors.darkGrey),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: const BorderSide(color: AppColors.darkGrey, width: 1),
//         ),
//         errorStyle: const TextStyle(
//           color: AppColors.red,
//         ),
//       ),
//     ),
//   );
// }

// ///
// /// Top-level model so it doesn’t get nested inside the State class
// ///
// class AddressComponentsModel {
//   String fullAddress;
//   String city;
//   String state;
//   String country;
//   String postalCode;
//   String buildingOrFlat;
//   double? latitude;
//   double? longitude;

//   AddressComponentsModel({
//     required this.fullAddress,
//     required this.city,
//     required this.state,
//     required this.country,
//     required this.postalCode,
//     required this.buildingOrFlat,
//     this.latitude,
//     this.longitude,
//   });

//   factory AddressComponentsModel.fromGoogleComponents(List<AddressComponent> comps) {
//     String _extract(String type) => comps
//         .firstWhere(
//           (e) => e.types.contains(type),
//           orElse: () => AddressComponent(name: '', shortName: '', types: []),
//         )
//         .name;

//     return AddressComponentsModel(
//       fullAddress: _extract('formatted_address'),
//       city: _extract('locality'),
//       state: _extract('administrative_area_level_1'),
//       country: _extract('country'),
//       postalCode: _extract('postal_code'),
//       buildingOrFlat: _extract('route'),
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
    required this.buildingName,
    required this.city,
    required this.pincode,
    required this.state,
  }) : super(key: key);

  final String buildingName;
  final String city;
  final String pincode;
  final String state;

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

  // 🔒 Editable state for each field individually
  bool _cityLocked = false;
  bool _stateLocked = false;
  bool _pincodeLocked = false;
  bool _buildingLocked = false;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController buildingNameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController completeAddressController = TextEditingController();
  final TextEditingController searchLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");

    // Pre-fill if returning from previous screen
    buildingNameController.text = widget.buildingName;
    cityController.text = widget.city;
    pincodeController.text = widget.pincode;
    stateController.text = widget.state;

    _updateCompleteAddress();

    // Watch address fields to update complete address dynamically
    buildingNameController.addListener(_updateCompleteAddress);
    cityController.addListener(_updateCompleteAddress);
    pincodeController.addListener(_updateCompleteAddress);
    stateController.addListener(_updateCompleteAddress);

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeOverlay();
    });
  }

  void _updateCompleteAddress() {
    final building = buildingNameController.text.trim();
    final city = cityController.text.trim();
    final state = stateController.text.trim();
    final pin = pincodeController.text.trim();

    String addr = '';
    if (building.isNotEmpty) addr += building;
    if (city.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + city;
    if (state.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + state;
    if (pin.isNotEmpty) addr += (addr.isEmpty ? '' : ', ') + 'Pincode: $pin';

    completeAddressController.text = addr;
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchFocus.dispose();
    buildingNameController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    stateController.dispose();
    completeAddressController.dispose();
    searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
     searchLocationController.clear();
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
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
      setState(() {
        buildingNameController.text = place.name ?? '';
        cityController.text = place.locality ?? '';
        stateController.text = place.administrativeArea ?? '';
        pincodeController.text = place.postalCode ?? '';
        latitude = lat;
        longitude = lng;

        // Lock only the filled fields
        _buildingLocked = buildingNameController.text.isNotEmpty;
        _cityLocked = cityController.text.isNotEmpty;
        _stateLocked = stateController.text.isNotEmpty;
        _pincodeLocked = pincodeController.text.isNotEmpty;
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
      final result =
          await _places.findAutocompletePredictions(query, countries: ['IN']);
      final preds = result.predictions ?? [];
      if (_latestQuery != query || searchLocationController.text.isEmpty) return;

      setState(() => predictions = preds);
      if (preds.isNotEmpty) _showOverlay();
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
    }
  }

  // void _showOverlay() {
  //   _removeOverlay();
  //   overlayEntry = OverlayEntry(
  //     builder: (context) => CompositedTransformFollower(
  //       link: _searchFieldLink,
  //       offset: const Offset(0, 62),
  //       child: Material(
  //         elevation: 6,
  //         borderRadius: BorderRadius.circular(10),
  //         child: ConstrainedBox(
  //           constraints: const BoxConstraints(maxHeight: 250),
  //           child: ListView(
  //             padding: EdgeInsets.zero,
  //             children: predictions.map((p) {
  //               final text = p.fullText ?? '';
  //               return ListTile(
  //                 title: Text(text),
  //                 onTap: () async {
  //                   await _onPredictionSelected(p.placeId);
  //                   searchLocationController.clear(); // ✅ clear after selection
  //                   _removeOverlay();
  //                 },
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  //   Overlay.of(context)?.insert(overlayEntry!);
//   // }
// void _showOverlay() {
//   _removeOverlay();

//   final screenWidth = MediaQuery.of(context).size.width;
//   final overlay = Overlay.of(context);
//   if (overlay == null) return;

//   overlayEntry = OverlayEntry(
//     builder: (context) => Positioned(
//       width: screenWidth * 1, // ✅ half screen width
//       child: CompositedTransformFollower(
//         link: _searchFieldLink,
//         showWhenUnlinked: false,
//         offset: const Offset(0, 60), // small gap under text field
//         child: Material(
//           elevation: 6,
//           borderRadius: BorderRadius.circular(10),
//           clipBehavior: Clip.hardEdge, // ensures rounded corners clip children
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(
//               maxHeight: 250, // ✅ fixed maximum height
//             ),
//             child: ListView.builder(
//               padding: EdgeInsets.zero,
//               shrinkWrap: true,
//               itemCount: predictions.length,
//               itemBuilder: (context, index) {
//                 final p = predictions[index];
//                 return ListTile(
//                   dense: true,
//                   contentPadding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                   title: Text(
//                     p.fullText ?? '',
//                     style: const TextStyle(fontSize: 14),
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
void _showOverlay() {
  _removeOverlay();

  final screenWidth = MediaQuery.of(context).size.width;
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16, // ✅ margin from left edge
      right: 16, // ✅ equal margin from right edge
      child: CompositedTransformFollower(
        link: _searchFieldLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60), // small vertical gap below TextField
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
      final comps = details.place?.addressComponents ?? [];
      final model = AddressComponentsModel.fromGoogleComponents(comps);

      final lat = details.place?.latLng?.lat;
      final lng = details.place?.latLng?.lng;

      if (!mounted) return;
      setState(() {
        // Fill only available data
        buildingNameController.text =
            model.buildingOrFlat.isNotEmpty ? model.buildingOrFlat : '';
        cityController.text = model.city;
        stateController.text = model.state;
        pincodeController.text = model.postalCode;

        latitude = lat;
        longitude = lng;

        // Lock only filled ones
        _buildingLocked = buildingNameController.text.isNotEmpty;
        _cityLocked = cityController.text.isNotEmpty;
        _stateLocked = stateController.text.isNotEmpty;
        _pincodeLocked = pincodeController.text.isNotEmpty;
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

      // ✅ clear (X) icon on the right
      suffixIcon: searchLocationController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              splashRadius: 18,
              onPressed: () {
                FocusScope.of(context).unfocus(); // hide keyboard
                searchLocationController.clear();
                setState(() {
                  predictions.clear(); // clear search results
                });
                _removeOverlay(); // remove dropdown overlay
              },
            )
          : null,
    ),

    onChanged: (val) async {
      setState(() {}); // rebuild to show/hide clear icon dynamically
      if (val.trim().isEmpty) {
        // ✅ if empty, instantly clear predictions & hide overlay
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
                          _buildTextField(
                            controller: buildingNameController,
                            label: 'Building Name and Flat No',
                            hint: 'Enter building name and flat number',
                          ),
                          _buildTextField(
                            controller: cityController,
                            label: 'City',
                            hint: 'Enter city',
                            regex: RegExp(r'^[a-zA-Z\s.-]+$'),
                            enabled: !_cityLocked,
                          ),
                          _buildTextField(
                            controller: pincodeController,
                            label: 'Pincode',
                            hint: 'Enter pincode',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            regex: RegExp(r'^\d{6}$'),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            enabled: !_pincodeLocked,
                          ),
                          _buildTextField(
                            controller: stateController,
                            label: 'State',
                            hint: 'Enter state',
                            regex: RegExp(r'^[a-zA-Z\s.-]+$'),
                            enabled: !_stateLocked,
                          ),
                          _buildTextField(
                            controller: completeAddressController,
                            label: 'Complete Address',
                            hint: 'Full address will appear here',
                            enabled: false,
                            isRequired: false,
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
                          'buildingName': buildingNameController.text,
                          'city': cityController.text,
                          'pincode': pincodeController.text,
                          'state': stateController.text,
                          'latitude': latitude,
                          'longitude': longitude,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(translateText(
                                'Please fill all required fields correctly'))));
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
//         if (isRequired && v.isEmpty) {
//           return translateText('$label is required');
//         }
//         if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
//           return translateText('Invalid $label');
//         }
//         return null;
//       },
//       decoration: InputDecoration(
//         labelText: translateText(label),
//         hintText: translateText(hint),
//         counterText: '',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//     ),
//   );
// }
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  bool enabled = true,
  bool isRequired = true,
  int? maxLength,
  RegExp? regex,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
  TextCapitalization textCapitalization = TextCapitalization.words,
}) {
  // ✅ Normalize label (strip any * to handle consistently)
  final baseLabel = label.replaceAll('*', '').trim();
  final translatedLabel = translateText(baseLabel);
  final translatedHint = translateText(hint.trim());

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      readOnly: !enabled,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        final v = value?.trim() ?? '';

        // ✅ Required validation
        if (isRequired && v.isEmpty) {
          final errorTemplate = translateText('{field} is required');
          return errorTemplate.replaceAll('{field}', translatedLabel);
        }

        // ✅ Regex validation (localized)
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
