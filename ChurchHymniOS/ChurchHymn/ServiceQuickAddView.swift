//
//  ServiceQuickAddView.swift
//  ChurchHymn
//
//  Created by Claude on 20/12/2024.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

/// Quick add service integration view that can be embedded in the sidebar
struct ServiceQuickAddView: View {
    @ObservedObject var serviceService: ServiceService
    @ObservedObject var hymnService: HymnService
    let hymn: Hymn
    
    @State private var isAdding = false
    @State private var showingSuccess = false
    
    var isInActiveService: Bool {
        guard let activeService = serviceService.activeService else { return false }
        return serviceService.serviceHymns.contains { serviceHymn in
            serviceHymn.hymnId == hymn.id && serviceHymn.serviceId == activeService.id
        }
    }
    
    var body: some View {
        Group {
            if let activeService = serviceService.activeService {
                if isInActiveService {
                    // Hymn is already in service - show position and remove option
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("In Service")
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        if let position = hymnPosition {
                            Text("(\(position))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: removeFromService) {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(0.7)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    // Hymn is not in service - show quick add button
                    Button(action: addToService) {
                        HStack(spacing: 4) {
                            if isAdding {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else if showingSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Text(isAdding ? "Adding..." : "Add to Service")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAdding || serviceService.isPerformingServiceOperation)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                    .help("Add \(hymn.title) to \(activeService.displayTitle)")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isInActiveService)
        .animation(.easeInOut(duration: 0.2), value: isAdding)
    }
    
    private var hymnPosition: Int? {
        guard let activeService = serviceService.activeService else { return nil }
        let serviceHymnsForActive = serviceService.serviceHymns
            .filter { $0.serviceId == activeService.id }
            .sorted { $0.order < $1.order }
        
        for (index, serviceHymn) in serviceHymnsForActive.enumerated() {
            if serviceHymn.hymnId == hymn.id {
                return index + 1 // 1-based indexing for display
            }
        }
        return nil
    }
    
    private func addToService() {
        guard let activeService = serviceService.activeService else { return }
        
        isAdding = true
        
        Task {
            let success = await serviceService.addHymnToService(
                hymnId: hymn.id,
                serviceId: activeService.id
            )
            
            await MainActor.run {
                isAdding = false
                if success {
                    showingSuccess = true
                    // Provide haptic feedback
                    #if os(iOS)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    #endif
                    
                    // Hide success indicator after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingSuccess = false
                    }
                }
            }
        }
    }
    
    private func removeFromService() {
        guard let activeService = serviceService.activeService else { return }
        
        Task {
            await serviceService.removeHymnFromService(
                hymnId: hymn.id,
                serviceId: activeService.id
            )
        }
    }
}

#Preview {
    Text("ServiceQuickAddView Preview")
        .padding()
        .foregroundColor(.secondary)
        .font(.caption)
}
