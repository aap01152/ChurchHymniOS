//
//  ImportHelpView.swift
//  ChurchHymn
//
//  Created by paulo on 02/08/2025.
//

import SwiftUI

struct ImportHelpView: View {
    private let jsonSingle = """
{
  "title": "Amazing Grace",
  "songNumber": 123,
  "lyrics": "Amazing grace, how sweet the sound...",
  "musicalKey": "C",
  "author": "John Newton",
  "copyright": "Public Domain",
  "tags": ["grace", "salvation"],
  "notes": "Traditional hymn"
}
"""

    private let jsonBatch = """
[
  { "title": "Hymn 1", "lyrics": "..." },
  { "title": "Hymn 2", "lyrics": "..." }
]
"""

    private let plainText = """
Amazing Grace
#Number: 123
#Key: C
#Author: John Newton
#Copyright: Public Domain
#Tags: grace, salvation
#Notes:

Amazing grace, how sweet the sound
That saved a wretch like me
…

Chorus
Praise God, praise God, praise God
"""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Importing Hymns")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("""
You can import hymns from **JSON** or **plain-text** files. \
Use the **Import** toolbar button, and select your file(s).
""")
                        .font(.body)
                        .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("JSON – Single Hymn")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            CodeBlock(text: jsonSingle)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("JSON – Batch Import")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            CodeBlock(text: jsonBatch)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Plain-Text")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            CodeBlock(text: plainText)
                            Text("Put the word 'Chorus' on a line by itself immediately before the chorus section.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }

                    Divider()
                        .padding(.vertical, 16)

                    HStack {
                        Spacer()
                        Link("Support page", destination: URL(string: "https://paulobfsilva.github.io/ChurchHymn/support.html")!)
                            .font(.body)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Import Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// A tiny helper for monospaced, selectable code blocks
private struct CodeBlock: View {
    let text: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

