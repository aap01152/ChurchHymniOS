import SwiftUI
import Foundation

/// Service Management View that works with the new ServiceService architecture
struct ServiceManagementView: View {
    @ObservedObject var serviceService: ServiceService
    @ObservedObject var hymnService: HymnService
    
    @State private var showingCreateService = false
    @State private var showingServiceDetails = false
    @State private var selectedService: WorshipService?
    @State private var newServiceTitle = ""
    @State private var newServiceDate = Date()
    @State private var newServiceNotes = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Active Service Section
                if let activeService = serviceService.activeService {
                    ActiveServiceCard(
                        service: activeService,
                        serviceService: serviceService,
                        hymnService: hymnService,
                        onViewDetails: {
                            selectedService = activeService
                            showingServiceDetails = true
                        }
                    )
                    .padding()
                } else {
                    NoActiveServiceCard(
                        onCreateService: {
                            showingCreateService = true
                        },
                        onCreateTodaysService: {
                            Task {
                                let todayService = WorshipService(
                                    title: "Today's Service",
                                    date: Date(),
                                    notes: nil
                                )
                                let success = await serviceService.createService(todayService)
                                if success {
                                    // Automatically activate the newly created service
                                    await serviceService.setActiveService(todayService)
                                }
                            }
                        }
                    )
                    .padding()
                }
                
                Divider()
                
                // Services List
                ServicesList(
                    serviceService: serviceService,
                    onServiceTap: { service in
                        selectedService = service
                        showingServiceDetails = true
                    },
                    onCreateService: {
                        showingCreateService = true
                    }
                )
            }
            .navigationTitle(NSLocalizedString("nav.services", comment: "Services button on navigation bar"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("btn.new_service", comment: "New Service")) {
                        showingCreateService = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateService) {
            CreateServiceSheet(
                title: $newServiceTitle,
                date: $newServiceDate,
                notes: $newServiceNotes,
                onCreate: { title, date, notes in
                    Task {
                        await createService(title: title, date: date, notes: notes)
                    }
                }
            )
        }
        .sheet(isPresented: $showingServiceDetails, onDismiss: {
            selectedService = nil
        }) {
            if let service = selectedService {
                ServiceDetailsView(
                    service: service,
                    serviceService: serviceService,
                    hymnService: hymnService
                )
            }
        }
        .task {
            if serviceService.services.isEmpty && !serviceService.isLoading {
                await serviceService.loadServices()
            }
            if hymnService.hymns.isEmpty && !hymnService.isLoading {
                await hymnService.loadHymns()
            }
        }
        .onAppear {
            // Refresh services when view appears to ensure data is current
            Task {
                await serviceService.loadServices()
            }
        }
        .onChange(of: serviceService.activeService) { _, newActiveService in
            // Refresh service hymns when active service changes
            if let activeService = newActiveService {
                Task {
                    await serviceService.loadServiceHymns(for: activeService.id)
                }
            }
        }
    }
    
    private func createService(title: String, date: Date, notes: String) async {
        let service = WorshipService(title: title, date: date, notes: notes.isEmpty ? nil : notes)
        let success = await serviceService.createService(service)
        
        if success {
            // Clear form
            await MainActor.run {
                newServiceTitle = ""
                newServiceDate = Date()
                newServiceNotes = ""
                showingCreateService = false
            }
        }
    }
}

// MARK: - Active Service Card

struct ActiveServiceCard: View {
    let service: WorshipService
    @ObservedObject var serviceService: ServiceService
    @ObservedObject var hymnService: HymnService
    let onViewDetails: () -> Void
    
