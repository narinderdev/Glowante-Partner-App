import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;

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
  double? latitude;  // Declare latitude
  double? longitude; // Declare longitude

  late FlutterGooglePlacesSdk _places;
  List<AutocompletePrediction> predictions = [];
  OverlayEntry? overlayEntry;
  final LayerLink _searchFieldLink = LayerLink();
  final FocusNode _searchFocus = FocusNode();
  Duration _debounceDuration = const Duration(milliseconds: 350);
  DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
  double? _anchorWidth; // width of search field to size overlay
  String _latestQuery = '';

  final TextEditingController buildingNameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController completeAddressController = TextEditingController();
  final TextEditingController searchLocationController = TextEditingController(); // Search location controller

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");
    
    // Initialize the controllers with values passed from the previous screen
    buildingNameController.text = widget.buildingName;
    cityController.text = widget.city;
    pincodeController.text = widget.pincode;
    stateController.text = widget.state;

    print('API Key: ${dotenv.env['GOOGLE_API_KEY']}');

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        _removeOverlay();
      }
    });
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

  // Function to get current location and fill in the address
  Future<void> _getCurrentLocation() async {
    print('Getting current location...');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are not enabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        print('Location permission denied.');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    // Get address from coordinates
    _getAddressFromCoordinates(position.latitude, position.longitude);
  }

  // Fetch the address using latitude and longitude
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      print('Fetching address from coordinates: $lat, $lng');
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          buildingNameController.text = placemark.name ?? '';
          cityController.text = placemark.locality ?? '';
          stateController.text = placemark.administrativeArea ?? '';
          pincodeController.text = placemark.postalCode ?? '';
          completeAddressController.text = "${placemark.name}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
          latitude = lat;   // Store latitude
          longitude = lng;  // Store longitude
        });
      }
    } catch (e) {
      print("Error fetching address: $e");
    }
  }

  // Fetch predictions from Google Places API
  Future<void> _getPredictions(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() => predictions = []);
      }
      _removeOverlay();
      return;
    }

    try {
      _latestQuery = query;
      print('Fetching predictions for: $query');
      final result = await _places.findAutocompletePredictions(query, countries: ['IN']);
      print('Predictions result: $result');
    
      // Check if predictions exist in the response
      if (result.predictions?.isEmpty ?? true) {
        print('No predictions found.');
        if (mounted) setState(() => predictions = []);
        _removeOverlay();
        return;
      } else {
        // Ignore stale results if user has typed more meanwhile
        if (_latestQuery != query || searchLocationController.text.trim().isEmpty) {
          return;
        }
        if (mounted) setState(() => predictions = result.predictions!);
        print('Predictions: $predictions');
      }
      if (predictions.isNotEmpty && searchLocationController.text.trim().isNotEmpty) {
        _showOverlay();
      }
    } catch (e) {
      print('Error fetching predictions: $e');
    }
  }

  // Show overlay with the list of predictions anchored to the search field
  void _showOverlay() {
    _removeOverlay();
    final double screenW = MediaQuery.of(context).size.width;
    // Force the popup to be half the screen width
    final double overlayWidth = (screenW * 0.5).clamp(160.0, screenW).toDouble();
    overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _searchFieldLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56 + 6), // field height + gap
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SizedBox(
              width: overlayWidth,
              child: predictions.isEmpty
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: predictions.map((prediction) {
                        final text = prediction.fullText ?? '';
                        return ListTile(
                          title: Text(text),
                          onTap: () async {
                            searchLocationController.text = text;
                            await _onPredictionSelected(prediction.placeId);
                            _removeOverlay();
                          },
                        );
                      }).toList(),
                    ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context)?.insert(overlayEntry!);
  }

  // Remove overlay when no results are found or a result is selected
  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  // Handle address selection
  Future<void> _onPredictionSelected(String placeId) async {
    final placeDetails = await _places.fetchPlace(
      placeId,
      fields: [PlaceField.Name, PlaceField.AddressComponents, PlaceField.Address, PlaceField.Location],
    );

    final comps = placeDetails.place?.addressComponents ?? [];
    final model = AddressComponentsModel.fromGoogleComponents(comps);

    final lat = placeDetails.place?.latLng?.lat;
    final lng = placeDetails.place?.latLng?.lng;

    if (lat != null && lng != null) {
      model.latitude = lat;
      model.longitude = lng;
    }

    setState(() {
      buildingNameController.text = (model.buildingOrFlat.isNotEmpty ? model.buildingOrFlat : placeDetails.place?.name ?? '');
      cityController.text = model.city;
      stateController.text = model.state;
      pincodeController.text = model.postalCode;
      latitude = model.latitude;
      longitude = model.longitude;
      completeAddressController.text = placeDetails.place?.address ?? searchLocationController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Location')),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeOverlay();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompositedTransformTarget(
                link: _searchFieldLink,
              child: LayoutBuilder(builder: (context, constraints) {
                if (_anchorWidth != constraints.maxWidth) {
                  // store field width to size overlay
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _anchorWidth = constraints.maxWidth);
                  });
                }
                return SizedBox(
                  height: 56,
                  child: TextField(
                    controller: searchLocationController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                    labelText: 'Search Location',
                    hintText: 'Search for a location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.orange),
                    ),
                    ),
                    onChanged: (val) {
                      final now = DateTime.now();
                      if (val.trim().isEmpty) {
                        setState(() => predictions = []);
                        _removeOverlay();
                        return;
                      }
                      if (now.difference(_lastType) < _debounceDuration) return;
                      _lastType = now;
                      _getPredictions(val.trim());
                    },
                  ),
                );
              }),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: Text('Use Current Location'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(buildingNameController, 'Building Name and Flat No', 'Enter building name and flat number'),
            _buildTextField(cityController, 'City', 'Enter city'),
            _buildTextField(pincodeController, 'Pincode', 'Enter pincode'),
            _buildTextField(stateController, 'State', 'Enter state'),
            _buildTextField(completeAddressController, 'Complete Address', 'Full address will appear here', enabled: false),
            // SizedBox(height: 20),
            // // Display Latitude and Longitude
            // if (latitude != null && longitude != null) ...[
            //   Text('Latitude: $latitude'),
            //   Text('Longitude: $longitude'),
            // ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'buildingName': buildingNameController.text,
                  'city': cityController.text,
                  'pincode': pincodeController.text,
                  'state': stateController.text,
                  'latitude': latitude,
                  'longitude': longitude,
                });
              },
              child: Text('Submit Location'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        ),
      ),
    ),
  );
  }

  // Custom method to build text fields with consistent styling
  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
        onChanged: (text) {
          // If this field is the search field, trigger predictions
          if (controller == searchLocationController) {
            final now = DateTime.now();
            if (now.difference(_lastType) < _debounceDuration) return;
            _lastType = now;
            _getPredictions(text.trim());
          }
        },
      ),
    );
  }
}

// Address model to store the fetched components
class AddressComponentsModel {
  String fullAddress;
  String city;
  String state;
  String country;
  String postalCode;
  String buildingOrFlat;
  double? latitude;
  double? longitude;

  AddressComponentsModel({
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.buildingOrFlat,
    this.latitude,
    this.longitude,
  });

  factory AddressComponentsModel.fromGoogleComponents(
    List<AddressComponent> comps,
  ) {
    String _extract(String type) => comps
        .firstWhere(
          (e) => e.types.contains(type),
          orElse: () => AddressComponent(name: '', shortName: '', types: []),
        )
        .name;

    final buildingOrFlat = _extract('route');

    return AddressComponentsModel(
      fullAddress: _extract('formatted_address'),
      city: _extract('locality'),
      state: _extract('administrative_area_level_1'),
      country: _extract('country'),
      postalCode: _extract('postal_code'),
      buildingOrFlat: buildingOrFlat,
    );
  }
}
