//
//  HymnQueueManager.swift
//  ChurchHymn
//
//  Created by Claude on 29/12/2025.
//

import SwiftUI
import Foundation

/// Queue item representing a hymn in the presentation queue
struct QueuedHymn: Identifiable, Codable {
    let id: UUID
    let hymn: Hymn
    let startingVerse: Int
    let addedAt: Date
    var status: QueueStatus
    
    init(hymn: Hymn, startingVerse: Int = 0, addedAt: Date = Date(), status: QueueStatus = .waiting) {
        self.id = UUID()
        self.hymn = hymn
        self.startingVerse = startingVerse
        self.addedAt = addedAt
        self.status = status
    }
    
    enum QueueStatus: String, Codable, CaseIterable {
        case waiting = "waiting"
        case presenting = "presenting"
        case completed = "completed"
        case skipped = "skipped"
        
        var displayName: String {
            switch self {
            case .waiting: return "Waiting"
            case .presenting: return "Presenting"
            case .completed: return "Completed"
            case .skipped: return "Skipped"
            }
        }
        
        var color: Color {
            switch self {
            case .waiting: return .blue
            case .presenting: return .green
            case .completed: return .gray
            case .skipped: return .orange
            }
        }
    }
}

/// Manager for hymn presentation queue during worship sessions
@MainActor
final class HymnQueueManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Queue of hymns to be presented
    @Published var queue: [QueuedHymn] = []
    
    /// Whether queue mode is enabled
    @Published var isQueueModeEnabled: Bool = false
    
    /// Auto-advance to next hymn when current one completes
    @Published var autoAdvanceEnabled: Bool = false
    
    /// Delay before auto-advancing (in seconds)
    @Published var autoAdvanceDelay: TimeInterval = 5.0
    
    /// Current auto-advance countdown
    @Published var autoAdvanceCountdown: Int = 0
    
    /// Whether auto-advance countdown is active
    @Published var isAutoAdvancing: Bool = false
    
    // MARK: - Private Properties
    
    private var worshipSessionManager: WorshipSessionManager?
    private var autoAdvanceTimer: Timer?
    
    // MARK: - Configuration
    
    /// Available auto-advance delay options
    static let autoAdvanceDelayOptions: [TimeInterval] = [3.0, 5.0, 10.0, 15.0, 30.0]
    
    static let autoAdvanceDelayLabels: [TimeInterval: String] = [
        3.0: "3 seconds",
        5.0: "5 seconds",
        10.0: "10 seconds", 
        15.0: "15 seconds",
        30.0: "30 seconds"
    ]
    
    // MARK: - Setup
    
    func setup(worshipSessionManager: WorshipSessionManager) {
        self.worshipSessionManager = worshipSessionManager
    }
    
    // MARK: - Queue Management
    
    /// Add hymn to queue
    func addToQueue(_ hymn: Hymn, startingVerse: Int = 0) {
        // Check if hymn already exists in queue
        if queue.contains(where: { $0.hymn.id == hymn.id && $0.status == .waiting }) {
            print("Hymn '\(hymn.title)' is already in the queue")
            return
        }
        
        let queuedHymn = QueuedHymn(
            hymn: hymn,
            startingVerse: startingVerse,
            addedAt: Date(),
            status: .waiting
        )
        
        queue.append(queuedHymn)
        print("➕ Added '\(hymn.title)' to presentation queue")
    }
    
    /// Remove hymn from queue
    func removeFromQueue(_ queuedHymn: QueuedHymn) {
        queue.removeAll { $0.id == queuedHymn.id }
        print("➖ Removed '\(queuedHymn.hymn.title)' from queue")
    }
    
    /// Move hymn up in queue
    func moveUp(_ queuedHymn: QueuedHymn) {
        guard let index = queue.firstIndex(where: { $0.id == queuedHymn.id }),
              index > 0 else { return }
        
        queue.swapAt(index, index - 1)
        print("⬆️ Moved '\(queuedHymn.hymn.title)' up in queue")
    }
    
    /// Move hymn down in queue
    func moveDown(_ queuedHymn: QueuedHymn) {
        guard let index = queue.firstIndex(where: { $0.id == queuedHymn.id }),
              index < queue.count - 1 else { return }
        
        queue.swapAt(index, index + 1)
        print("⬇️ Moved '\(queuedHymn.hymn.title)' down in queue")
    }
    
    /// Clear completed and skipped items from queue
    func clearCompleted() {
        let removedCount = queue.count
        queue.removeAll { $0.status == .completed || $0.status == .skipped }
        let currentCount = queue.count
        
        print("🧹 Cleared \(removedCount - currentCount) completed items from queue")
    }
    
    /// Clear entire queue
    func clearQueue() {
        let count = queue.count
        queue.removeAll()
        cancelAutoAdvance()
        
        print("🗑️ Cleared all \(count) items from queue")
    }
    
    // MARK: - Queue Playback
    
    /// Present next hymn in queue
    func presentNext() async {
        guard let worshipSessionManager = worshipSessionManager,
              worshipSessionManager.isWorshipSessionActive else {
            print("❌ Cannot present next: No active worship session")
            return
        }
        
        // Find next waiting hymn
        guard let nextIndex = queue.firstIndex(where: { $0.status == .waiting }),
              nextIndex < queue.count else {
            print("📭 No more hymns in queue to present")
            return
        }
        
        // Mark current presenting hymn as completed
        if let currentIndex = queue.firstIndex(where: { $0.status == .presenting }) {
            queue[currentIndex].status = .completed
        }
        
        // Present next hymn
        queue[nextIndex].status = .presenting
        let queuedHymn = queue[nextIndex]
        
        do {
            print("🎵 Presenting next queued hymn: \(queuedHymn.hymn.title)")
            try await worshipSessionManager.presentCurrentlyViewedHymn(
                queuedHymn.hymn,
                startingAtVerse: queuedHymn.startingVerse
            )
            
            // Start auto-advance timer if enabled
            if autoAdvanceEnabled && hasNextHymn() {
                startAutoAdvanceTimer()
            }
            
        } catch {
            print("❌ Failed to present queued hymn: \(error.localizedDescription)")
            queue[nextIndex].status = .waiting // Reset status on failure
        }
    }
    
    /// Skip current hymn in queue
    func skipCurrent() {
        guard let currentIndex = queue.firstIndex(where: { $0.status == .presenting }) else {
            print("❌ No hymn currently presenting to skip")
            return
        }
        
        queue[currentIndex].status = .skipped
        print("⏭️ Skipped current hymn: \(queue[currentIndex].hymn.title)")
        
        // Auto-present next if enabled
        if autoAdvanceEnabled {
            Task {
                await presentNext()
            }
        }
    }
    
    /// Check if there are more hymns in queue
    func hasNextHymn() -> Bool {
        return queue.contains { $0.status == .waiting }
    }
    
    /// Get current presenting hymn
    func currentPresentingHymn() -> QueuedHymn? {
        return queue.first { $0.status == .presenting }
    }
    
    /// Get next hymn in queue
    func nextHymn() -> QueuedHymn? {
        return queue.first { $0.status == .waiting }
    }
    
    // MARK: - Auto-Advance
    
    /// Start auto-advance timer
    private func startAutoAdvanceTimer() {
        cancelAutoAdvance()
        
        isAutoAdvancing = true
        autoAdvanceCountdown = Int(autoAdvanceDelay)
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                self.autoAdvanceCountdown -= 1
                
                if self.autoAdvanceCountdown <= 0 {
                    timer.invalidate()
                    self.isAutoAdvancing = false
                    
                    await self.presentNext()
                }
            }
        }
        
        print("⏱️ Auto-advance timer started (\(Int(autoAdvanceDelay))s)")
    }
    
    /// Cancel auto-advance timer
    func cancelAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        isAutoAdvancing = false
        autoAdvanceCountdown = 0
        
        print("⏹️ Auto-advance cancelled")
    }
    
    // MARK: - Statistics
    
    var queueStatistics: QueueStatistics {
        let waiting = queue.filter { $0.status == .waiting }.count
        let completed = queue.filter { $0.status == .completed }.count
        let skipped = queue.filter { $0.status == .skipped }.count
        let total = queue.count
        
        return QueueStatistics(
            total: total,
            waiting: waiting,
            completed: completed,
            skipped: skipped,
            currentPosition: total - waiting
        )
    }
}

