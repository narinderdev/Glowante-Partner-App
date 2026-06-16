import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import '../services/language_listener.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/services.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({
    super.key,

    // Kept old params optional for backward compatibility (no longer used)
    this.buildingName = '',
    this.city = '',
    this.pincode = '',
    this.state = '',

    // New (optional) initial values
    this.initialCompleteAddress,
    this.initialScoFlatHouse,
    this.initialStreetSectorArea,
  });

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
  final GlobalKey _completeAddressKey = GlobalKey();
  final Duration _debounceDuration = const Duration(milliseconds: 150);
  DateTime _lastType = DateTime.fromMillisecondsSinceEpoch(0);
  String _latestQuery = '';
  bool _isLoading = false;
  bool _isSyncingCompleteAddress = false;
  String _baseCompleteAddress = '';

  final _formKey = GlobalKey<FormState>();

  // Controllers we keep
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
    _places = FlutterGooglePlacesSdk(dotenv.env['GOOGLE_API_KEY'] ?? "");

    if (widget.initialScoFlatHouse?.isNotEmpty == true) {
      scoFlatHouseController.text = widget.initialScoFlatHouse!;
    }
    if (widget.initialStreetSectorArea?.isNotEmpty == true) {
      streetSectorAreaController.text = widget.initialStreetSectorArea!;
    }
    if (widget.initialCompleteAddress?.isNotEmpty == true) {
      _baseCompleteAddress =
          _addressWithoutManualParts(widget.initialCompleteAddress!);
      _syncCompleteAddressFromParts();
    }

    scoFlatHouseController.addListener(_syncCompleteAddressFromParts);
    streetSectorAreaController.addListener(_syncCompleteAddressFromParts);
    completeAddressController.addListener(_captureManualCompleteAddress);

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeOverlay();
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
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    FocusScope.of(context).unfocus();
    _removeOverlay();
    _formKey.currentState?.reset();
    setState(() {
      _clearManualAddressInputs(clearCompleteAddress: true);
      _baseCompleteAddress = '';
      _isLoading = true;
    });

    // Do not fill search when using current location
    searchLocationController.clear();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                translateText(
                    'Turn on location services to use your current location'),
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
                translateText(
                    'Allow location access to autofill your address details'),
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
              translateText(
                  'Enable location permissions in Settings to use your current location.'),
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
      debugPrint("Location error: $e");
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
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .map((value) => value.trim())
          .join(', ');

      _removeOverlay();

      setState(() {
        _setBaseCompleteAddress(formattedAddress);

        // Also make sure predictions are not shown
        predictions.clear();

        latitude = lat;
        longitude = lng;
      });
    } catch (e) {
      debugPrint("Error fetching address: $e");
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
      if (preds.isNotEmpty) _showOverlay();
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    title: Text(
                      p.fullText,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    onTap: () async {
                      await _onPredictionSelected(p.placeId);
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

      final place = details.place;
      if (place == null) return;
      final placeAddress = (place.address ?? '').trim();
      final placeName = (place.name ?? '').trim();
      final address = placeAddress.isNotEmpty ? placeAddress : placeName;
      final lat = place.latLng?.lat;
      final lng = place.latLng?.lng;

      if (!mounted) return;
      setState(() {
        _setBaseCompleteAddress(address);
        searchLocationController.text = address.trim();
        latitude = lat;
        longitude = lng;
      });
    } catch (e) {
      debugPrint("Error fetching place details: $e");
    }
  }

  String _composedAddress() {
    final composedAddress = _composeAddressFromParts();
    if (composedAddress.isNotEmpty) return composedAddress;
    return completeAddressController.text.trim();
  }

  List<String> _manualAddressParts() {
    return [
      scoFlatHouseController.text.trim(),
      streetSectorAreaController.text.trim(),
    ].where((value) => value.isNotEmpty).toList();
  }

  List<String> _splitAddressParts(String value) {
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String _addressWithoutManualParts(String address) {
    final manualPartsLower =
        _manualAddressParts().map((part) => part.toLowerCase()).toSet();
    if (manualPartsLower.isEmpty) return address.trim();
    return _splitAddressParts(address)
        .where((part) => !manualPartsLower.contains(part.toLowerCase()))
        .join(', ');
  }

  String _composeAddressFromParts() {
    final manualParts = _manualAddressParts();
    final baseParts = _splitAddressParts(
      _addressWithoutManualParts(_baseCompleteAddress),
    );
    return [...manualParts, ...baseParts].join(', ');
  }

  void _setBaseCompleteAddress(String address) {
    _baseCompleteAddress = _addressWithoutManualParts(address);
    _syncCompleteAddressFromParts();
  }

  void _syncCompleteAddressFromParts() {
    if (_isSyncingCompleteAddress) return;

    final currentAddress = completeAddressController.text.trim();
    if (_baseCompleteAddress.isEmpty && currentAddress.isNotEmpty) {
      _baseCompleteAddress = _addressWithoutManualParts(currentAddress);
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
    if (_isSyncingCompleteAddress) return;
    _baseCompleteAddress = _addressWithoutManualParts(
      completeAddressController.text,
    );
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
    final showSearchEllipsis = !_searchFocus.hasFocus &&
        searchLocationController.text.trim().isNotEmpty;
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
                    style: TextStyle(
                      color: showSearchEllipsis ? Colors.transparent : _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: translateText('Search your location...'),
                      counterText: '',
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
                              icon: const Icon(Icons.close, color: Colors.grey),
                              splashRadius: 18,
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                searchLocationController.clear();
                                setState(() => predictions.clear());
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
                        borderSide:
                            const BorderSide(color: _goldLight, width: 1.3),
                      ),
                    ),
                    onChanged: (val) async {
                      setState(() {});
                      if (val.trim().isEmpty) {
                        _removeOverlay();
                        setState(() => predictions.clear());
                        return;
                      }
                      await _getPredictions(val);
                    },
                  ),
                  if (showSearchEllipsis)
                    Positioned.fill(
                      left: 48,
                      right: 48,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            searchLocationController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
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
          Text(
            translateText('Manually Enter Address'),
            style: const TextStyle(
              color: Color(0xFF161616),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          _buildTextField(
            controller: scoFlatHouseController,
            label: 'House/Flat No',
            hint: 'e.g. 402, Luxe Residency',
            isRequired: false,
            maxLength: 30,
            inputFormatters: [
              LengthLimitingTextInputFormatter(30),
            ],
          ),
          _buildTextField(
            controller: streetSectorAreaController,
            label: 'Street/Area',
            hint: 'e.g. Golden Avenue',
            isRequired: false,
            maxLength: 60,
            keyboardType: TextInputType.streetAddress,
            inputFormatters: [
              LengthLimitingTextInputFormatter(60),
            ],
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
              maxLength: 180,
              keyboardType: TextInputType.streetAddress,
              textCapitalization: TextCapitalization.sentences,
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
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitLocation,
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

  void _submitLocation() {
    if (_formKey.currentState?.validate() ?? false) {
      final composedAddress = _composedAddress();
      if (composedAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translateText('Please enter or select the complete address.'),
            ),
          ),
        );
        return;
      }
      Navigator.pop(context, {
        'completeAddress': composedAddress,
        'baseCompleteAddress': _baseCompleteAddress.trim(),
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
  Widget? suffix,
}) {
  final baseLabel = label.replaceAll('*', '').trim();
  final translatedLabel = translateText(baseLabel);
  final translatedHint = translateText(hint.trim());

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          isRequired ? '$translatedLabel *' : translatedLabel,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: !enabled,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines ?? 1,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          textAlignVertical: minLines == null
              ? TextAlignVertical.center
              : TextAlignVertical.top,
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

            if (regex != null && v.isNotEmpty && !regex.hasMatch(v)) {
              final errorTemplate = translateText('Invalid {field}');
              return errorTemplate.replaceAll('{field}', translatedLabel);
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
            suffix: suffix,
            filled: true,
            fillColor: _AddLocationScreenState._fieldFill,
            contentPadding: EdgeInsets.fromLTRB(
              12,
              minLines == null ? 0 : 12,
              12,
              minLines == null ? 0 : 10,
            ),
            constraints: BoxConstraints(
              minHeight: minLines == null ? 46 : 84,
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
            errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
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
