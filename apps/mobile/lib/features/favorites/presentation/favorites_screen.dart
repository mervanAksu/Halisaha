import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/network_image_box.dart';
import '../domain/favorite_venue.dart';
import 'favorites_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteVenuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.navFavorites)),
      body: AsyncValueWidget<List<FavoriteVenue>>(
        value: favorites,
        onRetry: () => ref.invalidate(favoriteVenuesProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(favoriteVenuesProvider);
            try {
              await ref.read(favoriteVenuesProvider.future);
            } catch (_) {
              // Error state is rendered by the list.
            }
          },
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: 420,
                      child: EmptyState(
                        icon: Icons.favorite_border,
                        message: S.noFavorites,
                        actionLabel: S.searchVenue,
                        onAction: () => context.go(AppRoutes.home),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
                  itemBuilder: (context, index) => _FavoriteTile(venue: items[index]),
                ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.venue});

  final FavoriteVenue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.venue(venue.venueId)),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: NetworkImageBox(url: venuePhotoUrl(venue.coverPhotoPath), title: venue.name),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text(venue.district, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: S.removeFavorite,
              icon: Icon(Icons.favorite, color: context.tokens.danger),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(favoritesActionsProvider).setFavorite(venue.venueId, favorite: false);
                } on AppException catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
