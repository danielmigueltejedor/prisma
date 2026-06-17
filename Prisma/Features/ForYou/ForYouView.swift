import SwiftUI

struct ForYouView: View {
  @Bindable var viewModel: ForYouViewModel
  var onSelectArticle: (Article) -> Void
  var onShowPaywall: () -> Void

  @State private var selectedCluster: ClusterDTO?

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.articles.isEmpty {
          EmptyStateView(
            icon: "sparkles",
            title: String(localized: "foryou.empty.title"),
            message: String(localized: "foryou.empty.message")
          )
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: PrismaSpacing.lg) {
              if !viewModel.hasSmartFeed {
                plusPromoCard
              } else if AIServiceFactory.hasFreeOnDeviceAI && !viewModel.isPlusActive {
                onDeviceAIBadge
              }

              if viewModel.hasSmartFeed, let briefing = viewModel.briefing {
                briefingCard(briefing)
              }

              if viewModel.hasSmartFeed, !viewModel.clusters.isEmpty {
                sectionHeader(String(localized: "foryou.clusters"))
                ForEach(viewModel.clusters, id: \.id) { cluster in
                  Button { selectedCluster = cluster } label: {
                    clusterCard(cluster)
                  }
                  .buttonStyle(.plain)
                }
              }

              sectionHeader(
                viewModel.hasSmartFeed
                  ? String(localized: "foryou.smartFeed")
                  : String(localized: "foryou.localFeed")
              )

              ForEach(viewModel.articles.prefix(30), id: \.id) { article in
                Button { onSelectArticle(article) } label: {
                  ArticleCard(
                    title: article.title,
                    sourceName: article.sourceName,
                    publishedAt: article.publishedAt,
                    summary: HTMLSanitizer.stripHTML(article.summary),
                    imageURL: article.imageUrl.flatMap(URL.init(string:)),
                    isRead: article.isRead,
                    isSaved: article.isSaved,
                    likeCount: article.likeCount,
                    viewCount: article.viewCount,
                    readingTimeMinutes: article.readingTimeEstimate,
                    sourceSiteURL: article.feedSource?.siteURL,
                    sourceFeedURL: article.originalFeedUrl
                  )
                }
                .buttonStyle(.plain)
              }
            }
            .padding(PrismaSpacing.md)
          }
        }
      }
      .navigationTitle(String(localized: "tab.foryou"))
      .onAppear { viewModel.load() }
      .overlay {
        if viewModel.isLoadingAI {
          ProgressView()
            .padding()
            .prismaGlass()
        }
      }
      .sheet(item: $selectedCluster) { cluster in
        ClusterDetailView(
          cluster: cluster,
          articles: viewModel.articles(for: cluster),
          onSelectArticle: { article in
            selectedCluster = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              onSelectArticle(article)
            }
          }
        )
      }
    }
  }

  private var onDeviceAIBadge: some View {
    HStack(spacing: PrismaSpacing.xs) {
      Image(systemName: "apple.intelligence")
        .foregroundStyle(PrismaColors.accentFallback)
      Text(String(localized: "ai.onDeviceFree"))
        .font(PrismaTypography.caption(.semibold))
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .prismaGlass()
  }

  private var plusPromoCard: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        PrismaPlusBadge()
        Text(String(localized: "foryou.plus.title"))
          .font(PrismaTypography.headline())
      }
      Text(String(localized: "foryou.plus.message"))
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
      PrismaButton(title: String(localized: "plus.activate"), style: .secondary) {
        onShowPaywall()
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private func briefingCard(_ briefing: DailyBriefingDTO) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        PrismaPlusBadge()
        Text(briefing.title)
          .font(PrismaTypography.headline())
      }
      ForEach(briefing.sections.indices, id: \.self) { index in
        let section = briefing.sections[index]
        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text(section.headline)
            .font(PrismaTypography.callout(.semibold))
          Text(section.summary)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textSecondary)
            .lineLimit(4)
        }
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private func clusterCard(_ cluster: ClusterDTO) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        PrismaPlusBadge()
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(PrismaColors.textTertiary)
      }

      Text(cluster.title)
        .font(PrismaTypography.headline())
        .multilineTextAlignment(.leading)

      if let story = cluster.synthesizedStory ?? cluster.summary {
        Text(story)
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.textSecondary)
          .lineLimit(3)
      }

      HStack(spacing: PrismaSpacing.xs) {
        if let sources = cluster.sourceNames {
          ForEach(sources.prefix(4), id: \.self) { source in
            Text(source)
              .font(PrismaTypography.caption2())
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(PrismaColors.elevatedSurface)
              .clipShape(Capsule())
          }
        }
        Spacer()
        Text(String(localized: "foryou.cluster.count \(cluster.articleIds.count)"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textTertiary)
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(PrismaTypography.title())
  }
}

extension ClusterDTO: Identifiable {}
