import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DeleteConfirmationSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var deleteFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("删除任务？"))
                .font(.title2.bold())

            Text(L10n.tr("这会从 AriaFlow 中移除选中的任务。已下载的文件默认会保留在磁盘上。"))
                .foregroundStyle(.secondary)

            let exactTargets = store.selectedTask.map { store.deleteFileTargets(for: $0) } ?? []
            Toggle(L10n.tr("同时删除本地文件"), isOn: $deleteFiles)
                .disabled(exactTargets.isEmpty)

            if deleteFiles {
                let targets = store.selectedTask.map { store.deleteFileTargets(for: $0) } ?? []
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("将把 \(targets.count) 个文件或文件夹移到废纸篓。"))
                    ForEach(Array(targets.prefix(3).enumerated()), id: \.offset) { _, path in
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if targets.count > 3 {
                        Text(L10n.tr("另有 \(targets.count - 3) 项"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button(L10n.tr("取消")) {
                    store.showDeleteConfirmation = false
                }

                Button(deleteFiles ? L10n.tr("删除任务和文件") : L10n.tr("删除任务"), role: .destructive) {
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
