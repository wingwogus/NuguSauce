import SwiftUI

struct LegalDocumentView: View {
    let document: LegalPolicyDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(document.title)
                        .font(SauceTypography.sectionTitle())
                        .foregroundStyle(SauceColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("버전 \(document.version) · 시행일 \(document.effectiveDate)")
                        .font(SauceTypography.supporting(.semibold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }

                markdownBody

                if let sourceURL = document.sourceURL {
                    Text("공개 약관 원문: \(sourceURL.absoluteString)")
                        .font(SauceTypography.metric(.regular))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.top, 24)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("확인") {
                    dismiss()
                }
            }
        }
    }

    private var markdownBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(markdownBlocks.indices, id: \.self) { index in
                markdownBlockView(markdownBlocks[index])
            }
        }
        .textSelection(.enabled)
    }

    private var markdownBlocks: [LegalMarkdownBlock] {
        LegalMarkdownBlock.parse(document.markdownBody, skippingTitle: document.title)
    }

    @ViewBuilder
    private func markdownBlockView(_ block: LegalMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            markdownText(text)
                .font(level <= 2 ? SauceTypography.sectionTitle(.bold) : SauceTypography.body(.bold))
                .foregroundStyle(SauceColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 8 : 2)

        case let .paragraph(text):
            markdownText(text)
                .font(SauceTypography.body())
                .foregroundStyle(SauceColor.onSurface)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

        case let .bullets(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("•")
                            .font(SauceTypography.body(.bold))
                            .foregroundStyle(SauceColor.primaryContainer)
                        markdownText(items[index])
                            .font(SauceTypography.body())
                            .foregroundStyle(SauceColor.onSurface)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func markdownText(_ text: String) -> Text {
        do {
            return Text(try AttributedString(markdown: text))
        } catch {
            return Text(text)
        }
    }
}

private enum LegalMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])

    static func parse(_ markdown: String, skippingTitle title: String) -> [LegalMarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [LegalMarkdownBlock] = []
        var paragraphLines: [String] = []
        var bulletItems: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else {
                return
            }

            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines.removeAll()
        }

        func flushBullets() {
            guard !bulletItems.isEmpty else {
                return
            }

            blocks.append(.bullets(bulletItems))
            bulletItems.removeAll()
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedLine.isEmpty else {
                flushParagraph()
                flushBullets()
                continue
            }

            if let heading = heading(from: trimmedLine) {
                flushParagraph()
                flushBullets()
                blocks.append(.heading(level: heading.level, text: heading.text))
            } else if trimmedLine.hasPrefix("- ") {
                flushParagraph()
                bulletItems.append(String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                flushBullets()
                paragraphLines.append(trimmedLine)
            }
        }

        flushParagraph()
        flushBullets()

        if case let .heading(_, headingTitle)? = blocks.first,
           headingTitle == title {
            blocks.removeFirst()
        }

        return blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else {
            return nil
        }

        let marker = String(repeating: "#", count: level)
        guard line.hasPrefix(marker + " ") else {
            return nil
        }

        let text = line
            .dropFirst(level)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        return (level, text)
    }
}
