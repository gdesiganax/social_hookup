import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

enum GenderFilter {
  everyone,
  female,
  male,
}

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({
    super.key,
    this.isAuthenticated = false,
    this.onLogin,
    this.onOpenDashboard,
    this.onOpenMatches,
    this.onOpenMessages,
    this.onOpenProfile,
    this.onAuthenticated,
  });

  final bool isAuthenticated;
  final VoidCallback? onLogin;
  final VoidCallback? onOpenDashboard;
  final VoidCallback? onOpenMatches;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenProfile;
  final Future<void> Function(AuthResult result)? onAuthenticated;

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _cityController = TextEditingController();

  GenderFilter _genderFilter = GenderFilter.everyone;
  late Future<List<Profile>> _profilesFuture;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  List<Profile> _lastProfiles = const <Profile>[];
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isAnimatingAway = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        setState(() => _dragOffset = _swipeAnimation.value);
      });
    _profilesFuture = _loadProfiles();
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<List<Profile>> _loadProfiles() async {
    final profiles = await _apiService.discoveryProfiles(
      gender: _genderValue,
      city: _cityController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _lastProfiles = profiles;
        _currentIndex = 0;
        _dragOffset = Offset.zero;
      });
    }

    return profiles;
  }

  String? get _genderValue {
    switch (_genderFilter) {
      case GenderFilter.female:
        return 'female';
      case GenderFilter.male:
        return 'male';
      case GenderFilter.everyone:
        return null;
    }
  }

  void _refreshProfiles() {
    setState(() {
      _profilesFuture = _loadProfiles();
    });
  }

  void _goToLogin() {
    if (widget.onLogin != null) {
      widget.onLogin!();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(onAuthenticated: widget.onAuthenticated),
      ),
    );
  }

  void _nextProfile() {
    if (_lastProfiles.isEmpty || _currentIndex >= _lastProfiles.length - 1) {
      return;
    }

    _animateCardAway(const Offset(-520, 24));
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimatingAway) {
      return;
    }

    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimatingAway) {
      return;
    }

    final velocity = details.velocity.pixelsPerSecond;
    final shouldPeelAway =
        _dragOffset.dx.abs() > 110 || velocity.dx.abs() > 700;

    if (shouldPeelAway && _currentIndex < _lastProfiles.length - 1) {
      final direction = (_dragOffset.dx == 0 ? velocity.dx : _dragOffset.dx)
          .sign
          .clamp(-1, 1)
          .toDouble();
      _animateCardAway(Offset(520 * direction, _dragOffset.dy * 0.8));
      return;
    }

    _animateCardBack();
  }

  void _animateCardAway(Offset target) {
    _isAnimatingAway = true;
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _swipeController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _currentIndex =
              (_currentIndex + 1).clamp(0, _lastProfiles.length - 1).toInt();
          _dragOffset = Offset.zero;
          _isAnimatingAway = false;
        });
      });
  }

  void _animateCardBack() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _swipeController
      ..reset()
      ..forward();
  }

  void _openProfile(Profile profile) {
    final connectAction =
        widget.isAuthenticated ? widget.onOpenMatches ?? _goToLogin : _goToLogin;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return _ProfileDetailsSheet(
          profile: profile,
          imageUrl: _apiService.resolveMediaUrl(profile.avatarUrl),
          onLogin: connectAction,
          isAuthenticated: widget.isAuthenticated,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF24141B),
        title: const Text('Discover'),
        actions: <Widget>[
          if (widget.isAuthenticated)
            PopupMenuButton<String>(
              tooltip: 'Menu',
              onSelected: (String value) {
                if (value == 'dashboard') {
                  widget.onOpenDashboard?.call();
                } else if (value == 'matches') {
                  widget.onOpenMatches?.call();
                } else if (value == 'messages') {
                  widget.onOpenMessages?.call();
                } else if (value == 'profile') {
                  widget.onOpenProfile?.call();
                }
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'dashboard',
                    child: Text('Dashboard'),
                  ),
                  PopupMenuItem<String>(
                    value: 'matches',
                    child: Text('Matches'),
                  ),
                  PopupMenuItem<String>(
                    value: 'messages',
                    child: Text('Messages'),
                  ),
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('Profile'),
                  ),
                ];
              },
            )
          else
            TextButton.icon(
              onPressed: _goToLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _FiltersBar(
              genderFilter: _genderFilter,
              cityController: _cityController,
              onGenderChanged: (GenderFilter filter) {
                setState(() => _genderFilter = filter);
                _refreshProfiles();
              },
              onSearch: _refreshProfiles,
            ),
            Expanded(
              child: FutureBuilder<List<Profile>>(
                future: _profilesFuture,
                builder: (BuildContext context,
                    AsyncSnapshot<List<Profile>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _EmptyState(
                      icon: Icons.wifi_off,
                      title: 'Could not load profiles',
                      message: snapshot.error.toString(),
                      buttonText: 'Try again',
                      onPressed: _refreshProfiles,
                    );
                  }

                  final profiles = snapshot.data ?? const <Profile>[];
                  if (profiles.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      title: 'No matches found',
                      message: 'Try a different gender or city.',
                      buttonText: 'Reset filters',
                      onPressed: () {
                        setState(() {
                          _genderFilter = GenderFilter.everyone;
                          _cityController.clear();
                        });
                        _refreshProfiles();
                      },
                    );
                  }

                  final visibleProfiles = profiles.skip(_currentIndex).toList();

                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: _ProfileDeck(
                          profiles: visibleProfiles,
                          dragOffset: _dragOffset,
                          resolveImageUrl: _apiService.resolveMediaUrl,
                          onDragUpdate: _handleDragUpdate,
                          onDragEnd: _handleDragEnd,
                          onTapProfile: _openProfile,
                        ),
                      ),
                      _SwipeActions(
                        index: _currentIndex,
                        count: profiles.length,
                        onPass: _nextProfile,
                        onMeet: widget.isAuthenticated
                            ? widget.onOpenMatches ?? _goToLogin
                            : _goToLogin,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.genderFilter,
    required this.cityController,
    required this.onGenderChanged,
    required this.onSearch,
  });

  final GenderFilter genderFilter;
  final TextEditingController cityController;
  final ValueChanged<GenderFilter> onGenderChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDE2E7)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.tune, size: 18, color: Color(0xFFE91E63)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Who would you like to meet?',
                  style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: onSearch,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GenderSegments(
            selected: genderFilter,
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cityController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'City or nearby area',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F3F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE91E63)),
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderSegments extends StatelessWidget {
  const _GenderSegments({
    required this.selected,
    required this.onChanged,
  });

  final GenderFilter selected;
  final ValueChanged<GenderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _Segment(
          icon: Icons.people_outline,
          label: 'Everyone',
          selected: selected == GenderFilter.everyone,
          onTap: () => onChanged(GenderFilter.everyone),
        ),
        _Segment(
          icon: Icons.female,
          label: 'Women',
          selected: selected == GenderFilter.female,
          onTap: () => onChanged(GenderFilter.female),
        ),
        _Segment(
          icon: Icons.male,
          label: 'Men',
          selected: selected == GenderFilter.male,
          onTap: () => onChanged(GenderFilter.male),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFFE91E63) : const Color(0xFFF8F3F5),
              border: Border.all(
                color: selected
                    ? const Color(0xFFE91E63)
                    : const Color(0xFFE8DCE2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : const Color(0xFF6A4355),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selected ? Colors.white : const Color(0xFF513743),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDeck extends StatelessWidget {
  const _ProfileDeck({
    required this.profiles,
    required this.dragOffset,
    required this.resolveImageUrl,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapProfile,
  });

  final List<Profile> profiles;
  final Offset dragOffset;
  final String Function(String rawUrl) resolveImageUrl;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final ValueChanged<Profile> onTapProfile;

  @override
  Widget build(BuildContext context) {
    final visibleCount = profiles.length < 4 ? profiles.length : 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (var index = visibleCount - 1; index >= 0; index--)
            _DeckProfileCard(
              profile: profiles[index],
              imageUrl: resolveImageUrl(profiles[index].avatarUrl),
              depth: index,
              dragOffset: index == 0 ? dragOffset : Offset.zero,
              isTopCard: index == 0,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
              onTap: () => onTapProfile(profiles[index]),
            ),
        ],
      ),
    );
  }
}

