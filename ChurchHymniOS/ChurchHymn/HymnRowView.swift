//
//  HymnRowView.swift
//  ChurchHymniOS
//
//  Created by paulo on 10/01/2026.
//
import SwiftUI

struct HymnRowView: View {
    let hymn: Hymn
    let isSelected: Bool
    let isMarkedForDelete: Bool
    let isMultiSelectMode: Bool
    let isReorderMode: Bool
    let servicePosition: Int?
    let showServicePosition: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPresent: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack {
            if isMultiSelectMode {
                Button(action: onTap) {
                    Image(systemName: isMarkedForDelete ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isMarkedForDelete ? .accentColor : .secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hymn.title.isEmpty ? "Untitled Hymn" : hymn.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let author = hymn.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let key = hymn.musicalKey, !key.isEmpty {
                    Text("Key: \(key)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Service position indicator
            if showServicePosition, let position = servicePosition {
                Text("#\(position)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            
            if !isMultiSelectMode && !isReorderMode {
                Menu {
                    Button(NSLocalizedString("btn.present", comment: "Present"), action: onPresent)
                    Button(NSLocalizedString("btn.edit", comment: "Edit"), action: onEdit)
                    Button(NSLocalizedString("btn.delete", comment: "Delete"), role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Show reorder indicator when in reorder mode
            if isReorderMode {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.1) :
            isReorderMode ? Color.orange.opacity(0.05) : nil
        )
    }
}

