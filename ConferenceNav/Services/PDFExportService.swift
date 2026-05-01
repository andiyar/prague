import Foundation
import WebKit
import UIKit

enum PDFExportError: Error {
    case missingOutputURL
}

@MainActor
final class PDFExportService: NSObject {
    enum Mode {
        case conferenceReport(picks: [Session], allSessions: [Session], notes: [SessionNote], userId: String)
        case allNotes(notes: [SessionNote])
    }

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<URL, Error>?
    private var outputURL: URL?

    func export(mode: Mode, mediaURLProvider: (String) -> URL?) async throws -> URL {
        let html = buildHTML(mode: mode, mediaURLProvider: mediaURLProvider)
        let baseDir = try writeHTMLAndCopyMedia(html: html, mode: mode, mediaURLProvider: mediaURLProvider)
        let htmlURL = baseDir.appendingPathComponent("report.html")
        let outputURL = baseDir.appendingPathComponent(mode.outputFilename)
        self.outputURL = outputURL

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 768, height: 1024), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseDir)
        }
    }

    // MARK: - HTML construction

    private func buildHTML(mode: Mode, mediaURLProvider: (String) -> URL?) -> String {
        let cssURL = Bundle.main.url(forResource: "report", withExtension: "css")
        let css = cssURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        var body = ""

        switch mode {
        case .conferenceReport(let picks, let allSessions, let notes, let userId):
            // Include picked sessions PLUS any sessions that have notes but weren't picked.
            // Cover stats still report `picks.count` so the user sees an accurate pick count.
            let pickedIds = Set(picks.map(\.id))
            let extraIds = Set(notes.map(\.sessionId)).subtracting(pickedIds)
            let extras = allSessions.filter { extraIds.contains($0.id) }
            let merged = (picks + extras).sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                return a.startsAt < b.startsAt
            }
            body += renderCover(userId: userId, picks: picks, notes: notes)
            body += renderTOC(sessions: merged)
            body += renderConferenceContent(sessions: merged, notes: notes)
        case .allNotes(let notes):
            body += renderAllNotes(notes: notes)
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(mode.title)</title>
            <style>\(css)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func renderCover(userId: String, picks: [Session], notes: [SessionNote]) -> String {
        let name = fullName(for: userId)
        let totalSketches = notes.reduce(0) { $0 + $1.sketchFilenames.count }
        let formattedToday = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        return """
        <div class="cover">
            <h1>EAPC 2026 — Conference Report</h1>
            <div class="author">\(name)</div>
            <div class="dates">14–16 May 2026 · Prague</div>
            <div class="stats">\(picks.count) picks · \(notes.count) notes · \(totalSketches) sketches</div>
            <div class="generated">Generated \(formattedToday)</div>
        </div>
        """
    }

    private func fullName(for userId: String) -> String {
        switch userId {
        case "ben": return "Benjamin Thomas"
        case "ron": return "Ronald Wai"
        default: return userId.capitalized
        }
    }

    private func renderTOC(sessions: [Session]) -> String {
        let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
        let dayLabels = [
            "2026-05-14": "Thursday, 14 May",
            "2026-05-15": "Friday, 15 May",
            "2026-05-16": "Saturday, 16 May",
        ]
        var html = "<nav class=\"toc\"><h2>Contents</h2><ol>"
        for date in dates {
            let day = sessions.filter { $0.date == date }
            if day.isEmpty { continue }
            html += "<li class=\"day\">\(dayLabels[date] ?? date)</li>"
            for s in day {
                html += "<li><a href=\"#session-\(s.id)\">\(escapeHTML(s.title))</a> &nbsp;<span style=\"color:#888\">\(s.startsAt)–\(s.endsAt) · \(s.venue)</span></li>"
            }
        }
        html += "</ol></nav>"
        return html
    }

    private func renderConferenceContent(sessions: [Session], notes: [SessionNote]) -> String {
        var html = ""
        for session in sessions {
            html += "<article class=\"session\" id=\"session-\(session.id)\">"
            html += "<div class=\"meta\">\(session.date) · \(session.startsAt)–\(session.endsAt) · \(escapeHTML(session.venue))</div>"
            html += "<h2>\(escapeHTML(session.title))</h2>"

            // Note(s) for this session
            let sessionNotes = notes.filter { $0.sessionId == session.id }
            for note in sessionNotes {
                if !note.presentationTitle.isEmpty {
                    html += "<h3>\(escapeHTML(note.presentationTitle))</h3>"
                    if !note.presenter.isEmpty {
                        html += "<div class=\"presenter\">\(escapeHTML(note.presenter))</div>"
                    }
                }
                html += renderMarkdownBody(note.body)
                for filename in note.photoFilenames {
                    html += "<figure><img src=\"photos/\(filename)\"></figure>"
                }
            }
            html += "</article>"
        }
        return html
    }

    private func renderAllNotes(notes: [SessionNote]) -> String {
        var html = "<h1 style=\"color:#002664\">Session Notes — EAPC 2026</h1>"
        for note in notes {
            html += "<article class=\"session\" id=\"note-\(note.noteKey)\">"
            html += "<div class=\"meta\">\(note.sessionDate) · \(note.sessionTime) · \(escapeHTML(note.sessionVenue))</div>"
            html += "<h2>\(escapeHTML(note.displayTitle))</h2>"
            if !note.presenter.isEmpty {
                html += "<div class=\"presenter\">\(escapeHTML(note.presenter))</div>"
            }
            html += renderMarkdownBody(note.body)
            for filename in note.photoFilenames {
                html += "<figure><img src=\"photos/\(filename)\"></figure>"
            }
            html += "</article>"
        }
        return html
    }

    /// Lightweight Markdown → HTML for the subset we use.
    private func renderMarkdownBody(_ md: String) -> String {
        var html = ""
        let paragraphs = md.components(separatedBy: "\n\n")
        for raw in paragraphs {
            let p = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { continue }

            if p.hasPrefix("# ")  { html += "<h2>\(escapeInline(String(p.dropFirst(2))))</h2>"; continue }
            if p.hasPrefix("## ") { html += "<h3>\(escapeInline(String(p.dropFirst(3))))</h3>"; continue }
            if p.hasPrefix("### "){ html += "<h4>\(escapeInline(String(p.dropFirst(4))))</h4>"; continue }

            if let imgHTML = renderImageParagraph(p) { html += imgHTML; continue }

            if p.hasPrefix("- ") || p.hasPrefix("* ") {
                html += "<ul>"
                for line in p.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                        html += "<li>\(escapeInline(String(trimmed.dropFirst(2))))</li>"
                    }
                }
                html += "</ul>"
                continue
            }

            html += "<p>\(escapeInline(p).replacingOccurrences(of: "\n", with: "<br>"))</p>"
        }
        return html
    }

    private func renderImageParagraph(_ p: String) -> String? {
        guard p.hasPrefix("![") else { return nil }
        guard let bracketEnd = p.firstIndex(of: "]"),
              p.index(after: bracketEnd) < p.endIndex,
              p[p.index(after: bracketEnd)] == "(",
              let parenEnd = p.firstIndex(of: ")") else { return nil }
        let path = String(p[p.index(p.index(after: bracketEnd), offsetBy: 1)..<parenEnd])
        return "<figure><img src=\"\(path)\"></figure>"
    }

    private func escapeInline(_ s: String) -> String {
        var x = escapeHTML(s)
        x = x.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        x = x.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        return x
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - File staging

    private func writeHTMLAndCopyMedia(html: String, mode: Mode, mediaURLProvider: (String) -> URL?) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EAPC-PDF-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let allFilenames = mode.allMediaFilenames
        for filename in allFilenames {
            guard let source = mediaURLProvider(filename) else { continue }
            let dest = dir.appendingPathComponent(filename)
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: source, to: dest)
        }

        try html.write(to: dir.appendingPathComponent("report.html"), atomically: true, encoding: .utf8)
        return dir
    }
}

extension PDFExportService.Mode {
    var title: String {
        switch self {
        case .conferenceReport: return "EAPC 2026 Conference Report"
        case .allNotes: return "EAPC 2026 Session Notes"
        }
    }
    var outputFilename: String {
        switch self {
        case .conferenceReport: return "EAPC-2026-Conference-Report.pdf"
        case .allNotes: return "EAPC-2026-Notes.pdf"
        }
    }
    var allMediaFilenames: [String] {
        switch self {
        case .allNotes(let notes), .conferenceReport(_, _, let notes, _):
            return notes.flatMap {
                $0.photoFilenames.map { "photos/\($0)" }
                    + $0.sketchFilenames.map { "sketches/\($0)" }
            }
        }
    }
}

extension PDFExportService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let outputURL = self.outputURL else {
                self.continuation?.resume(throwing: PDFExportError.missingOutputURL)
                self.continuation = nil
                return
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: outputURL)
                            self.continuation?.resume(returning: outputURL)
                        } catch {
                            self.continuation?.resume(throwing: error)
                        }
                    case .failure(let error):
                        self.continuation?.resume(throwing: error)
                    }
                    self.continuation = nil
                    self.webView = nil
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
            self.webView = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
            self.webView = nil
        }
    }
}
