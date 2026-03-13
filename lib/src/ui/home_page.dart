import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/rss_controller.dart';
import '../models.dart';
import 'article_web_view.dart';

class ReadRssHomePage extends StatefulWidget {
  const ReadRssHomePage({super.key, required this.controller});

  final RssController controller;

  @override
  State<ReadRssHomePage> createState() => _ReadRssHomePageState();
}

class _ReadRssHomePageState extends State<ReadRssHomePage> {
  RssController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                theme.colorScheme.surface,
                theme.colorScheme.primary.withValues(alpha: 0.14),
                theme.colorScheme.secondary.withValues(alpha: 0.12),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 1160;
                    return Padding(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      child: isDesktop
                          ? _buildDesktopLayout(context)
                          : _buildMobileLayout(context),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _buildArticlesPanel(context)),
        const SizedBox(width: 12),
        SizedBox(width: 92, child: _buildQuickRail(context, vertical: true)),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: _buildQuickRail(context, vertical: false),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildArticlesPanel(context)),
      ],
    );
  }

  Widget _buildQuickRail(BuildContext context, {required bool vertical}) {
    final selectedTitle = controller.selectedFeed?.title ?? 'Tất cả';
    final unreadCount = controller.unreadCount;
    final feedCount = controller.feeds.length;
    final isMobileCompact = !vertical;

    final summary = _BrandLogoCard(
      vertical: vertical,
      mobileCompact: isMobileCompact,
      selectedTitle: selectedTitle,
      feedCount: feedCount,
      unreadCount: unreadCount,
    );

    final menuButton = Tooltip(
      message: 'Feed và cài đặt',
      child: IconButton.filled(
        onPressed: () => _showControlsSheet(context),
        icon: const Icon(Icons.dashboard_customize_outlined),
      ),
    );
    final addButton = Tooltip(
      message: 'Thêm feed',
      child: IconButton.filledTonal(
        onPressed: _showAddFeedDialog,
        icon: const Icon(Icons.add),
      ),
    );
    final refreshButton = Tooltip(
      message: 'Làm mới',
      child: IconButton.filledTonal(
        onPressed: controller.hasFeeds && !controller.isRefreshing
            ? () async {
                await controller.refreshAll();
              }
            : null,
        icon: const Icon(Icons.refresh),
      ),
    );

    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 8 : 6,
        vertical: vertical ? 10 : 6,
      ),
      child: vertical
          ? Column(
              children: <Widget>[
                summary,
                const SizedBox(height: 8),
                menuButton,
                const SizedBox(height: 6),
                addButton,
                const SizedBox(height: 6),
                refreshButton,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                summary,
                const SizedBox(width: 6),
                menuButton,
                addButton,
                refreshButton,
              ],
            ),
    );
  }

  Widget _buildFeedPanel(BuildContext context) {
    final theme = Theme.of(context);
    final allCount = controller.feeds.fold<int>(
      0,
      (total, feed) => total + controller.articleCountForFeed(feed.id),
    );
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent Feeds',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showAddFeedDialog,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FeedSelectorTile(
            isActive: controller.selectedFeedId == RssController.allFeedsId,
            title: 'Tất cả bài mới',
            subtitle: 'Tổng hợp tất cả feed theo thời gian mới nhất',
            trailing: '$allCount',
            onTap: () => controller.setSelectedFeed(RssController.allFeedsId),
          ),
          const SizedBox(height: 12),
          if (controller.feeds.isEmpty)
            Text(
              'Chưa có nguồn RSS nào. Thêm nguồn đầu tiên để bắt đầu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          else
            ...controller.feeds.map(
              (feed) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeedSelectorTile(
                  isActive: controller.selectedFeedId == feed.id,
                  title: feed.title,
                  subtitle: feed.lastError != null
                      ? feed.lastError!
                      : _describeFeedStatus(feed),
                  trailing: '${controller.articleCountForFeed(feed.id)}',
                  onTap: () => controller.setSelectedFeed(feed.id),
                  menu: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showEditFeedDialog(feed);
                      } else if (value == 'refresh') {
                        await controller.refreshFeed(feed.id);
                      } else if (value == 'remove') {
                        final message = await controller.removeFeed(feed.id);
                        if (mounted) {
                          _showSnack(message);
                        }
                      }
                    },
                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Sửa chu kỳ làm mới'),
                      ),
                      PopupMenuItem<String>(
                        value: 'refresh',
                        child: Text('Làm mới feed'),
                      ),
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Text('Xóa feed'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticlesPanel(BuildContext context, {bool shrinkWrap = false}) {
    final theme = Theme.of(context);
    final articles = controller.visibleArticles;
    final widgets = articles.isEmpty
        ? <Widget>[_buildEmptyState(context)]
        : _buildArticleWidgets(articles);

    final contentChildren = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              controller.selectedFeed?.title ?? 'Recent Feeds',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _DisplayModePicker(
            current: controller.settings.displayMode,
            onChanged: (mode) => controller.setDisplayMode(mode),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            _FilterChipButton(
              active: controller.selectedFeedId == RssController.allFeedsId,
              label: 'All recent',
              onTap: () => controller.setSelectedFeed(RssController.allFeedsId),
            ),
            ...controller.feeds.map(
              (feed) => Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _FilterChipButton(
                  active: controller.selectedFeedId == feed.id,
                  label: feed.title,
                  onTap: () => controller.setSelectedFeed(feed.id),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];

    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!shrinkWrap && controller.isRefreshing)
            const LinearProgressIndicator(minHeight: 3),
          ...contentChildren,
          if (shrinkWrap)
            ..._withSpacing(widgets, 14)
          else
            Expanded(
              child: ListView.separated(
                itemCount: widgets.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) => widgets[index],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cài đặt và đồng bộ',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thông báo tin mới'),
            subtitle: Text(controller.notificationAccess.label),
            value: controller.settings.notificationsEnabled,
            onChanged: (value) {
              _handleAsync(() => controller.setNotificationsEnabled(value));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AdBlock khi đọc'),
            subtitle: const Text('Loại bỏ iframe, script và khung quảng cáo.'),
            value: controller.settings.adBlockEnabled,
            onChanged: (value) {
              controller.setAdBlockEnabled(value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto refresh'),
            subtitle: const Text(
              'Tự động kiểm tra feed theo chu kỳ của từng nguồn.',
            ),
            value: controller.settings.autoRefreshEnabled,
            onChanged: (value) {
              controller.setAutoRefreshEnabled(value);
            },
          ),
          const SizedBox(height: 12),
          Text('Giao diện', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            multiSelectionEnabled: false,
            showSelectedIcon: false,
            selected: <ThemeMode>{controller.settings.themeMode},
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('Auto'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Sáng'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Tối'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            onSelectionChanged: (selection) {
              controller.setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _copySyncLink,
                icon: const Icon(Icons.link),
                label: const Text('Sao chép link'),
              ),
              FilledButton.tonalIcon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Nhập link'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _handleAsync(controller.backupToDiscord),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Backup Discord'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPanel(BuildContext context) {
    final theme = Theme.of(context);
    final articles = controller.sideArticles;
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            controller.selectedFeed?.title ?? 'Recent in Feed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (articles.isEmpty)
            Text(
              'Chưa có bài viết nào được tải.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          else
            ...articles
                .take(6)
                .map(
                  (article) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openReader(article),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.04,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              article.feedTitle,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              article.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _friendlyDate(article.publishedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  List<Widget> _buildArticleWidgets(List<NewsItem> articles) {
    switch (controller.settings.displayMode) {
      case FeedDisplayMode.spotlight:
        return <Widget>[
          _SpotlightCard(
            article: articles.first,
            unread: controller.isArticleUnread(articles.first.id),
            onTap: () => _openReader(articles.first),
            onOpenOriginal: () =>
                controller.openOriginalArticle(articles.first.link),
          ),
          ...articles
              .skip(1)
              .map(
                (article) => _CompactArticleTile(
                  article: article,
                  unread: controller.isArticleUnread(article.id),
                  onTap: () => _openReader(article),
                ),
              ),
        ];
      case FeedDisplayMode.headlines:
        return articles
            .map(
              (article) => _HeadlineTile(
                article: article,
                unread: controller.isArticleUnread(article.id),
                onTap: () => _openReader(article),
              ),
            )
            .toList();
      case FeedDisplayMode.cards:
        return articles
            .map(
              (article) => _ArticleCard(
                article: article,
                unread: controller.isArticleUnread(article.id),
                onTap: () => _openReader(article),
              ),
            )
            .toList();
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Chưa có nguồn RSS nào',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thêm URL RSS để hiển thị tin mới nhất, sắp xếp theo thời gian, nhận thông báo khi có bài mới và đọc ngay trong overlay.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _showAddFeedDialog,
            icon: const Icon(Icons.add),
            label: const Text('Thêm nguồn đầu tiên'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAsync(Future<String> Function() action) async {
    try {
      final message = await action();
      if (mounted) {
        _showSnack(message);
      }
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString(), isError: true);
      }
    }
  }

  Future<void> _showAddFeedDialog() async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddFeedDialog(controller: controller),
    );
    if (!mounted || message == null) {
      return;
    }
    _showSnack(message);
  }

  Future<void> _showImportDialog() async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ImportSyncDialog(controller: controller),
    );
    if (!mounted || message == null) {
      return;
    }
    _showSnack(message);
  }

  Future<void> _showEditFeedDialog(FeedSource feed) async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditFeedDialog(controller: controller, feed: feed),
    );
    if (!mounted || message == null) {
      return;
    }
    _showSnack(message);
  }

  Future<void> _copySyncLink() async {
    final link = controller.buildSyncLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      _showSnack('Đã sao chép link đồng bộ vào clipboard.');
    }
  }

  Future<void> _showControlsSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    if (screenSize.width >= 1160) {
      final panelWidth = (screenSize.width * 0.28).clamp(320.0, 380.0);
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.16),
        builder: (dialogContext) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
                child: SizedBox(
                  width: panelWidth,
                  height: screenSize.height * 0.9,
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildControlsSheetContent(
                        dialogContext,
                        onClose: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildControlsSheetContent(
                  context,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsSheetContent(
    BuildContext context, {
    required VoidCallback onClose,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final panelChildren = <Widget>[
          _buildFeedPanel(context),
          const SizedBox(height: 16),
          _buildControlsPanel(context),
          const SizedBox(height: 16),
          _buildRecentPanel(context),
        ];
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Thiết đặt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: panelChildren)),
          ],
        );
      },
    );
  }

  Future<void> _openReader(NewsItem article) async {
    controller.markArticleRead(article.id);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => ArticleReaderDialog(
        article: article,
        onOpenOriginal: () => controller.openOriginalArticle(article.link),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        content: Text(
          message
              .replaceFirst('StateError: ', '')
              .replaceFirst('FormatException: ', ''),
        ),
      ),
    );
  }

  String _describeFeedStatus(FeedSource feed) {
    final interval = _formatRefreshInterval(feed.refreshInterval);
    if (feed.lastFetchedAt == null) {
      return 'Chưa tải dữ liệu • $interval';
    }
    return 'Cập nhật ${_friendlyDate(feed.lastFetchedAt!)} • $interval';
  }

  List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) {
      return widgets;
    }
    final result = <Widget>[];
    for (var index = 0; index < widgets.length; index++) {
      if (index > 0) {
        result.add(SizedBox(height: spacing));
      }
      result.add(widgets[index]);
    }
    return result;
  }
}

