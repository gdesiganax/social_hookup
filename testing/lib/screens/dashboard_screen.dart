import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/post_media_picker.dart';
import '../widgets/profile_status.dart';
import 'member_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.token,
  });

  final User user;
  final String token;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _pageSize = 10;

  final _apiService = ApiService();
  final _postController = TextEditingController();
  final _scrollController = ScrollController();

  List<Profile> _quickMatches = const <Profile>[];
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  PickedPostImage? _selectedImage;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _isPosting = false;
  int _postOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _postOffset = 0;
      _hasMorePosts = true;
    });

    try {
      final profiles = await _apiService.discoveryProfiles();
      final posts = await _apiService.feedPosts(
        widget.token,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _quickMatches = profiles
            .where((Profile profile) => profile.userId != widget.user.id)
            .take(8)
            .toList(growable: false);
        _posts = posts;
        _postOffset = posts.length;
        _hasMorePosts = posts.length == _pageSize;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || _isLoadingMore || !_hasMorePosts) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final nextPosts = await _apiService.feedPosts(
        widget.token,
        limit: _pageSize,
        offset: _postOffset,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = <Map<String, dynamic>>[..._posts, ...nextPosts];
        _postOffset += nextPosts.length;
        _hasMorePosts = nextPosts.length == _pageSize;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showMessage(error.message);
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 420) {
      _loadMorePosts();
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await pickPostImage();
      if (!mounted) {
        return;
      }
      if (image == null) {
        _showMessage('Image upload is available in the web build.');
        return;
      }
      setState(() => _selectedImage = image);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (_isPosting) {
      return;
    }
    if (content.length < 3) {
      _showMessage('Write a little more before posting.');
      return;
    }

    setState(() => _isPosting = true);
    try {
      await _apiService.createPost(
        token: widget.token,
        content: content,
        imageBytes: _selectedImage?.bytes,
        imageFilename: _selectedImage?.name,
        imageMimeType: _selectedImage?.mimeType,
      );
      _postController.clear();
      setState(() => _selectedImage = null);
      await _loadInitial();
      _showMessage('Post published.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(
          profile: profile,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadInitial,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _ErrorState(message: errorMessage, onRetry: _loadInitial);
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Quick matches',
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: _quickMatches.isEmpty
                ? const _EmptyBlock(message: 'No profiles available.')
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickMatches.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final profile = _quickMatches[index];
                      return _QuickMatch(
                        profile: profile,
                        apiService: _apiService,
                        onTap: () => _openProfile(profile),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),
          _PostComposer(
            controller: _postController,
            selectedImage: _selectedImage,
            isPosting: _isPosting,
            onPickImage: _pickImage,
            onRemoveImage: () => setState(() => _selectedImage = null),
            onPost: _createPost,
          ),
          const SizedBox(height: 18),
          Text(
            'Public feed',
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 10),
          if (_posts.isEmpty)
            const _EmptyBlock(message: 'No posts yet.')
          else
            for (final post in _posts)
              _PostTile(
                post: post,
                token: widget.token,
                currentUserId: widget.user.id,
                apiService: _apiService,
              ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_hasMorePosts && _posts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'You are all caught up.',
                  style: TextStyle(color: Color(0xFF6B5961)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickMatch extends StatelessWidget {
  const _QuickMatch({
    required this.profile,
    required this.apiService,
    required this.onTap,
  });

  final Profile profile;
  final ApiService apiService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 86,
        child: Column(
          children: <Widget>[
            ProfileAvatar(
              imageUrl: apiService.resolveMediaUrl(profile.avatarUrl),
              isOnline: profile.isOnline,
              isVerified: profile.hasSubmittedVerification,
              radius: 34,
            ),
            const SizedBox(height: 7),
            Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              profile.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B5961)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  const _PostComposer({
    required this.controller,
    required this.selectedImage,
    required this.isPosting,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onPost,
  });

  final TextEditingController controller;
  final PickedPostImage? selectedImage;
  final bool isPosting;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final image = selectedImage;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share something publicly...',
                border: OutlineInputBorder(),
              ),
            ),
            if (image != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8DCE2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.image, color: Color(0xFFE91E63)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: isPosting ? null : onRemoveImage,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: isPosting ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Picture'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isPosting ? null : onPost,
                  icon: isPosting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatefulWidget {
  const _PostTile({
    required this.post,
    required this.token,
    required this.currentUserId,
    required this.apiService,
  });

  final Map<String, dynamic> post;
  final String token;
  final int currentUserId;
  final ApiService apiService;

  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile> {
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = const <Map<String, dynamic>>[];
  bool _commentsOpen = false;
  bool _loadingComments = false;
  bool _postingComment = false;
  bool _liking = false;
  bool _likedByMe = false;
  late int _likesCount;
  late int _commentsCount;

  int? get _postId => _readInt(widget.post, <String>['id', 'post_id']);

  @override
  void initState() {
    super.initState();
    _likesCount = _readInt(widget.post, <String>['likes_count']) ?? 0;
    _commentsCount = _readInt(widget.post, <String>['comments_count']) ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleComments() async {
    setState(() => _commentsOpen = !_commentsOpen);
    if (_commentsOpen && _comments.isEmpty) {
      await _loadComments();
    }
  }

  Future<void> _loadComments() async {
    final postId = _postId;
    if (postId == null || _loadingComments) {
      return;
    }

    setState(() => _loadingComments = true);
    try {
      final comments = await widget.apiService.postComments(
        token: widget.token,
        postId: postId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _loadingComments = false);
        _showMessage(error.message);
      }
    }
  }

  Future<void> _likePost() async {
    final postId = _postId;
    if (postId == null || _liking || _likedByMe) {
      return;
    }

    setState(() => _liking = true);
    try {
      await widget.apiService.likePost(token: widget.token, postId: postId);
      if (mounted) {
        setState(() {
          _likesCount += 1;
          _likedByMe = true;
          _liking = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _liking = false);
        _showMessage(error.message);
      }
    }
  }

  Future<void> _postComment() async {
    final postId = _postId;
    final body = _commentController.text.trim();
    if (postId == null || body.isEmpty || _postingComment) {
      return;
    }

    setState(() => _postingComment = true);
    try {
      await widget.apiService.createComment(
        token: widget.token,
        postId: postId,
        body: body,
      );
      _commentController.clear();
      final comments = await widget.apiService.postComments(
        token: widget.token,
        postId: postId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsCount += 1;
          _commentsOpen = true;
          _postingComment = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _postingComment = false);
        _showMessage(error.message);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final content = _read(widget.post, <String>['content', 'body', 'text']);
    final author = _read(widget.post, <String>[
      'display_name',
      'username',
      'author_name',
      'email',
    ]);
    final createdAt = _read(widget.post, <String>['created_at', 'updated_at']);
    final avatarUrl = widget.apiService.resolveMediaUrl(
      _read(widget.post, <String>['avatar_url']),
    );
    final mediaUrl = widget.apiService.resolveMediaUrl(
      _read(widget.post, <String>['media_url', 'image_url', 'photo_url']),
    );
    final mediaType = _read(widget.post, <String>['media_type']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ProfileAvatar(
                  imageUrl: avatarUrl,
                  isOnline: _isOnline(widget.post),
                  isVerified:
                      _read(widget.post, <String>['verification_status'])
                          .isNotEmpty,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        author.isEmpty ? 'Member' : author,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      RowStatusBadges(
                        isOnline: _isOnline(widget.post),
                        verificationStatus:
                            _read(widget.post, <String>['verification_status']),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B5961),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content.isEmpty ? widget.post.toString() : content),
            if (mediaUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _PostMedia(mediaUrl: mediaUrl, mediaType: mediaType),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _liking || _likedByMe ? null : _likePost,
                  icon: _liking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _likedByMe ? Icons.favorite : Icons.favorite_border,
                        ),
                  label: Text('$_likesCount likes'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _toggleComments,
                  icon: Icon(
                    _commentsOpen
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                  ),
                  label: Text('$_commentsCount comments'),
                ),
              ],
            ),
            if (_commentsOpen) ...<Widget>[
              const Divider(),
              _buildComments(),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Post comment',
                    onPressed: _postingComment ? null : _postComment,
                    icon: _postingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: const Color(0xFFE91E63),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComments() {
    if (_loadingComments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No comments yet.',
          style: TextStyle(color: Color(0xFF6B5961)),
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final comment in _comments)
          _CommentTile(
            comment: comment,
            apiService: widget.apiService,
          ),
      ],
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({
    required this.mediaUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'video') {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1E7EC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.videocam, size: 44, color: Color(0xFFE91E63)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1E7EC),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, color: Color(0xFFE91E63)),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.apiService,
  });

  final Map<String, dynamic> comment;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final author = _read(comment, <String>['display_name', 'username', 'email']);
    final body = _read(comment, <String>['body', 'content', 'comment']);
    final avatarUrl = apiService.resolveMediaUrl(
      _read(comment, <String>['avatar_url']),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileAvatar(
            imageUrl: avatarUrl,
            isOnline: _isOnline(comment),
            isVerified: _read(comment, <String>['verification_status']).isNotEmpty,
            radius: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F3F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    author.isEmpty ? 'Member' : author,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  RowStatusBadges(
                    isOnline: _isOnline(comment),
                    verificationStatus:
                        _read(comment, <String>['verification_status']),
                  ),
                  const SizedBox(height: 2),
                  Text(body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _read(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}

int? _readInt(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

bool _isOnline(Map<String, dynamic> row) {
  final raw = _read(row, <String>['last_seen_at', 'last_login_at']);
  if (raw.isEmpty) {
    return false;
  }
  final seenAt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (seenAt == null) {
    return false;
  }
  return DateTime.now().difference(seenAt).inMinutes <= 5;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 42, color: Color(0xFFE91E63)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(message)),
    );
  }
}
