import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/network/http.dart';
import 'package:haka_comic/network/models.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/log.dart';
import 'package:haka_comic/utils/request/request.dart';
import 'package:haka_comic/utils/ui.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/widgets/error_page.dart';
import 'package:haka_comic/widgets/ui_image.dart';

class Categories extends StatefulWidget {
  const Categories({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<Categories> createState() => _CategoriesState();
}

const extraMenus = [
  {"title": "排行榜", "path": "/rank", "icon": "assets/images/leaderboard.jpg"},
  {
    "title": "留言板",
    "path": "/comments/5822a6e3ad7ede654696e482",
    "icon": "assets/images/forum.jpg",
  },
  {"title": "最近更新", "path": "/comics", "icon": "assets/images/latest.jpg"},
  {"title": "随机本子", "path": "/random", "icon": "assets/images/random.jpg"},
];

class _CategoriesState extends State<Categories> with RequestMixin {
  final handler = fetchCategories.useRequest(
    onSuccess: (data) {
      Log.i('Fetch categories success', data);
    },
    onError: (e) {
      Log.e('Fetch categories failed', error: e);
    },
  );

  @override
  List<RequestHandler> registerHandler() => [handler];

  @override
  Widget build(BuildContext context) {
    return switch (handler.state) {
      Success(:final data) => Padding(
        padding: .only(top: context.top),
        child: _buildCategoryList(data.categories),
      ),
      Error(:final error) => ErrorPage(
        errorMessage: error.toString(),
        onRetry: handler.refresh,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildCategoryList(List<Category> categories) {
    final visibleExtraMenus = List.of(extraMenus);
    final visibleCategories = List<Category>.of(categories);
    if (AppConf().visibleCategories.isNotEmpty) {
      visibleExtraMenus.removeWhere(
        (item) => !AppConf().visibleCategories.contains(item['title']),
      );
      visibleCategories.removeWhere(
        (item) => !AppConf().visibleCategories.contains(item.title),
      );
    }
    return GridView.builder(
      controller: widget.scrollController,
      scrollCacheExtent: ScrollCacheExtent.pixels(context.height * 1.5),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: UiMode.m1(context)
            ? 130
            : UiMode.m2(context)
            ? 135
            : 140,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        childAspectRatio: 1 / 1.4,
      ),
      padding: .fromLTRB(12, 6, 12, context.bottom + 8),
      itemCount: visibleExtraMenus.length + visibleCategories.length,
      itemBuilder: (context, index) {
        if (index < visibleExtraMenus.length) {
          return _buildMenuItem(visibleExtraMenus[index]);
        }
        final item = visibleCategories[index - visibleExtraMenus.length];
        return _buildItem(item);
      },
    );
  }

  Widget _buildMenuItem(Map<String, String> item) {
    return _buildCategoryTile(
      title: item['title']!,
      image: Image.asset(item['icon']!, fit: BoxFit.cover),
      onTap: () => context.push(item['path']!),
    );
  }

  Widget _buildItem(Category item) {
    return _buildCategoryTile(
      title: item.title,
      onTap: item.isWeb == true
          ? null
          : () => context.push('/comics?c=${item.title}'),
      image: UiImage(
        url: item.thumb.url,
        cacheKey: item.thumb.cacheKey,
        filterQuality: .medium,
        cacheWidth: 150,
      ),
    );
  }

  Widget _buildCategoryTile({
    required String title,
    required Widget image,
    required VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(14);
    return InkWell(
      key: ValueKey(title),
      onTap: onTap,
      borderRadius: radius,
      child: Column(
        spacing: 7,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: context.colorScheme.surfaceContainer,
                child: image,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.labelLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
