import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/address_formatter.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class SalonDetailScreen extends StatefulWidget {
  const SalonDetailScreen({
    super.key,
    required this.salon,
  });

  final Map<String, dynamic> salon;

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  late Map<String, dynamic> _salon;
  Map<String, dynamic>? _primaryBranch;
  List<String> _services = const [];
  List<String> _teamMembers = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _salon = Map<String, dynamic>.from(widget.salon);
    _primaryBranch = _resolvePrimaryBranch(_salon);
    _loadBranchBackedDetails();
  }

  Future<void> _loadBranchBackedDetails() async {
    final branchId = _asInt(
      _primaryBranch?['id'] ?? _salon['branchId'] ?? _salon['mainBranchId'],
    );

    if (branchId == null) {
      setState(() {
        _services = _extractServices(_salon);
        _teamMembers = _extractTeamMembers(_salon['team'] ?? _salon['staff']);
      });
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService().getBranchDetail(branchId),
        ApiService().getBranchServiceDetail(branchId),
        ApiService.getTeamMembers(branchId),
      ]);

      final branchResponse = results[0];
      final serviceResponse = results[1];
      final teamResponse = results[2];
      final branchDetails =
          branchResponse['success'] == true && branchResponse['data'] is Map
              ? Map<String, dynamic>.from(branchResponse['data'] as Map)
              : _primaryBranch;

      if (!mounted) return;
      setState(() {
        _primaryBranch = branchDetails;
        _services = _extractServices(serviceResponse);
        _teamMembers = _extractTeamMembers(teamResponse['data']);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _services = _extractServices(_primaryBranch ?? _salon);
        _teamMembers =
            _extractTeamMembers(_primaryBranch?['team'] ?? _salon['team']);
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _formatDisplayTime(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;

    String formatParts(String h, String m, [String? suffix]) {
      var hour = int.tryParse(h) ?? 0;
      final minute = int.tryParse(m) ?? 0;

      if (suffix != null) {
        final s = suffix.toUpperCase();
        if (s == 'PM' && hour != 12) hour += 12;
        if (s == 'AM' && hour == 12) hour = 0;
      }

      final amPm = hour >= 12 ? 'PM' : 'AM';
      final hour12 = ((hour + 11) % 12) + 1;

      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';
    }

    final match12 = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);

    if (match12 != null) {
      return formatParts(
          match12.group(1)!, match12.group(2)!, match12.group(3)!);
    }

    final match24 = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (match24 != null) {
      return formatParts(match24.group(1)!, match24.group(2)!);
    }

    return fallback.isNotEmpty ? fallback : text;
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic>? _resolvePrimaryBranch(Map<String, dynamic> salon) {
    final branches = salon['branches'];
    if (branches is! List || branches.isEmpty) return null;

    final salonName = _cleanText(salon['name']).toLowerCase();
    final mapped = branches
        .whereType<Map>()
        .map((branch) => Map<String, dynamic>.from(branch))
        .toList();

    for (final branch in mapped) {
      final isMain = branch['isMain'];
      if (isMain == true || _cleanText(isMain).toLowerCase() == 'true') {
        return branch;
      }
      final branchName = _cleanText(branch['name']).toLowerCase();
      if (salonName.isNotEmpty && branchName == salonName) return branch;
    }
    return mapped.first;
  }

  dynamic _field(List<String> keys) {
    for (final key in keys) {
      final value = _salon[key];
      if (_cleanText(value).isNotEmpty || value is Map || value is List) {
        return value;
      }
    }
    final branch = _primaryBranch;
    if (branch != null) {
      for (final key in keys) {
        final value = branch[key];
        if (_cleanText(value).isNotEmpty || value is Map || value is List) {
          return value;
        }
      }
    }
    return null;
  }

  String _fieldText(List<String> keys) {
    final values = <dynamic>[];
    for (final key in keys) {
      values.add(_salon[key]);
    }
    final branch = _primaryBranch;
    if (branch != null) {
      for (final key in keys) {
        values.add(branch[key]);
      }
    }
    return _firstText(values);
  }

  String _composeAddress(dynamic source) {
    return formatAddressSummary(source);
  }

  Map<String, dynamic> _addressMap() {
    final salonAddress = _salon['address'];
    if (salonAddress is Map) return Map<String, dynamic>.from(salonAddress);
    final branchAddress = _primaryBranch?['address'];
    if (branchAddress is Map) return Map<String, dynamic>.from(branchAddress);
    return _primaryBranch ?? _salon;
  }

  List<String> _imageUrls() {
    final urls = <String>[];

    void add(dynamic value) {
      dynamic source = value;
      if (source is Map) {
        source = source['url'] ??
            source['imageUrl'] ??
            source['publicUrl'] ??
            source['cdnUrl'] ??
            source['src'];
      }
      final text = _cleanText(source);
      final lower = text.toLowerCase();
      if ((lower.startsWith('http://') || lower.startsWith('https://')) &&
          !urls.contains(text)) {
        urls.add(text);
      }
    }

    void addFromMap(Map<String, dynamic>? source) {
      if (source == null) return;
      final images = source['imageUrls'];
      if (images is List) {
        for (final image in images) {
          add(image);
        }
      }
      add(source['imageUrl']);
      add(source['image']);
    }

    addFromMap(_salon);
    addFromMap(_primaryBranch);
    return urls;
  }

  List<String> _extractServices(dynamic source) {
    final services = <String>[];

    void add(dynamic value) {
      final text = _cleanText(value);
      if (text.isNotEmpty && !services.contains(text)) services.add(text);
    }

    void collect(dynamic value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      if (value is! Map) {
        add(value);
        return;
      }
      final map = Map<String, dynamic>.from(value);
      final nestedServices = map['services'] ??
          map['serviceList'] ??
          map['items'] ??
          map['selectedServices'];
      final subCategories = map['subCategories'] ??
          map['subcategories'] ??
          map['children'] ??
          map['subCategory'];
      if (nestedServices != null) collect(nestedServices);
      if (subCategories != null) collect(subCategories);
      if (nestedServices == null && subCategories == null) {
        add(
          map['displayName'] ??
              map['name'] ??
              map['serviceName'] ??
              map['title'] ??
              map['code'],
        );
      }
    }

    if (source is Map) {
      for (final key in const [
        'services',
        'serviceList',
        'branchServices',
        'salonServices',
        'selectedServices',
        'serviceCodes',
        'selectedServiceCodes',
        'categories',
      ]) {
        collect(source[key]);
      }
    } else {
      collect(source);
    }
    return services;
  }

  List<String> _extractTeamMembers(dynamic source) {
    final names = <String>[];

    void addName(dynamic value) {
      if (value is! Map) {
        final text = _cleanText(value);
        if (text.isNotEmpty && !names.contains(text)) names.add(text);
        return;
      }
      final map = Map<String, dynamic>.from(value);
      final user = map['user'];
      final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
      final firstName = _firstText([map['firstName'], userMap?['firstName']]);
      final lastName = _firstText([map['lastName'], userMap?['lastName']]);
      final fullName = [firstName, lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ');
      final fallback = _firstText([
        fullName,
        map['name'],
        map['displayName'],
        map['phone'],
        userMap?['name'],
      ]);
      if (fallback.isNotEmpty && !names.contains(fallback)) {
        names.add(fallback);
      }
    }

    if (source is List) {
      for (final item in source) {
        addName(item);
      }
    } else {
      addName(source);
    }
    return names;
  }

  List<_DetailRowData> _scheduleRows() {
    final rawSchedule = _primaryBranch?['schedule'] ?? _salon['schedule'];

    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final scheduleByDay = <String, dynamic>{};

    if (rawSchedule is Map) {
      scheduleByDay.addAll(Map<String, dynamic>.from(rawSchedule));
    } else if (rawSchedule is List) {
      for (final item in rawSchedule.whereType<Map>()) {
        final day = item['day']?.toString().toLowerCase().trim();
        if (day != null && day.isNotEmpty) {
          scheduleByDay[day] = item['slots'];
        }
      }
    }

    return days.map((day) {
      final slots = scheduleByDay[day];

      if (slots is List && slots.isNotEmpty) {
        final timings = slots
            .whereType<Map>()
            .map((slot) {
              final start =
                  _formatDisplayTime(slot['startTime'] ?? slot['start']);
              final end = _formatDisplayTime(slot['endTime'] ?? slot['end']);

              if (start.isEmpty || end.isEmpty) return '';
              return '$start - $end';
            })
            .where((value) => value.isNotEmpty)
            .toList();

        return _DetailRowData(
          _capitalize(day),
          timings.isEmpty ? 'Closed' : timings.join(', '),
        );
      }

      return _DetailRowData(_capitalize(day), 'Closed');
    }).toList();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  List<_DetailRowData> _formRows() {
    final addressMap = _addressMap();
    String addressField(List<String> keys) =>
        _firstText(keys.map((key) => addressMap[key]).toList());
    final address = _firstText([
      _composeAddress(_salon['address']),
      _composeAddress(_primaryBranch?['address']),
      _composeAddress(_primaryBranch),
      _composeAddress(_salon),
    ]);

    return [
      _DetailRowData(
          'Salon Name',
          _fieldText([
            'name',
            'salonName',
            'businessName',
            'displayName',
          ])),
      _DetailRowData(
          'Phone',
          _fieldText([
            'phone',
            'phoneNumber',
            'contactNumber',
          ])),
      _DetailRowData(
          'Start Time',
          _formatDisplayTime(_fieldText([
            'startTime',
            'openingTime',
            'openTime',
          ]))),
      _DetailRowData(
        'End Time',
        _formatDisplayTime(_fieldText([
          'endTime',
          'closingTime',
          'closeTime',
        ])),
      ),
      _DetailRowData(
          'Description',
          _fieldText([
            'description',
            'salonDescription',
            'branchDescription',
            'about',
          ])),
      _DetailRowData(
          'Complete Address',
          _firstText([
            addressField(['line1', 'addressLine1', 'buildingName']),
            address,
          ])),
      _DetailRowData('House / Flat', addressField(['city'])),
      _DetailRowData(
        'Street / Area',
        addressField(['postalCode', 'pincode', 'zip']),
      ),
      _DetailRowData('State', addressField(['state'])),
      _DetailRowData(
          'Latitude',
          _firstText([
            addressField(['latitude', 'lat']),
            _primaryBranch?['latitude'],
            _salon['latitude'],
          ])),
      _DetailRowData(
          'Longitude',
          _firstText([
            addressField(['longitude', 'lng', 'lon']),
            _primaryBranch?['longitude'],
            _salon['longitude'],
          ])),
      _DetailRowData(
        'Uploaded Photos',
        _imageUrls().isEmpty ? '' : _imageUrls().length.toString(),
      ),
      // _DetailRowData(
      //   'Main Branch ID',
      //   _cleanText(
      //       _primaryBranch?['id'] ?? _field(['branchId', 'mainBranchId'])),
      // ),
    ].where((row) => row.value.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _fieldText(['name', 'salonName', 'businessName']);
    final imageUrls = _imageUrls();
    final openDays =
        _scheduleRows().where((row) => row.value != 'Closed').length;
    final branchCount = _salon['branches'] is List
        ? (_salon['branches'] as List).length
        : (_primaryBranch == null ? 0 : 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EEE7),
      appBar: buildProfileSubpageAppBar(title: translateText('Salon Details')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F4ED), Color(0xFFF3ECE3)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => RefreshFeedback.playAndRun(_loadBranchBackedDetails),
          color: AppColors.starColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeroCard(
                title: title.isEmpty ? translateText('Salon Details') : title,
                subtitle: translateText('Main Salon'),
                imageUrls: imageUrls,
                active: _salon['active'] != false,
              ),
              const SizedBox(height: 14),
              _SummaryStrip(
                items: [
                  _SummaryStat(
                      label: 'Branches', value: branchCount.toString()),
                  _SummaryStat(
                      label: 'Services', value: _services.length.toString()),
                  _SummaryStat(label: 'Open Days', value: openDays.toString()),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _WarningBox(message: _error!),
              ],
              const SizedBox(height: 14),
              _DetailSection(
                title: 'Salon Form Values',
                child: Column(
                  children: _formRows()
                      .map((row) =>
                          _DetailLine(label: row.label, value: row.value))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              _DetailSection(
                title: 'Weekly Schedule',
                child: Column(
                  children: _scheduleRows()
                      .map((row) =>
                          _DetailLine(label: row.label, value: row.value))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              _ExpandableChipSection(title: 'Services', values: _services),
              const SizedBox(height: 14),
              _ExpandableChipSection(
                  title: 'Team Members', values: _teamMembers),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData(this.label, this.value);

  final String label;
  final String value;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.imageUrls,
    required this.active,
  });

  final String title;
  final String subtitle;
  final List<String> imageUrls;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFAF4)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrls.length <= 1
                    ? (imageUrls.isEmpty
                        ? const _ImageFallback()
                        : Image.network(
                            imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _ImageFallback(),
                          ))
                    : _AutoSlidingHeroImage(
                        imageUrls: imageUrls,
                        fallback: const _ImageFallback(),
                        imageBuilder: (imageUrl) => Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const _ImageFallback(),
                        ),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF201B17).withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _StatusPill(active: active),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.starColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF201B17),
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 14,
                      color: Color(0xFF8A8178),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        translateText(
                            'Salon overview, operating hours, and team snapshot'),
                        style: const TextStyle(
                          color: Color(0xFF8A8178),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoSlidingHeroImage extends StatefulWidget {
  const _AutoSlidingHeroImage({
    required this.imageUrls,
    required this.fallback,
    required this.imageBuilder,
  });

  final List<String> imageUrls;
  final Widget fallback;
  final Widget Function(String imageUrl) imageBuilder;

  @override
  State<_AutoSlidingHeroImage> createState() => _AutoSlidingHeroImageState();
}

class _AutoSlidingHeroImageState extends State<_AutoSlidingHeroImage> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  int _autoScrollDirection = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _AutoSlidingHeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _currentPage = 0;
      _autoScrollDirection = 1;
      _stopAutoScroll();
      _startAutoScroll();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  void _startAutoScroll() {
    if (widget.imageUrls.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients || widget.imageUrls.isEmpty) {
        return;
      }
      final lastIndex = widget.imageUrls.length - 1;
      var nextPage = _currentPage + _autoScrollDirection;

      if (nextPage >= lastIndex) {
        nextPage = lastIndex;
        _autoScrollDirection = -1;
      } else if (nextPage <= 0) {
        nextPage = 0;
        _autoScrollDirection = 1;
      }

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 760),
        curve: Curves.easeInOutCubicEmphasized,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return widget.fallback;
    if (widget.imageUrls.length == 1) {
      return widget.imageBuilder(widget.imageUrls.first);
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.hardEdge,
        padEnds: false,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          if (!mounted) return;
          setState(() {
            _currentPage = index;
            if (index == 0) {
              _autoScrollDirection = 1;
            } else if (index == widget.imageUrls.length - 1) {
              _autoScrollDirection = -1;
            }
          });
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final page = _pageController.hasClients &&
                      _pageController.position.hasPixels
                  ? (_pageController.page ?? _currentPage.toDouble())
                  : _currentPage.toDouble();
              final delta = page - index;
              final distance = delta.abs().clamp(0.0, 1.0);
              final shift = -delta * 32.0;
              final scale = 1.14 - (distance * 0.08);
              final rotateY = -delta * 0.34;
              final opacity = 0.90 + (1.0 - distance) * 0.10;

              return Opacity(
                opacity: opacity,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateY(rotateY),
                    child: Transform.translate(
                      offset: Offset(shift, 0.0),
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox.expand(
                          child: widget.imageBuilder(widget.imageUrls[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText(title).toUpperCase(),
            style: const TextStyle(
              color: AppColors.starColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              translateText(label),
              style: const TextStyle(
                color: Color(0xFF7C6F63),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF201B17),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: title,
      child: values.isEmpty
          ? Text(
              translateText('No data available'),
              style: const TextStyle(
                color: Color(0xFF8A8178),
                fontWeight: FontWeight.w700,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in values) _DetailChip(label: value),
              ],
            ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0BE58)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6A4B10),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF047857) : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE6FFF1) : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? const Color(0xFF7DD3A7) : const Color(0xFFF1B4B4),
        ),
      ),
      child: Text(
        translateText(active ? 'Active' : 'Deactivated'),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEACB73)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF6B4E00),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F3EF),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.starColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            translateText('No image available'),
            style: const TextStyle(
              color: Color(0xFF756A61),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.items});

  final List<_SummaryStat> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _SummaryStatCard(stat: items[i])),
          if (i != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SummaryStat {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({required this.stat});

  final _SummaryStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translateText(stat.label).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8A8178),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: const TextStyle(
              color: Color(0xFF201B17),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableChipSection extends StatefulWidget {
  const _ExpandableChipSection({
    required this.title,
    required this.values,
    this.initialLimit = 5,
  });

  final String title;
  final List<String> values;
  final int initialLimit;

  @override
  State<_ExpandableChipSection> createState() => _ExpandableChipSectionState();
}

class _ExpandableChipSectionState extends State<_ExpandableChipSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final visibleValues = _showAll
        ? widget.values
        : widget.values.take(widget.initialLimit).toList();

    return _DetailSection(
      title: widget.title,
      child: widget.values.isEmpty
          ? Text(
              translateText('No data available'),
              style: const TextStyle(
                color: Color(0xFF8A8178),
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in visibleValues)
                      _DetailChip(label: value),
                  ],
                ),
                if (widget.values.length > widget.initialLimit) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAll = !_showAll;
                      });
                    },
                    child: Text(
                      translateText(_showAll ? 'See less' : 'See more'),
                      style: const TextStyle(
                        color: AppColors.starColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