    var hymnCount: Int {
        serviceService.serviceHymns.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("service.active_service", comment: "Active Service"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(service.displayTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Button("Details") {
                    onViewDetails()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Info Row
            HStack {
                Label("\(hymnCount) hymns", systemImage: "music.note")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !service.date.isToday {
                    Text(service.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                Button("Add Hymn") {
                    onViewDetails()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if hymnCount > 0 {
                    Button("Clear All") {
                        Task {
                            for serviceHymn in serviceService.serviceHymns {
                                _ = await serviceService.removeHymnFromService(
                                    hymnId: serviceHymn.hymnId,
                                    serviceId: service.id
                                )
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            
            // Error Display
            if let error = serviceService.serviceOperationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        serviceService.clearServiceOperationError()
                    }
                    .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - No Active Service Card

struct NoActiveServiceCard: View {
    let onCreateService: () -> Void
    let onCreateTodaysService: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("No Active Service")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Create or activate a service to start managing hymns for worship")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Create Today's Service") {
                    onCreateTodaysService()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Create Service") {
                    onCreateService()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Services List

struct ServicesList: View {
    @ObservedObject var serviceService: ServiceService
    let onServiceTap: (WorshipService) -> Void
    let onCreateService: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("All Services")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if serviceService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding()
            
            // Content
            if serviceService.services.isEmpty && !serviceService.isLoading {
                VStack(spacing: 16) {
                    Text("No services created yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("Create Your First Service") {
                        onCreateService()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(serviceService.services) { service in
                    ServiceRowView(
                        service: service,
                        isActive: service.id == serviceService.activeService?.id,
                        onTap: { onServiceTap(service) },
                        onSetActive: {
                            Task {
                                await serviceService.setActiveService(service)
                            }
                        },
                        onDelete: {
                            Task {
                                await serviceService.deleteService(service)
                            }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Service Row View

struct ServiceRowView: View {
    let service: WorshipService
    let isActive: Bool
    let onTap: () -> Void
    let onSetActive: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(service.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                Text(service.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = service.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if !isActive {
                    Button("Activate") {
                        onSetActive()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Details") {
                    onTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(NSLocalizedString("btn.delete", comment: "Delete")) {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .alert("Delete Service", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button(NSLocalizedString("btn.delete", comment: "Delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(service.displayTitle)'? This action cannot be undone.")
        }
    }
}

// MARK: - Create Service Sheet

struct CreateServiceSheet: View {
    @Binding var title: String
    @Binding var date: Date
    @Binding var notes: String
    let onCreate: (String, Date, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Service Details") {
                    TextField("Service Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(NSLocalizedString("nav.new_service", comment: "New Service"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate(title, date, notes)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Service Details View

struct ServiceDetailsView: View {
    let service: WorshipService
    @ObservedObject var serviceService: ServiceService
    @ObservedObject var hymnService: HymnService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddHymn = false
    @State private var localServiceHymns: [ServiceHymn] = []
    @State private var isLoading = false
    
    var currentService: WorshipService? {
        serviceService.services.first { $0.id == service.id }
    }
    
    func loadLocalServiceHymns() async {
        isLoading = true
        do {
            // Use the serviceHymnRepository directly to get hymns for this specific service
            let hymns = try await serviceService.serviceHymnRepository.getServiceHymns(for: service.id)
            await MainActor.run {
                localServiceHymns = hymns.sorted { $0.order < $1.order }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                localServiceHymns = []
                isLoading = false
            }
        }
    }
    
    var body: some View {
        Group {
            if let currentService = currentService {
                VStack(spacing: 0) {
                    // Service Info Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(currentService.displayTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(currentService.date.formatted(date: .complete, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                if currentService.isActive {
                                    Text("ACTIVE")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor)
                                        .cornerRadius(6)
                                }
                                
                                if currentService.isCompleted {
                                    Text("COMPLETED")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                        
                                    if let completedAt = currentService.completedAt {
                                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        if let notes = currentService.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        
                        // Worship History Section (for completed services)
                        if currentService.isCompleted && !currentService.worshipHymnsUsed.isEmpty {
                            worshipHistorySection(for: currentService)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                
                // Hymns Section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Hymns (\(localServiceHymns.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Add Hymn") {
                            showingAddHymn = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    
                    if localServiceHymns.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            
                            Text("No hymns added yet")
                                .font(.headline)
                            
                            Text("Add hymns to this service to organize worship music")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Add First Hymn") {
                                showingAddHymn = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        List {
                            ForEach(localServiceHymns, id: \.id) { serviceHymn in
                                ServiceHymnRowView(
                                    serviceHymn: serviceHymn,
                                    hymn: hymnService.hymns.first { $0.id == serviceHymn.hymnId },
                                    onRemove: {
                                        Task {
                                            await serviceService.removeHymnFromService(
                                                hymnId: serviceHymn.hymnId,
                                                serviceId: service.id
                                            )
                                            // Refresh local hymns after removing
                                            await loadLocalServiceHymns()
                                        }
                                    }
                                )
                            }
                            .onMove { source, destination in
                                Task {
                                    let movedHymns = Array(localServiceHymns)
                                    var reorderedHymns = movedHymns
                                    reorderedHymns.move(fromOffsets: source, toOffset: destination)
                                    
                                    let hymnIds = reorderedHymns.map { $0.hymnId }
                                    _ = await serviceService.reorderServiceHymns(serviceId: service.id, hymnIds: hymnIds)
                                    // Refresh local hymns after reordering
                                    await loadLocalServiceHymns()
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Service Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("Service Not Found")
                    .font(.headline)
                
                Text("The service details could not be loaded.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("Service Details")
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
        .task {
            // Load service hymns when the details view appears
            await loadLocalServiceHymns()
        }
        .onAppear {
            // Ensure hymns are loaded when view appears
            Task {
                await loadLocalServiceHymns()
            }
        }
        .sheet(isPresented: $showingAddHymn) {
            AddHymnToServiceSheet(
                availableHymns: hymnService.hymns,
                onAddHymn: { hymn in
                    Task {
                        await serviceService.addHymnToService(
                            hymnId: hymn.id,
                            serviceId: service.id
                        )
                        // Refresh local hymns after adding
                        await loadLocalServiceHymns()
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func worshipHistorySection(for service: WorshipService) -> some View {
        Divider()
            .padding(.top, 8)
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.green)
                Text("Hymns Presented During Worship")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(service.worshipHymnsUsed.enumerated()), id: \.offset) { index, hymnTitle in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(hymnTitle)
                            .font(.body)
                        
                        Spacer()
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding(.top, 8)
    }
}

// MARK: - Service Hymn Row View

struct ServiceHymnRowView: View {
    let serviceHymn: ServiceHymn
    let hymn: Hymn?
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text("\(serviceHymn.order + 1)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hymn?.title ?? "Unknown Hymn")
                    .font(.headline)
                
                if let author = hymn?.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = serviceHymn.notes, !notes.isEmpty {
                    Text("Note: \(notes)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button("Remove") {
                onRemove()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
    }
}

// MARK: - Add Hymn to Service Sheet

struct AddHymnToServiceSheet: View {
    let availableHymns: [Hymn]
    let onAddHymn: (Hymn) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredHymns: [Hymn] {
        if searchText.isEmpty {
            return availableHymns
        } else {
            return availableHymns.filter { hymn in
                hymn.title.localizedCaseInsensitiveContains(searchText) ||
                (hymn.author?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            if availableHymns.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No hymns available")
                        .font(.headline)
                    
                    Text("Please add some hymns first before creating services")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(filteredHymns) { hymn in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hymn.title)
                                .font(.headline)
                            
                            if let author = hymn.author, !author.isEmpty {
                                Text(author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(NSLocalizedString("btn.add", comment: "Add")) {
                            onAddHymn(hymn)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .searchable(text: $searchText, prompt: "Search hymns...")
            }
        }
        .navigationTitle("Add Hymn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
