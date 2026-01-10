//
//  TestResultsView.swift
//  ChurchHymniOS
//
//  Created by paulo on 10/01/2026.
//

import SwiftUI

struct TestResultsView: View {
    let testResults: [ContentView.ValidationTestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let passedCount = testResults.filter { $0.passed }.count
                        let totalCount = testResults.count
                        let totalTime = testResults.reduce(0) { $0 + $1.executionTime }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: passedCount == totalCount ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(passedCount == totalCount ? .green : .red)
                                Text("Tests Passed: \(passedCount)/\(totalCount)")
                                    .font(.headline)
                            }
                            
                            Text("Total Execution Time: \(String(format: "%.3f", totalTime))s")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Success Rate: \(String(format: "%.1f", Double(passedCount) / Double(max(totalCount, 1)) * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Individual Test Results
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.passed ? .green : .red)
                                
                                Text("\(index + 1). \(result.testName)")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.3f", result.executionTime))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !result.message.isEmpty {
                                Text(result.message)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !result.details.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(result.details, id: \.self) { detail in
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(result.passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if testResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "testtube.2")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            
                            Text("No test results available")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Run the test suite to see validation results")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
}
