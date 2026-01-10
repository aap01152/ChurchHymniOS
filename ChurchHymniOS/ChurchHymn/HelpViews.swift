import SwiftUI
import Foundation

// MARK: - Help Sheet View

/// Main help interface that presents help content in a sheet
struct HelpSheetView: View {
    @ObservedObject var helpSystem: HelpSystem
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: HelpCategory? = .gettingStarted
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Categories sidebar
                helpCategoriesSidebar
                
                Divider()
                
                // Topics and content
                helpContentArea
            }
            .navigationTitle(NSLocalizedString("help.support_title", comment: "Help and support title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("btn.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600) // Ensure good size on iPad
    }
    
    // MARK: - Categories Sidebar
    
    @ViewBuilder
    private var helpCategoriesSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("help.search_placeholder", comment: "Search help topics placeholder"), text: $helpSystem.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if !helpSystem.searchText.isEmpty {
                    searchResultsList
                } else {
                    categoriesList
                }
            }
            
            Spacer()
        }
        .frame(width: 280)
        .background(Color(.secondarySystemBackground))
    }
    
    @ViewBuilder
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(helpSystem.filteredTopics) { topic in
                    HelpTopicRow(
                        topic: topic,
                        isSelected: topic == helpSystem.currentHelpTopic,
                        onTap: {
                            helpSystem.navigateToTopic(topic)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var categoriesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(HelpCategory.allCases, id: \.self) { category in
                    HelpCategorySection(
                        category: category,
                        topics: HelpSystem.helpTopics[category] ?? [],
                        selectedTopic: helpSystem.currentHelpTopic,
                        isExpanded: selectedCategory == category,
                        onCategoryTap: {
                            selectedCategory = selectedCategory == category ? nil : category
                        },
                        onTopicTap: { topic in
                            helpSystem.navigateToTopic(topic)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var helpContentArea: some View {
        VStack(spacing: 0) {
            if helpSystem.searchText.isEmpty {
                // Topic content
                ScrollView {
                    HelpTopicContentView(
                        topic: helpSystem.currentHelpTopic,
                        onRelatedTopicTap: { topic in
                            helpSystem.navigateToTopic(topic)
                        }
                    )
                    .padding()
                }
            } else {
                // Search results content
                if helpSystem.filteredTopics.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(NSLocalizedString("help.no_topics_title", comment: "No help topics found"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(NSLocalizedString("help.no_topics_message", comment: "Try different search terms or browse categories"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(NSLocalizedString("help.search_results_title", comment: "Search results title"))
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text(String(format: NSLocalizedString("help.search_results_count", comment: "Search results count"), helpSystem.filteredTopics.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(helpSystem.filteredTopics) { topic in
                                    HelpSearchResultCard(
                                        topic: topic,
                                        searchText: helpSystem.searchText,
                                        onTap: {
                                            helpSystem.searchText = "" // Clear search
                                            helpSystem.navigateToTopic(topic)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Help Category Section

struct HelpCategorySection: View {
    let category: HelpCategory
    let topics: [HelpTopic]
    let selectedTopic: HelpTopic
    let isExpanded: Bool
    let onCategoryTap: () -> Void
    let onTopicTap: (HelpTopic) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Button(action: onCategoryTap) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .frame(width: 20)
                    
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Topics (if expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(topics) { topic in
                        HelpTopicRow(
                            topic: topic,
                            isSelected: topic == selectedTopic,
                            onTap: {
                                onTopicTap(topic)
                            }
                        )
                        .padding(.leading, 28) // Indent under category
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Help Topic Row

struct HelpTopicRow: View {
    let topic: HelpTopic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: topic.icon)
                    .foregroundColor(topic.category.color)
                    .frame(width: 16)
                
                Text(topic.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Topic Content View

struct HelpTopicContentView: View {
    let topic: HelpTopic
    let onRelatedTopicTap: (HelpTopic) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: topic.icon)
                        .font(.title)
                        .foregroundColor(topic.category.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(topic.category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
            }
            
            // Content
            Text(topic.content)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Related topics
            if !topic.relatedTopics.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("help.related_topics", comment: "Related topics"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 300))
                    ], spacing: 12) {
                        ForEach(topic.relatedTopics) { relatedTopic in
                            HelpRelatedTopicCard(
                                topic: relatedTopic,
                                onTap: {
                                    onRelatedTopicTap(relatedTopic)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Related Topic Card

struct HelpRelatedTopicCard: View {
    let topic: HelpTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: topic.icon)
                    .foregroundColor(topic.category.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(topic.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result Card

struct HelpSearchResultCard: View {
    let topic: HelpTopic
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: topic.icon)
                        .foregroundColor(topic.category.color)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(topic.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Content preview with highlighted search terms
                Text(contentPreview)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentPreview: String {
        let content = topic.content
        let searchLower = searchText.lowercased()
        
        // Find the location of the search term in content
        if let range = content.lowercased().range(of: searchLower) {
            let startIndex = max(content.startIndex, 
                               content.index(range.lowerBound, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex)
            let endIndex = min(content.endIndex,
                             content.index(range.upperBound, offsetBy: 100, limitedBy: content.endIndex) ?? content.endIndex)
            
            var preview = String(content[startIndex..<endIndex])
            if startIndex != content.startIndex {
                preview = "..." + preview
            }
            if endIndex != content.endIndex {
                preview = preview + "..."
            }
            return preview
        }
        
        // Fallback to beginning of content
        return String(content.prefix(150)) + (content.count > 150 ? "..." : "")
    }
}

// MARK: - Help Button

/// Reusable help button component for toolbars
struct HelpButton: View {
    @ObservedObject var helpSystem: HelpSystem
    let context: HelpContext?
    
    init(helpSystem: HelpSystem, context: HelpContext? = nil) {
        self.helpSystem = helpSystem
        self.context = context
    }
    
    var body: some View {
        Button(action: {
            if let context = context {
                let topic = helpSystem.getContextualHelp(for: context)
                helpSystem.showHelp(for: topic)
            } else {
                helpSystem.showHelp()
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Text(NSLocalizedString("btn.help", comment: "Help"))
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .help(NSLocalizedString("help.open_help", comment: "Open help and support"))
    }
}

// MARK: - Contextual Help Overlay

/// Small help hint that can appear over interface elements
struct HelpHintOverlay: View {
    let message: String
    let isVisible: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        if isVisible {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 4)
                )
                
                Spacer()
            }
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
