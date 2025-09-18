import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  Duration _debounceDuration = const Duration(milliseconds: 350);
  DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
  double? _anchorWidth;
  String _latestQuery = '';

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

    buildingNameController.text = widget.buildingName;
    cityController.text = widget.city;
    pincodeController.text = widget.pincode;
    stateController.text = widget.state;

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

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _getAddressFromCoordinates(position.latitude, position.longitude);
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          buildingNameController.text = placemark.name ?? '';
          cityController.text = placemark.locality ?? '';
          stateController.text = placemark.administrativeArea ?? '';
          pincodeController.text = placemark.postalCode ?? '';
          completeAddressController.text =
              "${placemark.name}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
          latitude = lat;
          longitude = lng;
        });
      }
    } catch (e) {
      print("Error fetching address: $e");
    }
  }

  Future<void> _getPredictions(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      setState(() => predictions = []);
      _removeOverlay();
      return;
    }

    try {
      _latestQuery = query;
      final result = await _places.findAutocompletePredictions(query, countries: ['IN']);
      if (result.predictions?.isEmpty ?? true) {
        setState(() => predictions = []);
        _removeOverlay();
        return;
      } else {
        if (_latestQuery != query || searchLocationController.text.trim().isEmpty) return;
        setState(() => predictions = result.predictions!);
      }
      if (predictions.isNotEmpty && searchLocationController.text.trim().isNotEmpty) {
        _showOverlay();
      }
    } catch (e) {
      print('Error fetching predictions: $e');
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final double screenW = MediaQuery.of(context).size.width;
    final double overlayWidth = (screenW * 0.5).clamp(160.0, screenW).toDouble();
    overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _searchFieldLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 62),
        child: SizedBox(
          width: overlayWidth,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
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

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

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
      buildingNameController.text = model.buildingOrFlat.isNotEmpty
          ? model.buildingOrFlat
          : placeDetails.place?.name ?? '';
      cityController.text = model.city;
      stateController.text = model.state;
      pincodeController.text = model.postalCode;
      latitude = model.latitude;
      longitude = model.longitude;
      completeAddressController.text =
          placeDetails.place?.address ?? searchLocationController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
    backgroundColor: Colors.orange, // main orange background
    iconTheme: const IconThemeData(
    color: Colors.white, // ✅ sets back button color to white
  ),
    centerTitle: true, // center the title
    title: const Text(
      'Add Location',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: Colors.white,
      ),
    ),
  ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeOverlay();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompositedTransformTarget(
                    link: _searchFieldLink,
                    child: TextFormField(
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
                  _buildTextField(buildingNameController, 'Building Name and Flat No',
                      'Enter building name and flat number'),
                  _buildTextField(cityController, 'City', 'Enter city'),
                  _buildTextField(pincodeController, 'Pincode', 'Enter pincode'),
                  _buildTextField(stateController, 'State', 'Enter state'),
                  _buildTextField(completeAddressController, 'Complete Address',
                      'Full address will appear here',
                      enabled: false, isRequired: false),
                  SizedBox(height: 20),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please fill all required fields')),
                        );
                      }
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
      ),
    );
  }

Widget _buildTextField(
  TextEditingController controller,
  String label,
  String hint, {
  bool enabled = true,
  bool isRequired = true,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction, // ✅ live validation
      cursorColor: Colors.orange, // ✅ orange cursor for consistency
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.orange), // ✅ orange label
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2), // ✅ orange error border
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2), // ✅ orange error border when focused
        ),
        errorStyle: const TextStyle(
          color: Colors.orange, // ✅ orange error text
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}}
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

  factory AddressComponentsModel.fromGoogleComponents(List<AddressComponent> comps) {
    String _extract(String type) => comps
        .firstWhere(
          (e) => e.types.contains(type),
          orElse: () => AddressComponent(name: '', shortName: '', types: []),
        )
        .name;

    return AddressComponentsModel(
      fullAddress: _extract('formatted_address'),
      city: _extract('locality'),
      state: _extract('administrative_area_level_1'),
      country: _extract('country'),
      postalCode: _extract('postal_code'),
      buildingOrFlat: _extract('route'),
    );
  }
}
