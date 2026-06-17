import SwiftUI

struct LiveTimelineView: View {
  let entries: [LiveTimelineEntry]
  var isRefreshing: Bool = false
  var lastUpdated: Date?
  var onRefresh: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.md) {
      header

      if entries.isEmpty {
        Text(String(localized: "reader.live.empty"))
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.textSecondary)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            LiveTimelineRow(entry: entry, isFirst: index == 0, isLast: index == entries.count - 1)
          }
        }
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var header: some View {
    HStack(spacing: PrismaSpacing.sm) {
      LivePulseIndicator()

      VStack(alignment: .leading, spacing: 2) {
        Text(String(localized: "reader.live.title"))
          .font(PrismaTypography.headline())
        if let lastUpdated {
          Text(String(localized: "reader.live.updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"))
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textTertiary)
        }
      }

      Spacer()

      if isRefreshing {
        ProgressView()
          .controlSize(.small)
      } else if onRefresh != nil {
        Button {
          onRefresh?()
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 15, weight: .semibold))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "reader.live.refresh"))
      }

      Text("\(entries.count)")
        .font(PrismaTypography.caption(.semibold))
        .foregroundStyle(PrismaColors.textTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PrismaColors.elevatedSurface)
        .clipShape(Capsule())
    }
  }
}

private struct LivePulseIndicator: View {
  @State private var isPulsing = false

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.red.opacity(0.18))
        .frame(width: 22, height: 22)
        .scaleEffect(isPulsing ? 1.35 : 0.85)
        .opacity(isPulsing ? 0.15 : 0.45)
      Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
    }
    .accessibilityLabel(String(localized: "reader.live.indicator"))
    .onAppear {
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
        isPulsing = true
      }
    }
  }
}

private struct LiveTimelineRow: View {
  let entry: LiveTimelineEntry
  let isFirst: Bool
  let isLast: Bool

  var body: some View {
    HStack(alignment: .top, spacing: PrismaSpacing.sm) {
      timelineRail

      VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
        HStack(spacing: PrismaSpacing.xs) {
          if let timeLabel = entry.timeLabel, !timeLabel.isEmpty {
            Text(timeLabel)
              .font(PrismaTypography.caption(.semibold))
              .foregroundStyle(PrismaColors.accentFallback)
              .monospacedDigit()
          } else if let timestamp = entry.timestamp {
            Text(timestamp, style: .time)
              .font(PrismaTypography.caption(.semibold))
              .foregroundStyle(PrismaColors.accentFallback)
          }

          if entry.isHighlight {
            Text(String(localized: "reader.live.highlight"))
              .font(PrismaTypography.caption2(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.red)
              .clipShape(Capsule())
          }
        }

        if let title = entry.title, !title.isEmpty {
          Text(title)
            .font(PrismaTypography.callout(.semibold))
            .foregroundStyle(PrismaColors.textPrimary)
        }

        Text(entry.body)
          .font(PrismaTypography.body())
          .foregroundStyle(PrismaColors.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let imageURL = entry.imageURL, let url = URL(string: imageURL) {
          ArticleRemoteImage(url: url, maxPixelSize: 480) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            RoundedRectangle(cornerRadius: PrismaRadius.sm)
              .fill(PrismaColors.elevatedSurface)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.sm, style: .continuous))
        }
      }
      .padding(.bottom, isLast ? 0 : PrismaSpacing.md)
    }
  }

  private var timelineRail: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(isFirst ? Color.clear : PrismaColors.textTertiary.opacity(0.25))
        .frame(width: 2, height: 8)

      Circle()
        .fill(isFirst ? Color.red : PrismaColors.accentFallback.opacity(0.85))
        .frame(width: isFirst ? 12 : 9, height: isFirst ? 12 : 9)
        .overlay {
          if isFirst {
            Circle()
              .stroke(Color.red.opacity(0.25), lineWidth: 4)
          }
        }

      Rectangle()
        .fill(isLast ? Color.clear : PrismaColors.textTertiary.opacity(0.25))
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }
    .frame(width: 14)
  }
}

struct LiveCoverageDot: View {
  var body: some View {
    Circle()
      .fill(Color.red)
      .frame(width: 7, height: 7)
      .accessibilityLabel(String(localized: "article.live"))
  }
}

struct LiveCoverageBadge: View {
  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(Color.red)
        .frame(width: 6, height: 6)
      Text(String(localized: "article.live"))
        .font(PrismaTypography.caption2(.semibold))
        .foregroundStyle(Color.red)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.red.opacity(0.12))
    .clipShape(Capsule())
    .accessibilityLabel(String(localized: "article.live"))
  }
}
