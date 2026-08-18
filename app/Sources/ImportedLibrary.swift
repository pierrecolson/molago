import Foundation

/// Les imports choisis par l'utilisateur, un fichier par source.
///
/// Un fichier unique pour toute la bibliothèque créerait un conflit dès que
/// deux appareils ajoutent chacun une vidéo avant la prochaine synchronisation.
/// Ici, deux imports différents ne touchent jamais au même fichier.
enum ImportedLibrary {
    static func save(_ item: LibraryItem, in directory: URL = Paths.imports) throws {
        guard item.text.slot.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(item)
        try data.write(to: directory.appending(path: "\(item.text.slot).json"), options: .atomic)
    }

    /// Un import précis. Le lecteur n'a que son texte ; pour réécrire l'anglais
    /// qui arrive, il lui faut l'import entier.
    static func item(slot: String, in directory: URL = Paths.imports) -> LibraryItem? {
        guard let data = try? Data(contentsOf: directory.appending(path: "\(slot).json")) else { return nil }
        return try? JSONDecoder().decode(LibraryItem.self, from: data)
    }

    static func read(from directory: URL = Paths.imports) async -> [LibraryItem] {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let urls = files.compactMap { file -> URL? in
            if file.pathExtension == "json" { return file }
            guard file.pathExtension == "icloud",
                  file.lastPathComponent.hasPrefix(".")
            else { return nil }
            let name = file.lastPathComponent.dropFirst().dropLast(".icloud".count)
            return directory.appending(path: String(name))
        }

        for url in urls { try? manager.startDownloadingUbiquitousItem(at: url) }

        // ponytail: cinq secondes de polling suffisent pour une petite
        // bibliothèque personnelle ; passer à NSMetadataQuery si des centaines
        // d'imports rendent les arrivées iCloud continues.
        for attempt in 0..<20 {
            if urls.allSatisfy({ manager.fileExists(atPath: $0.path(percentEncoded: false)) }) { break }
            if attempt < 19 { try? await Task.sleep(for: .milliseconds(250)) }
        }

        return urls
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(LibraryItem.self, from: $0) }
            .sorted { ($0.text.importedAt ?? $0.date) > ($1.text.importedAt ?? $1.date) }
    }
}