class AddFeedDialog extends StatefulWidget {
  const AddFeedDialog({super.key, required this.controller});

  final RssController controller;

  @override
  State<AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<AddFeedDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  int _intervalMinutes = 15;
  FeedPreview? _preview;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: const Text('Add Feed'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      hintText: 'VnExpress',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ RSS',
                      hintText: 'https://vnexpress.net/rss/tin-moi-nhat.rss',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    initialValue: _intervalMinutes,
                    decoration: const InputDecoration(labelText: 'Làm mới'),
                    items: _buildRefreshIntervalItems(_intervalMinutes),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _intervalMinutes = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _loadPreview,
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: const Text('Kiểm tra nguồn'),
                ),
                if (_preview != null) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Last updated: ${_preview!.fetchedAt.toLocal()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.04),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _preview == null
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: Text('Preview bài viết mới nhất sẽ hiển ở đây.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        Text(
                          _preview!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ..._preview!.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('• ${item.title}'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Thêm nguồn'),
        ),
      ],
    );
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final preview = await widget.controller.previewFeed(_urlController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = preview.title;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('StateError: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final message = await widget.controller.addFeed(
        title: _titleController.text,
        url: _urlController.text,
        refreshInterval: Duration(minutes: _intervalMinutes),
        preview: _preview,
      );
      if (mounted) {
        Navigator.of(context).pop(message);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('StateError: ', '');
          _isLoading = false;
        });
      }
    }
  }
}

