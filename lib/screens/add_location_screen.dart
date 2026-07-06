import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({
    super.key,
    this.buildingName = '',
    this.city = '',
    this.pincode = '',
    this.state = '',
    this.initialCompleteAddress,
    this.initialScoFlatHouse,
    this.initialStreetSectorArea,
  });

  final String buildingName;
  final String city;
  final String pincode;
  final String state;

  final String? initialCompleteAddress;
  final String? initialScoFlatHouse;
  final String? initialStreetSectorArea;

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  static const Color _gold = Color(0xFF8B6500);
  static const Color _goldLight = Color(0xFFD0A244);
  static const Color _ink = Color(0xFF1F1B18);
  static const Color _muted = Color(0xFF6F665E);
  static const Color _border = Color(0xFFE8DED6);
  static const Color _fieldFill = Color(0xFFF7F4F3);

  double? latitude;
  double? longitude;

  late FlutterGooglePlacesSdk _places;
  List<AutocompletePrediction> predictions = [];
  OverlayEntry? overlayEntry;

  final LayerLink _searchFieldLink = LayerLink();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _completeAddressFieldScrollController =
      ScrollController();
  final GlobalKey _completeAddressKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();

  final Duration _debounceDuration = const Duration(milliseconds: 150);
  DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
  String _latestQuery = '';

  bool _isLoading = false;
  bool _isSyncingCompleteAddress = false;
  bool _isSelectingPlace = false;

  String _baseCompleteAddress = '';

  final TextEditingController completeAddressController =
      TextEditingController();
  final TextEditingController scoFlatHouseController = TextEditingController();
  final TextEditingController streetSectorAreaController =
      TextEditingController();
  final TextEditingController searchLocationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? '');

    if (widget.initialScoFlatHouse?.isNotEmpty == true) {
      scoFlatHouseController.text = widget.initialScoFlatHouse!;
    }

    if (widget.initialStreetSectorArea?.isNotEmpty == true) {
      streetSectorAreaController.text = widget.initialStreetSectorArea!;
    } else if (widget.initialCompleteAddress?.isNotEmpty == true) {
      final derivedStreet = _deriveStreetSectorArea(
        _cleanAddressText(widget.initialCompleteAddress!),
      );
      if (derivedStreet.isNotEmpty) {
        streetSectorAreaController.text = derivedStreet;
      }
    }

    if (widget.initialCompleteAddress?.isNotEmpty == true) {
      _baseCompleteAddress = _addressWithoutManualParts(
        _cleanAddressText(widget.initialCompleteAddress!),
      );
      _syncCompleteAddressFromParts();
    }

    scoFlatHouseController.addListener(_syncCompleteAddressFromParts);
    streetSectorAreaController.addListener(_syncCompleteAddressFromParts);
    completeAddressController.addListener(_captureManualCompleteAddress);

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_searchFocus.hasFocus) {
            _removeOverlay();
          }
        });
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchFocus.dispose();
    _scrollController.dispose();

    scoFlatHouseController.removeListener(_syncCompleteAddressFromParts);
    streetSectorAreaController.removeListener(_syncCompleteAddressFromParts);
    completeAddressController.removeListener(_captureManualCompleteAddress);

    completeAddressController.dispose();
    scoFlatHouseController.dispose();
    streetSectorAreaController.dispose();
    searchLocationController.dispose();
    _completeAddressFieldScrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    FocusScope.of(context).unfocus();
    _removeOverlay();
    _formKey.currentState?.reset();

    setState(() {
      _clearManualAddressInputs(clearCompleteAddress: true);
      _baseCompleteAddress = '';
      latitude = null;
      longitude = null;
      _isLoading = true;
    });

    searchLocationController.clear();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          Fluttertoast.showToast(
              msg: translateText(
            'Turn on location services to use your current location',
          ));
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
          Fluttertoast.showToast(
              msg: translateText(
            'Allow location access to autofill your address details',
          ));
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
              translateText(
                'Enable location permissions in Settings to use your current location.',
              ),
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
      await _scrollToCompleteAddress();
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scrollToCompleteAddress() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final fieldContext = _completeAddressKey.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;

    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  void _showWrappedToast(String message) {
    final toast = FToast()..init(context);
    final screenWidth = MediaQuery.of(context).size.width;

    toast.showToast(
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth - 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4B4B4B),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _cleanAddressText(String value) {
    final cleaned = value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(_addressDisallowedRegex, '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .replaceAll(RegExp(r',\s*,'), ',')
        .trim();
    return _dedupeAddressParts(cleaned);
  }

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

//       final formattedAddress = _cleanAddressText(
//         parts
//             .whereType<String>()
//             .where((value) => value.trim().isNotEmpty)
//             .map((value) => value.trim())
//             .join(', '),
//       );

//       _removeOverlay();

//       _isSelectingPlace = true;
//       setState(() {
//   _setBaseCompleteAddress(formattedAddress);

//   // Keep search location empty when using current location
//   searchLocationController.clear();

//   predictions = [];
//   latitude = lat;
//   longitude = lng;
// });
//       _isSelectingPlace = false;

//       debugPrint('CURRENT LOCATION LAT=$latitude LNG=$longitude');
//     } catch (e) {
//       debugPrint('Error fetching address: $e');
//     }
//   }
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

      final formattedAddress = _cleanAddressText(
        parts
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .map((value) => value.trim())
            .join(', '),
      );
      // final derivedStreet = _deriveStreetSectorArea(formattedAddress);
final derivedStreet = '';
      _removeOverlay();

      _isSyncingCompleteAddress = true;
      setState(() {
    _baseCompleteAddress = formattedAddress;

        scoFlatHouseController.clear();
        streetSectorAreaController.value = TextEditingValue(
          text: derivedStreet,
          selection: TextSelection.collapsed(offset: derivedStreet.length),
        );

        completeAddressController.value = TextEditingValue(
  text: formattedAddress,
  selection: TextSelection.collapsed(offset: formattedAddress.length),
);
     

        // Keep search location empty when using current location
        searchLocationController.clear();

        predictions = [];
        latitude = lat;
        longitude = lng;
      });
      _isSyncingCompleteAddress = false;

      debugPrint('CURRENT LOCATION ADDRESS=$formattedAddress');
      debugPrint('CURRENT LOCATION COMPLETE=${completeAddressController.text}');
      debugPrint('CURRENT LOCATION LAT=$latitude LNG=$longitude');
    } catch (e) {
      debugPrint('Error fetching address: $e');
    }
  }

  void _clearManualAddressInputs({bool clearCompleteAddress = false}) {
    _isSyncingCompleteAddress = true;

    scoFlatHouseController.clear();
    streetSectorAreaController.clear();

    if (clearCompleteAddress) {
      completeAddressController.clear();
    }

    _isSyncingCompleteAddress = false;
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

      final preds = result.predictions;

      if (_latestQuery != query || searchLocationController.text.isEmpty) {
        return;
      }

      setState(() => predictions = preds);

      if (preds.isNotEmpty) {
        _showOverlay();
      }
    } catch (e) {
      debugPrint('Error fetching predictions: $e');
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);

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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    title: Text(
                      p.fullText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () async {
                      final placeId = p.placeId;
                      final suggestionText = p.fullText.trim();

                      _isSelectingPlace = true;

                      setState(() {
                        searchLocationController.value = TextEditingValue(
                          text: suggestionText,
                          selection: TextSelection.collapsed(
                            offset: suggestionText.length,
                          ),
                        );

                        // _baseCompleteAddress = suggestionText;

                        // completeAddressController.value = TextEditingValue(
                        //   text: suggestionText,
                        //   selection: TextSelection.collapsed(
                        //     offset: suggestionText.length,
                        //   ),
                        // );

                        predictions = [];
                      });

                      _removeOverlay();

                      await _onPredictionSelected(placeId, suggestionText);

                      _isSelectingPlace = false;

                      if (!mounted) return;

                      _searchFocus.unfocus();

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _scrollToCompleteAddress();
                      });
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

  Future<void> _onPredictionSelected(
    String placeId,
    String fallbackSuggestionText,
  ) async {
    _isSelectingPlace = true;

    debugPrint('---------------- FETCH PLACE DETAILS START ----------------');
    debugPrint('FETCH placeId = $placeId');
    debugPrint('FETCH fallbackSuggestionText = $fallbackSuggestionText');

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

      final place = details.place;

      debugPrint('FETCH raw place = $place');
      debugPrint('FETCH name = ${place?.name}');
      debugPrint('FETCH address = ${place?.address}');
      debugPrint('FETCH latLng = ${place?.latLng}');
      debugPrint('FETCH lat = ${place?.latLng?.lat}');
      debugPrint('FETCH lng = ${place?.latLng?.lng}');
      debugPrint('FETCH addressComponents = ${place?.addressComponents}');

      final placeAddress = (place?.address ?? '').trim();
      final placeName = (place?.name ?? '').trim();

      final address = _cleanAddressText(
  placeName.isNotEmpty && placeAddress.isNotEmpty
      ? '$placeName, $placeAddress'
      : fallbackSuggestionText.isNotEmpty && placeAddress.isNotEmpty
          ? '$fallbackSuggestionText, $placeAddress'
          : placeAddress.isNotEmpty
              ? placeAddress
              : fallbackSuggestionText,
);

      double? lat = place?.latLng?.lat;
      double? lng = place?.latLng?.lng;

      debugPrint('PARSED address = $address');
      debugPrint('PARSED lat = $lat');
      debugPrint('PARSED lng = $lng');

      if ((lat == null || lng == null) && address.isNotEmpty) {
        debugPrint('GEOCODE fallback started for address = $address');

        try {
          final locations = await locationFromAddress(address);

          debugPrint('GEOCODE result count = ${locations.length}');

          for (var i = 0; i < locations.length; i++) {
            debugPrint(
              'GEOCODE[$i] lat=${locations[i].latitude}, lng=${locations[i].longitude}',
            );
          }

          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lng = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('GEOCODE fallback failed = $e');
        }
      }

      if (!mounted) return;

   final derivedStreet = '';

      _isSyncingCompleteAddress = true;
      setState(() {
        searchLocationController.value = TextEditingValue(
          text: address,
          selection: TextSelection.collapsed(offset: address.length),
        );

        _baseCompleteAddress = address;

        scoFlatHouseController.clear();
        streetSectorAreaController.value = TextEditingValue(
          text: derivedStreet,
          selection: TextSelection.collapsed(offset: derivedStreet.length),
        );

        completeAddressController.value = TextEditingValue(
          text: address,
          selection: TextSelection.collapsed(offset: address.length),
        );

        latitude = lat;
        longitude = lng;
        predictions = [];
      });
      _isSyncingCompleteAddress = false;

      debugPrint('STATE latitude = $latitude');
      debugPrint('STATE longitude = $longitude');
      debugPrint('---------------- FETCH PLACE DETAILS END ----------------');
    } catch (e, stack) {
      debugPrint('---------------- FETCH PLACE DETAILS ERROR ----------------');
      debugPrint('ERROR = $e');
      debugPrint('STACK = $stack');

      final cleanFallback = _cleanAddressText(fallbackSuggestionText);

      double? lat;
      double? lng;

      debugPrint('ERROR FALLBACK geocode address = $cleanFallback');

      try {
        final locations = await locationFromAddress(cleanFallback);

        debugPrint('ERROR FALLBACK geocode count = ${locations.length}');

        for (var i = 0; i < locations.length; i++) {
          debugPrint(
            'ERROR FALLBACK geocode[$i] lat=${locations[i].latitude}, lng=${locations[i].longitude}',
          );
        }

        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (geoError) {
        debugPrint('ERROR FALLBACK geocode failed = $geoError');
      }

      if (!mounted) return;

      final derivedStreet = _deriveStreetSectorArea(cleanFallback);

      _isSyncingCompleteAddress = true;
      setState(() {
        searchLocationController.value = TextEditingValue(
          text: cleanFallback,
          selection: TextSelection.collapsed(offset: cleanFallback.length),
        );

        _baseCompleteAddress = cleanFallback;

        scoFlatHouseController.clear();
        streetSectorAreaController.value = TextEditingValue(
          text: derivedStreet,
          selection: TextSelection.collapsed(offset: derivedStreet.length),
        );

        completeAddressController.value = TextEditingValue(
          text: cleanFallback,
          selection: TextSelection.collapsed(offset: cleanFallback.length),
        );

        latitude = lat;
        longitude = lng;
        predictions = [];
      });
      _isSyncingCompleteAddress = false;

      debugPrint('ERROR STATE latitude = $latitude');
      debugPrint('ERROR STATE longitude = $longitude');
      debugPrint(
          '---------------- FETCH PLACE DETAILS ERROR END ----------------');
    } finally {
      _isSelectingPlace = false;
    }
  }

  String _composedAddress() {
    final composedAddress = _composeAddressFromParts();

    final address = composedAddress.isNotEmpty
        ? composedAddress
        : completeAddressController.text;

    return _cleanAddressText(address);
  }

  List<String> _manualAddressParts() {
    return [
      scoFlatHouseController.text.trim(),
      streetSectorAreaController.text.trim(),
    ].where((value) => value.isNotEmpty).toList();
  }

  List<String> _splitAddressParts(String value) {
    final seen = <String>{};
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) {
      final key = _addressPartKey(part);
      if (key.isEmpty) return false;
      return seen.add(key);
    }).toList();
  }

  String _addressPartKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _dedupeAddressParts(String address) {
    return _splitAddressParts(address).join(', ');
  }

  String _deriveStreetSectorArea(String address) {
    final remaining = _splitAddressParts(
      _addressWithoutManualParts(_cleanAddressText(address)),
    );
    if (remaining.length >= 3) {
      return remaining.skip(1).take(2).join(', ');
    }
    if (remaining.length >= 2) {
      return remaining.skip(1).join(', ');
    }
    return '';
  }

  String _addressWithoutManualParts(String address) {
    final manualPartsLower = _manualAddressParts()
        .map(_addressPartKey)
        .where((part) => part.isNotEmpty)
        .toSet();

    if (manualPartsLower.isEmpty) return address.trim();

    return _splitAddressParts(address)
        .where((part) => !manualPartsLower.contains(_addressPartKey(part)))
        .join(', ');
  }

  String _composeAddressFromParts() {
    final manualParts = _manualAddressParts();

    final baseParts = _splitAddressParts(
      _addressWithoutManualParts(_baseCompleteAddress),
    );

    return _dedupeAddressParts([...manualParts, ...baseParts].join(', '));
  }

  void _setBaseCompleteAddress(String address) {
    _baseCompleteAddress =
        _addressWithoutManualParts(_cleanAddressText(address));
    _syncCompleteAddressFromParts();
  }

  void _syncCompleteAddressFromParts() {
    if (_isSyncingCompleteAddress || _isSelectingPlace) return;

    final currentAddress = completeAddressController.text.trim();

    if (_baseCompleteAddress.isEmpty && currentAddress.isNotEmpty) {
      _baseCompleteAddress = _addressWithoutManualParts(
        _cleanAddressText(currentAddress),
      );
    }

    final composedAddress = _composeAddressFromParts();

    if (completeAddressController.text == composedAddress) return;

    _isSyncingCompleteAddress = true;

    completeAddressController.text = composedAddress;
    completeAddressController.selection = TextSelection.collapsed(
      offset: completeAddressController.text.length,
    );

    _isSyncingCompleteAddress = false;
  }

  void _captureManualCompleteAddress() {
    if (_isSyncingCompleteAddress || _isSelectingPlace) return;

    latitude = null;
    longitude = null;

    _baseCompleteAddress = _addressWithoutManualParts(
      _cleanAddressText(completeAddressController.text),
    );
  }

  void _clearSelectedCoordinatesForManualInput() {
    if (_isSelectingPlace || _isSyncingCompleteAddress) return;

    latitude = null;
    longitude = null;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageListener>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: buildProfileSubpageAppBar(
        title: translateText('Add Location'),
        toolbarHeight: kToolbarHeight,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeOverlay();
        },
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildSearchCard(),
                      const SizedBox(height: 20),
                      _buildManualAddressCard(),
                      const SizedBox(height: 18),
                      _buildProTipCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return _ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(translateText('Search Location')),
          const SizedBox(height: 10),
          CompositedTransformTarget(
            link: _searchFieldLink,
            child: SizedBox(
              height: 48,
              child: Stack(
                children: [
                  TextFormField(
                    controller: searchLocationController,
                    focusNode: _searchFocus,
                    maxLines: 1,
                    maxLength: 120,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.search,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(120),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: translateText('Search your location...'),
                      hintStyle: const TextStyle(
                        color: Color(0xFF9A928B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _gold,
                        size: 20,
                      ),
                      suffixIcon: searchLocationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                              ),
                              splashRadius: 18,
                              onPressed: () {
                                FocusScope.of(context).unfocus();

                                setState(() {
                                  searchLocationController.clear();
                                  completeAddressController.clear();
                                  _baseCompleteAddress = '';
                                  predictions = [];
                                  latitude = null;
                                  longitude = null;
                                });

                                _removeOverlay();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: _fieldFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _goldLight,
                          width: 1.3,
                        ),
                      ),
                    ),
                    onChanged: (val) async {
                      setState(() {
                        _clearSelectedCoordinatesForManualInput();
                      });

                      if (val.trim().isEmpty) {
                        _removeOverlay();
                        setState(() => predictions.clear());
                        return;
                      }

                      await _getPredictions(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: _border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  translateText('OR'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _border, thickness: 1)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _goldLight, width: 1.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                translateText('Use Current Location').toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualAddressCard() {
    return _ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   translateText('Manually Enter Address'),
          //   style: const TextStyle(
          //     color: Color(0xFF161616),
          //     fontSize: 22,
          //     fontWeight: FontWeight.w500,
          //     height: 1.2,
          //   ),
          // ),
          // const SizedBox(height: 22),
          _buildTextField(
            controller: scoFlatHouseController,
            label: 'House/Flat No',
            hint: 'e.g. 402, Luxe Residency',
            isRequired: false,
            maxLength: 30,
            regex: _addressAllowedRegex,
            inputFormatters: _addressInputFormatters,
          ),
          _buildTextField(
            controller: streetSectorAreaController,
            label: 'Street/Area',
            hint: 'e.g. Golden Avenue',
            isRequired: false,
            maxLength: 60,
            keyboardType: TextInputType.streetAddress,
            regex: _addressAllowedRegex,
            inputFormatters: _addressInputFormatters,
          ),
          KeyedSubtree(
            key: _completeAddressKey,
            child: _buildTextField(
              controller: completeAddressController,
              label: 'Complete Address',
              hint: 'Start typing above to auto-suggest full address...',
              isRequired: true,
              minLines: 3,
              maxLines: 3,
              showScrollbar: true,
              scrollController: _completeAddressFieldScrollController,
              maxLength: 180,
              keyboardType: TextInputType.streetAddress,
              textCapitalization: TextCapitalization.sentences,
              regex: null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(180),
              ],
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: _gold, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    translateText('Autofill active'),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              suffixInsideField: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async => _submitLocation(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0x338B6500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                translateText('Confirm Location').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard() {
    return _ThemedCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: _gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateText('Pro Tip'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  translateText(
                    'Accurate locations help clients find your salon faster and improve your local search ranking.',
                  ),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // void _submitLocation() {
  //   if (_formKey.currentState?.validate() ?? false) {
  //     final composedAddress = _composedAddress();

  //     debugPrint(
  //       'RETURN LOCATION lat=$latitude lng=$longitude address=$composedAddress',
  //     );

  //     if (composedAddress.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             translateText('Please enter or select the complete address.'),
  //           ),
  //         ),
  //       );
  //       return;
  //     }

  //     if (latitude == null ||
  //         longitude == null ||
  //         latitude == 0.0 ||
  //         longitude == 0.0) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             translateText(
  //               'Please select a location from suggestions or use current location.',
  //             ),
  //           ),
  //         ),
  //       );
  //       return;
  //     }

  //     Navigator.pop(context, {
  //       'completeAddress': composedAddress,
  //       'baseCompleteAddress': _baseCompleteAddress.trim(),
  //       'scoFlatHouse': scoFlatHouseController.text.trim(),
  //       'streetSectorArea': streetSectorAreaController.text.trim(),
  //       'latitude': latitude,
  //       'longitude': longitude,
  //     });
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           translateText('Please fill all required fields correctly'),
  //         ),
  //       ),
  //     );
  //   }
  // }
  Future<void> _submitLocation() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      Fluttertoast.showToast(
          msg: translateText('Please fill all required fields correctly'));
      return;
    }

    final composedAddress = _composedAddress();

    if (composedAddress.isEmpty) {
      Fluttertoast.showToast(
          msg: translateText('Please enter or select the complete address.'));
      return;
    }

    var finalLatitude = latitude;
    var finalLongitude = longitude;

    if (finalLatitude == null ||
        finalLongitude == null ||
        finalLatitude == 0.0 ||
        finalLongitude == 0.0) {
      try {
        debugPrint('SUBMIT GEOCODING ADDRESS: $composedAddress');

        final locations = await locationFromAddress(composedAddress);

        debugPrint('SUBMIT GEOCODING RESULT COUNT: ${locations.length}');

        if (locations.isNotEmpty) {
          finalLatitude = locations.first.latitude;
          finalLongitude = locations.first.longitude;

          setState(() {
            latitude = finalLatitude;
            longitude = finalLongitude;
          });
        }
      } catch (e) {
        debugPrint('Submit geocoding failed: $e');
      }
    }

    debugPrint(
      'RETURN LOCATION lat=$finalLatitude lng=$finalLongitude address=$composedAddress',
    );

    if (finalLatitude == null ||
        finalLongitude == null ||
        finalLatitude == 0.0 ||
        finalLongitude == 0.0) {
      _showWrappedToast(
        translateText(
          'Could not get coordinates. Please use current location or select a more specific suggestion.',
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.pop(context, {
      'completeAddress': composedAddress,
      'baseCompleteAddress': _addressWithoutManualParts(
        _cleanAddressText(_baseCompleteAddress),
      ),
      'scoFlatHouse': scoFlatHouseController.text.trim(),
      'streetSectorArea': streetSectorAreaController.text.trim(),
      'latitude': finalLatitude,
      'longitude': finalLongitude,
    });
  }
}

final RegExp _addressAllowedRegex = RegExp(r'^[^\u0000-\u001F\u007F]+$');

final RegExp _addressDisallowedRegex = RegExp(r'[\u0000-\u001F\u007F]');

final List<TextInputFormatter> _addressInputFormatters = [
  FilteringTextInputFormatter.allow(
    RegExp(r'[^\u0000-\u001F\u007F]'),
  ),
];
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  bool enabled = true,
  bool isRequired = true,
  int? maxLength,
  int? minLines,
  int? maxLines,
  bool showScrollbar = false,
  ScrollController? scrollController,
  RegExp? regex,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
  TextCapitalization textCapitalization = TextCapitalization.words,
  Widget? suffix,
  bool suffixInsideField = false,
}) {
  final baseLabel = label.replaceAll('*', '').trim();
  final translatedLabel = translateText(baseLabel);
  final translatedHint = translateText(hint.trim());
  final isMultiLine = minLines != null || (maxLines ?? 1) > 1;

  final textField = TextFormField(
    controller: controller,
    scrollController: scrollController,
    readOnly: !enabled,
    maxLength: maxLength,
    minLines: minLines,
    maxLines: maxLines ?? 1,
    keyboardType: keyboardType,
    inputFormatters: [
      ...?inputFormatters,
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ],
    textCapitalization: textCapitalization,
    textAlignVertical:
        isMultiLine ? TextAlignVertical.top : TextAlignVertical.center,
    style: const TextStyle(
      color: Color(0xFF1F1B18),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    cursorColor: _AddLocationScreenState._gold,
    validator: (value) {
      final v = value?.trim() ?? '';

      if (isRequired && v.isEmpty) {
        final errorTemplate = translateText('{field} is required');
        return errorTemplate.replaceAll('{field}', translatedLabel);
      }

      if (maxLength != null && v.length > maxLength) {
        return '$translatedLabel cannot exceed $maxLength characters';
      }

      if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
        return '$translatedLabel can contain only alphabets, numbers, spaces, comma, /, -, +, ., # and brackets';
      }

      return null;
    },
    decoration: InputDecoration(
      counterText: '',
      hintText: translatedHint,
      hintStyle: const TextStyle(
        color: Color(0xFF9A928B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _AddLocationScreenState._fieldFill,
      contentPadding: EdgeInsets.fromLTRB(
        12,
        isMultiLine ? 12 : 0,
        suffixInsideField ? 92 : 12,
        isMultiLine ? 12 : 0,
      ),
      constraints: BoxConstraints(
        minHeight: isMultiLine ? 96 : 52,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _AddLocationScreenState._border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _AddLocationScreenState._border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _AddLocationScreenState._goldLight,
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red, width: 1),
      ),
      errorStyle: const TextStyle(
        color: AppColors.red,
        fontSize: 11,
      ),
    ),
  );

  final fieldWidget = showScrollbar && isMultiLine
      ? Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          radius: const Radius.circular(8),
          thickness: 3,
          child: textField,
        )
      : textField;

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          isRequired ? '$translatedLabel *' : translatedLabel,
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            fieldWidget,
            if (suffix != null && suffixInsideField)
              Positioned(
                top: 12,
                right: 12,
                child: IgnorePointer(child: suffix),
              ),
          ],
        ),
        if (suffix != null && !suffixInsideField)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(child: suffix),
            ),
          ),
        if (maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length} / $maxLength',
                      style: TextStyle(
                        color: value.text.length >= maxLength
                            ? AppColors.red
                            : const Color(0xFF8B8178),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ThemedCard extends StatelessWidget {
  const _ThemedCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AddLocationScreenState._border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F4C3426),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF514840),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
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
    List<AddressComponent> comps,
  ) {
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
