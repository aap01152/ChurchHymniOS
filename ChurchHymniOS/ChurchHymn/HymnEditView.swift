//
//  HymnEditView.swift
//  ChurchHymn
//
//  Created by paulo on 20/05/2025.
//
import SwiftUI
import SwiftData

struct HymnEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var hymn: Hymn
    var onSave: ((Hymn) -> Void)?
    @State private var songNumberText: String = ""

    init(hymn: Hymn, onSave: ((Hymn) -> Void)? = nil) {
        self._hymn = Bindable(wrappedValue: hymn)
        self.onSave = onSave
        // Initialize songNumberText with the current value if it exists
        self._songNumberText = State(initialValue: hymn.songNumber.map(String.init) ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header section with basic info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("form.hymn_details", comment: "Hymn details section title"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("form.title", comment: "Title field label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField(NSLocalizedString("placeholder.hymn_title", comment: "Hymn title placeholder"), text: $hymn.title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("form.hymn_number", comment: "Hymn number field label"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField(NSLocalizedString("placeholder.number", comment: "Number placeholder"), text: $songNumberText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                        .onChange(of: songNumberText) { oldValue, newValue in
                                            // Only allow numeric input
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                songNumberText = filtered
                                            }
                                            // Convert to Int if not empty
                                            hymn.songNumber = filtered.isEmpty ? nil : Int(filtered)
                                        }
                                        .keyboardType(.numberPad)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("form.key", comment: "Key field label"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField(NSLocalizedString("placeholder.key", comment: "Key placeholder"), text: $hymn.musicalKey.unwrap(or: ""))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("form.author", comment: "Author field label"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField(NSLocalizedString("placeholder.author", comment: "Author placeholder"), text: $hymn.author.unwrap(or: ""))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                }
                            }
                            
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("form.tags", comment: "Tags field label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField(NSLocalizedString("placeholder.tags", comment: "Tags placeholder"), text: Binding(
                                    get: { hymn.tags?.joined(separator: ", ") ?? "" },
                                    set: { hymn.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                            }
                        }
                    }
                    
                    // Lyrics section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("form.lyrics", comment: "Lyrics section title"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        TextEditor(text: $hymn.lyrics.unwrap(or: ""))
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 400, maxHeight: 600)
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("form.notes", comment: "Notes section title"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        TextField(NSLocalizedString("placeholder.notes", comment: "Notes placeholder"), text: $hymn.notes.unwrap(or: ""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    
                    // Copyright section (moved to bottom)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("form.copyright", comment: "Copyright field label"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        TextField(NSLocalizedString("placeholder.copyright", comment: "Copyright placeholder"), text: $hymn.copyright.unwrap(or: ""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            .navigationTitle(NSLocalizedString("nav.edit_hymn", comment: "Edit hymn navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("btn.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("btn.save", comment: "Save button")) {
                        onSave?(hymn)
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .disabled(hymn.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 700)
        .frame(idealWidth: 600, idealHeight: 800)
    }
}

extension Binding where Value == String? {
    func unwrap(or defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