class EditFeedDialog extends StatefulWidget {
  const EditFeedDialog({
    super.key,
    required this.controller,
    required this.feed,
  });

  final RssController controller;
  final FeedSource feed;

  @override
  State<EditFeedDialog> createState() => _EditFeedDialogState();
}

class _EditFeedDialogState extends State<EditFeedDialog> {
  late int _intervalMinutes = widget.feed.refreshInterval.inMinutes;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: const Text('Sửa chu kỳ làm mới'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.feed.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.feed.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: _intervalMinutes,
              decoration: const InputDecoration(labelText: 'Làm mới'),
              items: _buildRefreshIntervalItems(_intervalMinutes),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _intervalMinutes = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Chu kỳ hiện tại: ${_formatRefreshInterval(Duration(minutes: _intervalMinutes))}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final message = await widget.controller.updateFeedRefreshInterval(
        widget.feed.id,
        Duration(minutes: _intervalMinutes),
      );
      if (mounted) {
        Navigator.of(context).pop(message);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('StateError: ', '');
          _isSaving = false;
        });
      }
    }
  }
}

class ImportSyncDialog extends StatefulWidget {
  const ImportSyncDialog({super.key, required this.controller});

  final RssController controller;

  @override
  State<ImportSyncDialog> createState() => _ImportSyncDialogState();
}

