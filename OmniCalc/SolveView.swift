import SwiftUI
import PhotosUI

struct SolveView: View {
    @Environment(\.theme) private var theme
    @State private var problem = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageJPEG: Data?
    @State private var preview: CGImage?
    @State private var solution: AISolution?
    @State private var check: String?
    @State private var loading = false
    @State private var error: String?
    @State private var copied = false
    @FocusState private var focused: Bool

    private var canSolve: Bool {
        !loading && (imageJPEG != nil || !problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if AIConfig.isMissingKey {
                            Label("Add your Gemini API key in Secrets.swift to enable this tab.", systemImage: "key.fill")
                                .font(.footnote).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            TextEditor(text: $problem)
                                .frame(minHeight: 100).focused($focused)
                                .scrollContentBackground(.hidden)
                                .overlay(alignment: .topLeading) {
                                    if problem.isEmpty {
                                        Text("Type a question or add a photo of one.\ne.g. A car travels 150 km in 2 h 15 min. Average speed in m/s?")
                                            .foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                }
                            HStack {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Label(preview == nil ? "Add photo" : "Change photo", systemImage: "photo")
                                }
                                if preview != nil {
                                    Button("Remove", role: .destructive) {
                                        withAnimation(.smooth) { pickerItem = nil; imageJPEG = nil; preview = nil }
                                    }
                                }
                                Spacer()
                            }
                            if let cg = preview {
                                Image(decorative: cg, scale: 1).resizable().scaledToFit()
                                    .frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }.cardStyle()

                        Button { Task { await solve() } } label: {
                            HStack { if loading { ProgressView() }; Text(loading ? "Solving…" : "Solve").fontWeight(.semibold) }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!canSolve)

                        if let error { Text(error).foregroundStyle(.red).font(.callout).transition(.opacity) }
                        if let s = solution { resultCard(s).transition(.opacity.combined(with: .move(edge: .bottom))) }
                    }
                    .padding().frame(maxWidth: 700).frame(maxWidth: .infinity)
                    .animation(.smooth(duration: 0.35), value: solution?.answer)
                    .animation(.smooth(duration: 0.25), value: error)
                    .animation(.smooth(duration: 0.25), value: preview != nil)
                }
            }
            .navigationTitle("AI Solver")
            .onChange(of: pickerItem) { _, item in Task { await loadPhoto(item) } }
        }
    }

    private func resultCard(_ s: AISolution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let i = s.interpretation, !i.isEmpty { Text(i).font(.subheadline).foregroundStyle(.secondary) }
            ForEach(Array(s.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)").font(.caption.bold()).frame(width: 22, height: 22)
                        .background(theme.accent.opacity(0.2), in: Circle())
                    Text(step)
                }
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Answer").font(.caption).foregroundStyle(.secondary)
                    Text(s.answer).font(.title2.weight(.semibold)).foregroundStyle(theme.accent).textSelection(.enabled)
                }
                Spacer()
                Button { copyToClipboard(s.answer); copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(PressableStyle())
            }
            if let c = check {
                Label("Calculator check: \(c)", systemImage: "checkmark.seal.fill")
                    .font(.footnote).foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @MainActor private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let r = ImageTools.jpeg(from: data) else { return }
        withAnimation(.smooth) { imageJPEG = r.jpeg; preview = r.preview }
    }

    @MainActor private func solve() async {
        focused = false; loading = true; error = nil; solution = nil; check = nil
        defer { loading = false }
        do {
            let s = try await AISolver.solve(problem, image: imageJPEG)
            solution = s
            if let e = s.expression, !e.isEmpty, let v = try? ExpressionEngine().evaluate(e) {
                check = ExpressionEngine.format(v)
            }
        } catch let e as URLError where [.cannotFindHost, .notConnectedToInternet, .cannotConnectToHost].contains(e.code) {
            self.error = "Couldn't reach the internet. If you're on Mac, make sure App Sandbox is removed (see README)."
        } catch { self.error = error.localizedDescription }
    }
}
