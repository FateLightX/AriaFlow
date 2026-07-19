import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DeleteConfirmationSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var deleteFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("删除任务？")
                .font(.title2.bold())

            Text("这会从 AriaFlow 中移除选中的任务。已下载的文件默认会保留在磁盘上。")
                .foregroundStyle(.secondary)

            Toggle("同时删除本地文件", isOn: $deleteFiles)

            if deleteFiles {
                let targets = store.selectedTask.map { store.deleteFileTargets(for: $0) } ?? []
                VStack(alignment: .leading, spacing: 4) {
                    Text("将把 \(targets.count) 个文件或文件夹移到废纸篓。")
                    ForEach(Array(targets.prefix(3).enumerated()), id: \.offset) { _, path in
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if targets.count > 3 {
                        Text("另有 \(targets.count - 3) 项")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") {
                    store.showDeleteConfirmation = false
                }

                Button(deleteFiles ? "删除任务和文件" : "删除任务", role: .destructive) {
                    Task {
                        await store.deleteSelected(deleteFiles: deleteFiles)
                        store.showDeleteConfirmation = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
    }
}
