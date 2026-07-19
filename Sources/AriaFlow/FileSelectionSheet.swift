import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileSelectionSheet: View {
    @EnvironmentObject private var store: AppStore

    private var selectedCount: Int {
        store.fileCandidates.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择要下载的文件")
                .font(.title2.bold())

            if store.fileCandidates.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在读取文件列表")
                        .font(.headline)
                    Text("Torrent 或 magnet 元数据解析完成后，可以选择要下载的文件。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                Toggle("全选", isOn: allSelectedBinding)
                    .font(.headline)

                Button("反选") {
                    for index in store.fileCandidates.indices {
                        store.fileCandidates[index].isSelected.toggle()
                    }
                }

                List {
                    ForEach($store.fileCandidates) { $file in
                        HStack {
                            Toggle(file.name, isOn: $file.isSelected)
                            Spacer()
                            Text(file.size)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(minHeight: 210)

                Text("已选择 \(selectedCount) 个文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消任务") {
                    Task {
                        await store.cancelFileSelection()
                    }
                }

                Button("开始下载") {
                    Task {
                        await store.startSelectedFilesDownload()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
        }
        .padding(22)
    }

    private var allSelectedBinding: Binding<Bool> {
        Binding {
            store.fileCandidates.allSatisfy(\.isSelected)
        } set: { newValue in
            for index in store.fileCandidates.indices {
                store.fileCandidates[index].isSelected = newValue
            }
        }
    }
}