class _ImportSyncDialogState extends State<ImportSyncDialog> {
  final _linkController = TextEditingController();
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: const Text('Nhập link đồng bộ'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Dán full URL hoặc chuỗi sync=... để phục hồi danh sách feed và thiết đặt.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _linkController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'https://domain/#sync=...',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isImporting ? null : _import,
          child: const Text('Nhập dữ liệu'),
        ),
      ],
    );
  }

  Future<void> _import() async {
    setState(() {
      _isImporting = true;
      _error = null;
    });
    try {
      final message = await widget.controller.importSyncLink(
        _linkController.text,
      );
      if (mounted) {
        Navigator.of(context).pop(message);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('FormatException: ', '');
          _isImporting = false;
        });
      }
    }
  }
}

class ArticleReaderDialog extends StatelessWidget {
  const ArticleReaderDialog({
    super.key,
    required this.article,
    required this.onOpenOriginal,
  });

  final NewsItem article;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLink = article.link.trim().isNotEmpty;
    final readerUrl = hasLink ? _buildOverlayReaderUrl(article.link) : null;
    final canEmbedWeb = readerUrl != null;
    final summary = article.summary.trim();
    final content = article.content.trim();
    final hasSummary = summary.isNotEmpty;
    final hasContent = content.isNotEmpty;
    final showDetailSection =
        hasContent &&
        _normalizeReaderText(content) != _normalizeReaderText(summary);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        article.feedTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (article.author != null && article.author!.trim().isNotEmpty)
                  Chip(label: Text(article.author!)),
                Chip(label: Text(_friendlyDate(article.publishedAt))),
                if (canEmbedWeb)
                  const Chip(label: Text('Đang mở trang gốc trong overlay')),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: canEmbedWeb
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: ArticleWebView(url: readerUrl)),
                        const SizedBox(height: 10),
                        Text(
                          'Nếu trang này chặn iframe và hiện trống/trang lỗi, dùng "Mở tab mới" để xem bản gốc.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (hasLink)
                            Text(
                              'Không thể mở trang này trong overlay, app đang hiển thị nội dung RSS thay thế.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          if (hasLink) const SizedBox(height: 14),
                          if (article.imageUrl != null) ...<Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.network(
                                article.imageUrl!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasSummary) ...<Widget>[
                            Text(
                              'Tóm tắt',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              summary,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (showDetailSection) ...<Widget>[
                            Text(
                              'Chi tiết',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.7,
                              ),
                            ),
                          ],
                          if (!hasSummary && !hasContent)
                            SelectableText(
                              'Feed này không cung cấp nội dung đầy đủ. Hãy mở bài gốc để xem thêm.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.7,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onOpenOriginal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở tab mới'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              blurRadius: 48,
              offset: const Offset(0, 26),
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _BrandLogoCard extends StatelessWidget {
  const _BrandLogoCard({
    required this.vertical,
    required this.mobileCompact,
    required this.selectedTitle,
    required this.feedCount,
    required this.unreadCount,
  });

  final bool vertical;
  final bool mobileCompact;
  final String selectedTitle;
  final int feedCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const lightBlue = Color(0xFFCFE3F4);
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFF6F96B3)
        : lightBlue;

    return Container(
      constraints: BoxConstraints(
        minWidth: vertical ? 0 : (mobileCompact ? 58 : 180),
        maxWidth: vertical ? 72 : (mobileCompact ? 64 : 220),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 8 : (mobileCompact ? 6 : 12),
        vertical: vertical ? 12 : (mobileCompact ? 7 : 10),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(mobileCompact ? 18 : 20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[background, background.withValues(alpha: 0.92)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 10),
            color: background.withValues(alpha: 0.32),
          ),
        ],
      ),
      child: vertical
          ? Column(
              children: <Widget>[
                const _RssNewsHubLogo(compact: true),
                const SizedBox(height: 10),
                Text(
                  '$feedCount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'feed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 0.6,
                  ),
                ),
                if (unreadCount > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      '$unreadCount mới',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : mobileCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _RssNewsHubLogo(compact: true, mobileMini: true),
                if (unreadCount > 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '$unreadCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '$feedCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _RssNewsHubLogo(compact: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'RSS NEWS HUB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selectedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        unreadCount > 0
                            ? '$feedCount feed • $unreadCount mới'
                            : '$feedCount feed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RssNewsHubLogo extends StatelessWidget {
  const _RssNewsHubLogo({required this.compact, this.mobileMini = false});

  final bool compact;
  final bool mobileMini;

  @override
  Widget build(BuildContext context) {
    final markSize = mobileMini ? 28.0 : (compact ? 42.0 : 48.0);
    final bookSize = mobileMini ? 18.0 : (compact ? 26.0 : 30.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: markSize,
          height: markSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: 0,
                child: SizedBox(
                  width: markSize,
                  height: markSize * 0.55,
                  child: const CustomPaint(
                    painter: _RssSignalPainter(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: markSize * 0.3,
                child: Container(
                  width: compact ? 8 : 10,
                  height: compact ? 8 : 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: bookSize,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (!mobileMini) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            compact ? 'RSS HUB' : 'RSS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
        if (!compact && !mobileMini)
          Text(
            'NEWS HUB',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 1.0,
            ),
          ),
      ],
    );
  }
}

class _RssSignalPainter extends CustomPainter {
  const _RssSignalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.11;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.92);
    final outer = Rect.fromCircle(center: center, radius: size.width * 0.34);
    final inner = Rect.fromCircle(center: center, radius: size.width * 0.2);

    canvas.drawArc(outer, 4.02, 1.38, false, paint);
    canvas.drawArc(inner, 4.0, 1.42, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RssSignalPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FeedSelectorTile extends StatelessWidget {
  const _FeedSelectorTile({
    required this.isActive,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.menu,
  });

  final bool isActive;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.onSurface.withValues(alpha: 0.04),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.66,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(trailing, style: theme.textTheme.titleSmall),
              if (menu != null) ...<Widget>[const SizedBox(width: 4), menu!],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.active,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: active
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DisplayModePicker extends StatelessWidget {
  const _DisplayModePicker({required this.current, required this.onChanged});

  final FeedDisplayMode current;
  final ValueChanged<FeedDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FeedDisplayMode>(
      multiSelectionEnabled: false,
      showSelectedIcon: false,
      selected: <FeedDisplayMode>{current},
      segments: FeedDisplayMode.values
          .map(
            (mode) => ButtonSegment<FeedDisplayMode>(
              value: mode,
              label: Text(mode.label),
            ),
          )
          .toList(),
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.unread,
    required this.onTap,
  });

  final NewsItem article;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          border: Border.all(
            color: unread
                ? theme.colorScheme.secondary.withValues(alpha: 0.35)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          article.feedTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _friendlyDate(article.publishedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.teaser,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            if (article.imageUrl != null) ...<Widget>[
              const SizedBox(width: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  article.imageUrl!,
                  width: 160,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactArticleTile extends StatelessWidget {
  const _CompactArticleTile({
    required this.article,
    required this.unread,
    required this.onTap,
  });

  final NewsItem article;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${article.feedTitle} • ${_friendlyDate(article.publishedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
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

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.article,
    required this.unread,
    required this.onTap,
    required this.onOpenOriginal,
  });

  final NewsItem article;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              theme.colorScheme.primary.withValues(alpha: 0.16),
              theme.colorScheme.secondary.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                if (unread) const SizedBox(width: 10),
                Text(
                  article.feedTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _friendlyDate(article.publishedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              article.teaser,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  article.imageUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onOpenOriginal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở bài gốc'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadlineTile extends StatelessWidget {
  const _HeadlineTile({
    required this.article,
    required this.unread,
    required this.onTap,
  });

  final NewsItem article;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(article.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '${article.feedTitle} • ${_friendlyDate(article.publishedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

String _friendlyDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Hôm nay $hh:$mm';
  }
  final year = local.year == now.year ? '' : '/${local.year}';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}$year $hh:$mm';
}

bool _isKnownIframeBlockedHost(String rawUrl) {
  final host = Uri.tryParse(rawUrl)?.host.toLowerCase();
  if (host == null || host.isEmpty) {
    return false;
  }
  return host == 'vnexpress.net' || host.endsWith('.vnexpress.net');
}

String _normalizeReaderText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String? _buildOverlayReaderUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  if (_isKnownIframeBlockedHost(rawUrl)) {
    return null;
  }
  return rawUrl;
}

List<DropdownMenuItem<int>> _buildRefreshIntervalItems(int currentMinutes) {
  final values = <int>{5, 15, 30, 60, 180, 360, 720, 1440, currentMinutes}
    ..removeWhere((value) => value <= 0);
  final sorted = values.toList()..sort();
  return sorted
      .map(
        (minutes) => DropdownMenuItem<int>(
          value: minutes,
          child: Text(_formatRefreshInterval(Duration(minutes: minutes))),
        ),
      )
      .toList();
}

String _formatRefreshInterval(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) {
    return 'Mỗi $minutes phút';
  }
  if (minutes % (24 * 60) == 0) {
    final days = minutes ~/ (24 * 60);
    return days == 1 ? 'Mỗi 1 ngày' : 'Mỗi $days ngày';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? 'Mỗi 1 giờ' : 'Mỗi $hours giờ';
  }
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  return 'Mỗi ${hours}g ${remainMinutes}p';
}