class _DeckProfileCard extends StatelessWidget {
  const _DeckProfileCard({
    required this.profile,
    required this.imageUrl,
    required this.depth,
    required this.dragOffset,
    required this.isTopCard,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTap,
  });

  final Profile profile;
  final String imageUrl;
  final int depth;
  final Offset dragOffset;
  final bool isTopCard;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - (depth * 0.045);
    final yOffset = depth * 18.0;
    final rotation = isTopCard ? dragOffset.dx / 900 : 0.0;
    final opacity = 1 - (depth * 0.08);

    Widget card = Transform.translate(
      offset: isTopCard ? dragOffset : Offset(0, yOffset),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: opacity,
            child: _SwipeProfileCard(
              profile: profile,
              imageUrl: imageUrl,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );

    if (!isTopCard) {
      return Positioned.fill(child: IgnorePointer(child: card));
    }

    return Positioned.fill(
      child: GestureDetector(
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        child: card,
      ),
    );
  }
}

class _SwipeProfileCard extends StatelessWidget {
  const _SwipeProfileCard({
    required this.profile,
    required this.imageUrl,
    required this.onTap,
  });

  final Profile profile;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 14,
      shadowColor: const Color(0x55351A26),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _ProfileImage(imageUrl: imageUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x05000000),
                    Color(0x22000000),
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _Badge(
                icon: Icons.place,
                label: profile.city,
              ),
            ),
            if (profile.isFeatured)
              const Positioned(
                top: 18,
                right: 18,
                child: _Badge(
                  icon: Icons.local_fire_department,
                  label: 'Featured',
                ),
              ),
            if (profile.isOnline)
              Positioned(
                top: profile.isFeatured ? 58 : 18,
                right: 18,
                child: const _OnlineIndicator(),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '${profile.displayName}, ${profile.age}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (profile.isVerified) ...<Widget>[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF64D2FF),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEFE7EA),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _ImageFallback();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const _ImageFallback();
      },
      errorBuilder: (_, __, ___) => const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAD9E1),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Color(0xFF9B5A76),
          size: 86,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: const Color(0xFFE91E63)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF351A26),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActions extends StatelessWidget {
  const _SwipeActions({
    required this.index,
    required this.count,
    required this.onPass,
    required this.onMeet,
  });

  final int index;
  final int count;
  final VoidCallback onPass;
  final VoidCallback onMeet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Pass',
            onPressed: index >= count - 1 ? null : onPass,
            iconSize: 32,
            icon: const Icon(Icons.close),
            color: const Color(0xFF6B5961),
          ),
          Expanded(
            child: Text(
              '${index + 1} of $count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B5961),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onMeet,
              icon: const Icon(Icons.favorite),
              label: const Text('Meet'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailsSheet extends StatelessWidget {
  const _ProfileDetailsSheet({
    required this.profile,
    required this.imageUrl,
    required this.onLogin,
    required this.isAuthenticated,
  });

  final Profile profile;
  final String imageUrl;
  final VoidCallback onLogin;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: _ProfileImage(imageUrl: imageUrl),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${profile.displayName}, ${profile.age}',
              style: Theme.of(context).textTheme.headline5?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text('@${profile.username} - ${profile.city}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (profile.isOnline)
                  const _StatusPill(
                    icon: Icons.circle,
                    label: 'Online',
                    color: Color(0xFF18B857),
                  ),
                if (profile.hasSubmittedVerification)
                  _StatusPill(
                    icon: Icons.verified,
                    label: profile.isVerified
                        ? 'Verified'
                        : 'Verification submitted',
                    color: const Color(0xFF1DA1F2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(profile.bio),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLogin();
                },
                icon: Icon(isAuthenticated ? Icons.favorite : Icons.login),
                label: Text(isAuthenticated ? 'Open matches' : 'Login to connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineIndicator extends StatelessWidget {
  const _OnlineIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.circle, size: 12, color: Color(0xFF18B857)),
            SizedBox(width: 5),
            Text(
              'Online',
              style: TextStyle(
                color: Color(0xFF166A36),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 54, color: const Color(0xFFE91E63)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B5961)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
