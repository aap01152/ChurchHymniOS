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
                VStack(spacing: 24) {
                    // Header section with basic info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hymn Details")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter hymn title", text: $hymn.title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hymn Number")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Number", text: $songNumberText)
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
                                    Text("Key")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField("e.g. G Major", text: $hymn.musicalKey.unwrap(or: ""))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Author")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Author name", text: $hymn.author.unwrap(or: ""))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Copyright")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("e.g. © 2025 Church", text: $hymn.copyright.unwrap(or: ""))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Comma separated tags", text: Binding(
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
                        Text("Lyrics")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        TextEditor(text: $hymn.lyrics.unwrap(or: ""))
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 300)
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
                        Text("Notes")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        TextField("Additional notes...", text: $hymn.notes.unwrap(or: ""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Edit Hymn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave?(hymn)
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .disabled(hymn.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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
