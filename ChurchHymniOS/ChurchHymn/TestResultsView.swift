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
                        Text(NSLocalizedString("test.summary", comment: "Test summary section title"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let passedCount = testResults.filter { $0.passed }.count
                        let totalCount = testResults.count
                        let totalTime = testResults.reduce(0) { $0 + $1.executionTime }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: passedCount == totalCount ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(passedCount == totalCount ? .green : .red)
                                Text(String(format: NSLocalizedString("test.passed_count", comment: "Tests passed count"), passedCount, totalCount))
                                    .font(.headline)
                            }
                            
                            Text(String(format: NSLocalizedString("test.total_execution_time", comment: "Total execution time"), totalTime))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: NSLocalizedString("test.success_rate", comment: "Success rate"), Double(passedCount) / Double(max(totalCount, 1)) * 100))
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
                                
                                Text(String(format: NSLocalizedString("test.result_title", comment: "Test result title"), index + 1, result.testName))
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(String(format: NSLocalizedString("test.execution_time", comment: "Execution time"), result.executionTime))
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
                            
                            Text(NSLocalizedString("test.no_results_title", comment: "No test results title"))
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text(NSLocalizedString("test.no_results_message", comment: "No test results message"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("test.results_title", comment: "Test results title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("btn.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
}
