import SwiftUI
import MacCleanKit

struct MaintenanceView: View {
    @State private var taskStates: [MaintenanceTask: TaskState] = [:]
    @State private var executor = MaintenanceExecutor()

    enum TaskState {
        case idle
        case running
        case completed(String)
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Run system maintenance tasks to keep your Mac healthy")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button("Run All") { runAll() }
                    .buttonStyle(SuperEllipseButtonStyle(
                        gradient: ModuleTheme.performance.gradient,
                        size: CGSize(width: 100, height: 36)
                    ))
            }
            .padding(20)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(MaintenanceTask.allCases) { task in
                        taskRow(task)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text(task.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            statusView(for: task)

            Button {
                runTask(task)
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(isRunning(task))
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func statusView(for task: MaintenanceTask) -> some View {
        switch taskStates[task] {
        case .running:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .idle, .none:
            EmptyView()
        }
    }

    private func isRunning(_ task: MaintenanceTask) -> Bool {
        if case .running = taskStates[task] { return true }
        return false
    }

    private func runTask(_ task: MaintenanceTask) {
        taskStates[task] = .running
        Task {
            let result = await executor.execute(task)
            if result.success {
                taskStates[task] = .completed(result.output)
            } else {
                taskStates[task] = .failed(result.error ?? "Unknown error")
            }
        }
    }

    private func runAll() {
        for task in MaintenanceTask.allCases {
            runTask(task)
        }
    }
}
