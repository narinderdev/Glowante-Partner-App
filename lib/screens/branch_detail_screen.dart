import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/refresh_feedback.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/address_formatter.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class BranchDetailScreen extends StatefulWidget {
  const BranchDetailScreen({
    super.key,
    required this.branchId,
    required this.initialBranch,
  });

  final int branchId;
  final Map<String, dynamic> initialBranch;

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  Map<String, dynamic> _branch = {};
  List<String> _services = const [];
  List<String> _teamMembers = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branch = Map<String, dynamic>.from(widget.initialBranch);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService().getBranchDetail(widget.branchId),
        ApiService().getBranchServiceDetail(widget.branchId),
        ApiService.getTeamMembers(widget.branchId),
      ]);

      final branchResponse = results[0];
      final serviceResponse = results[1];
      final teamResponse = results[2];

      if (mounted) {
        setState(() {
          if (branchResponse['success'] == true &&
              branchResponse['data'] is Map) {
            _branch = Map<String, dynamic>.from(branchResponse['data'] as Map);
          }
          _services = _extractServices(serviceResponse);
          _teamMembers = _extractTeamMembers(teamResponse['data']);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _services = _extractServices(_branch);
        _teamMembers = _extractTeamMembers(_branch['team'] ?? _branch['staff']);
        _isLoading = false;
      });
    }
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

  List<_DetailRowData> _scheduleRows() {
    final rawSchedule = _branch['schedule'];

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

  String _composeAddress(dynamic source) {
    return formatAddressSummary(source);
  }

  String _imageUrl() {
    final urls = _imageUrls();
    return urls.isEmpty ? '' : urls.first;
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

    final rawImages = _branch['imageUrls'];
    if (rawImages is List) {
      for (final image in rawImages) {
        add(image);
      }
    }
    add(_branch['imageUrl']);
    add(_branch['image']);
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

  List<_DetailRowData> _formRows() {
    final address = _branch['address'];
    final addressMap =
        address is Map ? Map<String, dynamic>.from(address) : _branch;
    String addressField(List<String> keys) =>
        _firstText(keys.map((key) => addressMap[key]).toList());

    return [
      _DetailRowData(
          'Branch Name',
          _firstText([
            _branch['name'],
            _branch['branchName'],
            _branch['displayName'],
          ])),
      _DetailRowData(
          'Phone',
          _firstText([
            _branch['phone'],
            _branch['phoneNumber'],
            _branch['contactNumber'],
          ])),
      _DetailRowData(
          'Start Time',
          _formatDisplayTime(_firstText([
            _branch['startTime'],
            _branch['openingTime'],
            _branch['openTime'],
          ]))),
      _DetailRowData(
        'End Time',
        _formatDisplayTime(_firstText([
          _branch['endTime'],
          _branch['closingTime'],
          _branch['closeTime'],
        ])),
      ),
      _DetailRowData(
          'Description',
          _firstText([
            _branch['description'],
            _branch['branchDescription'],
            _branch['about'],
          ])),
      _DetailRowData(
          'Complete Address',
          _firstText([
            _composeAddress(address),
            _composeAddress(_branch),
            addressField(['line1', 'addressLine1', 'buildingName']),
          ])),
      _DetailRowData('House / Flat', addressField(['city'])),
      _DetailRowData(
          'Street / Area', addressField(['postalCode', 'pincode', 'zip'])),
      _DetailRowData('State', addressField(['state'])),
      _DetailRowData(
          'Latitude',
          _firstText([
            addressField(['latitude', 'lat']),
            _branch['latitude'],
            _branch['lat'],
          ])),
      _DetailRowData(
          'Longitude',
          _firstText([
            addressField(['longitude', 'lng', 'lon']),
            _branch['longitude'],
            _branch['lng'],
          ])),
      _DetailRowData(
        'Uploaded Photos',
        _imageUrls().isEmpty ? '' : _imageUrls().length.toString(),
      ),
    ].where((row) => row.value.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _firstText([
      _branch['name'],
      _branch['branchName'],
      _branch['displayName'],
      'Branch Details',
    ]);
    final imageUrl = _imageUrl();
    final openDays =
        _scheduleRows().where((row) => row.value != 'Closed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4EEE7),
      appBar: buildProfileSubpageAppBar(title: translateText('Branch Details')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F4ED), Color(0xFFF3ECE3)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => RefreshFeedback.playAndRun(_loadDetails),
          color: AppColors.starColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeroCard(
                title: title,
                subtitle: translateText('Branch'),
                imageUrl: imageUrl,
                active: _branch['active'] != false,
              ),
              const SizedBox(height: 14),
              _SummaryStrip(
                items: [
                  _SummaryStat(
                      label: 'Services', value: _services.length.toString()),
                  _SummaryStat(
                      label: 'Team', value: _teamMembers.length.toString()),
                  _SummaryStat(label: 'Open Days', value: openDays.toString()),
                ],
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _WarningBox(message: _error!),
              ],
              const SizedBox(height: 14),
              _DetailSection(
                title: 'Branch Form Values',
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
    required this.imageUrl,
    required this.active,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
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
                child: imageUrl.isEmpty
                    ? const _ImageFallback()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImageFallback(),
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
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF8A8178),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        translateText(
                            'Branch overview and live operating info'),
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
