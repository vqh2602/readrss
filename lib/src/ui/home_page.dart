import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/rss_controller.dart';
import '../models.dart';

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.primary.withOpacity(0.14),
            theme.colorScheme.secondary.withOpacity(0.12),
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
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 8,
          child: Column(
            children: <Widget>[
              _buildHeader(context, compact: false),
              const SizedBox(height: 18),
              Expanded(child: _buildArticlesPanel(context)),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 360,
          child: Column(
            children: <Widget>[
              _buildFeedPanel(context),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    _buildControlsPanel(context),
                    const SizedBox(height: 18),
                    _buildRecentPanel(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      children: <Widget>[
        _buildHeader(context, compact: true),
        const SizedBox(height: 16),
        _buildFeedPanel(context),
        const SizedBox(height: 16),
        _buildArticlesPanel(context, shrinkWrap: true),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final allCount = controller.feeds.fold<int>(
      0,
      (total, feed) => total + controller.articleCountForFeed(feed.id),
    );
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ReadRSS', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Web doc RSS hien dai, de them nguon, de doc, co auto refresh, thong bao, sao luu va dong bo bang link.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _showAddFeedDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Them nguon'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.hasFeeds && !controller.isRefreshing
                        ? () async {
                            await controller.refreshAll();
                          }
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Lam moi'),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _showControlsSheet(context),
                    icon: const Icon(Icons.tune),
                    tooltip: 'Cai dat',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricChip(
                icon: Icons.rss_feed_rounded,
                label: '${controller.feeds.length} nguon',
              ),
              _MetricChip(
                icon: Icons.article_outlined,
                label: '$allCount bai da tai',
              ),
              _MetricChip(
                icon: Icons.notifications_active_outlined,
                label: '${controller.unreadCount} tin moi',
              ),
              _MetricChip(
                icon: controller.settings.autoRefreshEnabled
                    ? Icons.schedule
                    : Icons.pause_circle_outline,
                label: controller.settings.autoRefreshEnabled
                    ? 'Auto refresh bat'
                    : 'Auto refresh tat',
              ),
            ],
          ),
          if (controller.lastStatus != null) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              controller.lastStatus!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.66),
              ),
            ),
          ],
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
                child: Text('Recent Feeds', style: theme.textTheme.titleLarge),
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
            title: 'Tat ca bai moi',
            subtitle: 'Tong hop tat ca feed theo thoi gian moi nhat',
            trailing: '$allCount',
            onTap: () => controller.setSelectedFeed(RssController.allFeedsId),
          ),
          const SizedBox(height: 12),
          if (controller.feeds.isEmpty)
            Text(
              'Chua co nguon RSS nao. Them nguon dau tien de bat dau.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                      if (value == 'refresh') {
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
                        value: 'refresh',
                        child: Text('Lam moi feed'),
                      ),
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Text('Xoa feed'),
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
              style: theme.textTheme.titleLarge,
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
          Text('Cai dat va dong bo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thong bao tin moi'),
            subtitle: Text(controller.notificationAccess.label),
            value: controller.settings.notificationsEnabled,
            onChanged: (value) {
              _handleAsync(() => controller.setNotificationsEnabled(value));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AdBlock khi doc'),
            subtitle: const Text('Loai bot iframe, script va khung quang cao.'),
            value: controller.settings.adBlockEnabled,
            onChanged: (value) {
              controller.setAdBlockEnabled(value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto refresh'),
            subtitle: const Text(
              'Tu dong kiem tra feed theo chu ky cua tung nguon.',
            ),
            value: controller.settings.autoRefreshEnabled,
            onChanged: (value) {
              controller.setAutoRefreshEnabled(value);
            },
          ),
          const SizedBox(height: 12),
          Text('Giao dien', style: theme.textTheme.titleMedium),
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
                label: Text('Sang'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Toi'),
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
                label: const Text('Sao chep link'),
              ),
              FilledButton.tonalIcon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Nhap link'),
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
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (articles.isEmpty)
            Text(
              'Chua co bai viet nao duoc tai.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                          color: theme.colorScheme.onSurface.withOpacity(0.04),
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
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
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
        color: theme.colorScheme.onSurface.withOpacity(0.04),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Chua co nguon RSS nao', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Them URL RSS de hien thi tin moi nhat, sap xep theo thoi gian, nhan thong bao khi co bai moi va doc ngay trong overlay.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _showAddFeedDialog,
            icon: const Icon(Icons.add),
            label: const Text('Them nguon dau tien'),
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

  Future<void> _copySyncLink() async {
    final link = controller.buildSyncLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      _showSnack('Da sao chep link dong bo vao clipboard.');
    }
  }

  Future<void> _showControlsSheet(BuildContext context) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  _buildControlsPanel(context),
                  const SizedBox(height: 16),
                  _buildRecentPanel(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReader(NewsItem article) async {
    controller.markArticleRead(article.id);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
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
    if (feed.lastFetchedAt == null) {
      return 'Chua tai du lieu';
    }
    return 'Cap nhat ${_friendlyDate(feed.lastFetchedAt!)}';
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
                      labelText: 'Tieu de',
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
                      labelText: 'Dia chi RSS',
                      hintText: 'https://vnexpress.net/rss/tin-moi-nhat.rss',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    value: _intervalMinutes,
                    decoration: const InputDecoration(labelText: 'Lam moi'),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(value: 5, child: Text('Moi 5 phut')),
                      DropdownMenuItem(value: 15, child: Text('Moi 15 phut')),
                      DropdownMenuItem(value: 30, child: Text('Moi 30 phut')),
                      DropdownMenuItem(value: 60, child: Text('Moi 1 gio')),
                      DropdownMenuItem(value: 180, child: Text('Moi 3 gio')),
                    ],
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
                  label: const Text('Kiem tra nguon'),
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
                ).colorScheme.onSurface.withOpacity(0.04),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _preview == null
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: Text('Preview bai viet moi nhat se hien o day.'),
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
          child: const Text('Huy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Them nguon'),
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
      title: const Text('Nhap link dong bo'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Dan full URL hoac chuoi sync=... de phuc hoi danh sach feed va thiet dat.',
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
          child: const Text('Huy'),
        ),
        FilledButton(
          onPressed: _isImporting ? null : _import,
          child: const Text('Nhap du lieu'),
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
    final body = article.content.isNotEmpty
        ? article.content
        : (article.summary.isNotEmpty
              ? article.summary
              : 'Feed nay khong cung cap noi dung day du. Hay mo bai goc de xem them.');

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
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
                        style: theme.textTheme.headlineMedium,
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
              ],
            ),
            const SizedBox(height: 18),
            if (article.imageUrl != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  article.imageUrl!,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onOpenOriginal,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mo bai goc'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dong'),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: theme.colorScheme.surface.withOpacity(0.78),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 48,
            offset: const Offset(0, 26),
            color: theme.colorScheme.primary.withOpacity(0.12),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.onSurface.withOpacity(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.14)
              : theme.colorScheme.onSurface.withOpacity(0.04),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.onSurface.withOpacity(0.06),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.66),
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
              : theme.colorScheme.onSurface.withOpacity(0.04),
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
          color: theme.colorScheme.onSurface.withOpacity(0.04),
          border: Border.all(
            color: unread
                ? theme.colorScheme.secondary.withOpacity(0.35)
                : theme.colorScheme.onSurface.withOpacity(0.06),
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
                          ),
                        ),
                      ),
                      Text(
                        _friendlyDate(article.publishedAt),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(article.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    article.teaser,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
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
          color: theme.colorScheme.onSurface.withOpacity(0.04),
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
                    : theme.colorScheme.onSurface.withOpacity(0.18),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.62),
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
              theme.colorScheme.primary.withOpacity(0.16),
              theme.colorScheme.secondary.withOpacity(0.12),
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
                Text(article.feedTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(_friendlyDate(article.publishedAt)),
              ],
            ),
            const SizedBox(height: 16),
            Text(article.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              article.teaser,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
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
                label: const Text('Mo bai goc'),
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
          color: theme.colorScheme.onSurface.withOpacity(0.03),
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
                    : theme.colorScheme.onSurface.withOpacity(0.18),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
    return 'Hom nay $hh:$mm';
  }
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $hh:$mm';
}