/// Queue statistics for display
struct QueueStatistics {
    let total: Int
    let waiting: Int
    let completed: Int
    let skipped: Int
    let currentPosition: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed + skipped) / Double(total)
    }
}

/// Queue management view
struct HymnQueueView: View {
    @ObservedObject var queueManager: HymnQueueManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Queue controls
                queueControlsSection
                
                // Queue list
                if queueManager.queue.isEmpty {
                    emptyQueueView
                } else {
                    queueListView
                }
            }
            .navigationTitle("Hymn Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Settings") {
                        // Show queue settings
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var queueControlsSection: some View {
        VStack(spacing: 12) {
            // Queue mode toggle
            Toggle("Queue Mode", isOn: $queueManager.isQueueModeEnabled)
                .padding(.horizontal)
            
            if queueManager.isQueueModeEnabled {
                // Queue statistics
                let stats = queueManager.queueStatistics
                
                HStack(spacing: 16) {
                    VStack {
                        Text("\(stats.total)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.waiting)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Waiting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(stats.completed)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Done")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Progress bar
                if stats.total > 0 {
                    ProgressView(value: stats.progress)
                        .padding(.horizontal)
                }
                
                // Queue actions
                HStack(spacing: 12) {
                    Button(NSLocalizedString("btn.present_next", comment: "Present Next"), action: {
                        Task { await queueManager.presentNext() }
                    })
                    .disabled(!queueManager.hasNextHymn())
                    
                    Button(NSLocalizedString("btn.clear_done", comment: "Clear Done")) {
                        queueManager.clearCompleted()
                    }
                    .disabled(stats.completed + stats.skipped == 0)
                    
                    Button("Clear All") {
                        queueManager.clearQueue()
                    }
                    .disabled(stats.total == 0)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Queue is Empty")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add hymns to the queue from the main hymn list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var queueListView: some View {
        List {
            ForEach(Array(queueManager.queue.enumerated()), id: \.element.id) { index, queuedHymn in
                QueueItemRow(
                    queuedHymn: queuedHymn,
                    position: index + 1,
                    queueManager: queueManager
                )
            }
        }
    }
}

/// Individual queue item row
struct QueueItemRow: View {
    let queuedHymn: QueuedHymn
    let position: Int
    let queueManager: HymnQueueManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Position indicator
            VStack {
                Text("\(position)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(queuedHymn.status.color)
                    .frame(width: 8, height: 8)
            }
            
            // Hymn info
            VStack(alignment: .leading, spacing: 4) {
                Text(queuedHymn.hymn.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(queuedHymn.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(queuedHymn.status.color.opacity(0.2))
                        .foregroundColor(queuedHymn.status.color)
                        .cornerRadius(4)
                    
                    if queuedHymn.startingVerse > 0 {
                        Text("Start at verse \(queuedHymn.startingVerse + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 4) {
                Button(action: { queueManager.moveUp(queuedHymn) }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .disabled(position == 1)
                
                Button(action: { queueManager.moveDown(queuedHymn) }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .disabled(position == queueManager.queue.count)
            }
            .buttonStyle(.borderless)
            
            Button(action: { queueManager.removeFromQueue(queuedHymn) }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .opacity(queuedHymn.status == .completed || queuedHymn.status == .skipped ? 0.6 : 1.0)
    }
}