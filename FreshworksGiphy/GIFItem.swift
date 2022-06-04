//
//  GIFDisplayItem.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-04.
//

import UIKit
import Combine
import Photos

fileprivate let USER_DEFAULTS = UserDefaults.standard

class GIFItem: Hashable, ObservableObject {
    static func == (lhs: GIFItem, rhs: GIFItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    let id: String
    let originalImageURL: URL
    
    init(id: String, originalImageURL: URL, dateFavorited: Date? = nil) {
        self.id = id
        self.originalImageURL = originalImageURL
    }
    
}

extension GIFItem {
    /// Returns an UIImage object from local stores. This will first attempt to fetch it from the cache;
    /// failing that, it will attempt to find it from file storage. If both methods fail, return `nil`.
    var localImage: UIImage? {
        let cache = GIFImageCache.shared
        if let image = cache.object(forItem: self) {
            // return from cache
            return image
        } else if let diskData = self.imageDataFromDisk,
                  let image = UIImage.gifImageWithData(diskData) {
            // return from disk data (after caching it for faster access next time)
            cache.cacheObject(image, forItem: self)
            return image
        } else {
            return nil
        }
    }
    
    /// Get-only property. Use `addToFavorite` and `removeFromFavorite` methods to change this value.
    var dateFavorited: Date? {
        let userDefaults = USER_DEFAULTS
        if let info = userDefaults.favoriteGIFs[self.id] as? [String: Any],
           let dateDouble = info["dateFavorited"] as? Double {
            return Date(timeIntervalSince1970: dateDouble)
        } else {
            return nil
        }
    }
    
    var isFavorited: Bool { return (dateFavorited != nil) }
    
    func addToFavorite() {
        guard !self.isFavorited else { return }
        let userDefaults = USER_DEFAULTS
        var dict = self.dictionaryRepresentation
        dict["dateFavorited"] = Date().timeIntervalSince1970
        userDefaults.favoriteGIFs[self.id] = dict
        self.objectWillChange.send()
        saveImageDataToDiskIfHaveNot()
    }
    
    func removeFromFavorite() {
        guard self.isFavorited else { return }
        let userDefaults = USER_DEFAULTS
        userDefaults.favoriteGIFs.removeValue(forKey: self.id)
        self.objectWillChange.send()
    }
}

// MARK: - Photo Saving
extension GIFItem {
    func saveToPhotoLibrary(completion: @escaping ((Bool, Error?) -> Void)) {
        
    }
}

// MARK: - Disk caching for favourites
extension GIFItem {
    /// The file URL for the on-disk cache of the image. Two things pending:
    /// 1. the mehanism to clean up old and unused files
    /// 2. choosing a better location other than `temporaryDirectory` but since it's not oftenly purged
    /// by the OS we're good for now
    private var fileURL: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(self.id).gif")
    }
    
    private var imageDataFromDisk: Data? {
        if let data = try? Data(contentsOf: fileURL) {
            return data
        } else {
            return nil
        }
    }
    
    private func saveImageDataToDiskIfHaveNot() {
        // Skip the step if it has been saved to disk before.
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { return }
            print("Saving \(self.id)")
            let fileURL = self.fileURL
            let webURL = self.originalImageURL
            // Steps below should have error handling. Using `try?` to simplify the
            // flow for sake of the exercise
            if let data = try? Data(contentsOf: webURL) {
                try? data.write(to: fileURL)
            }
        }
    }
}

// MARK: - Data Conversion
extension GIFItem {
    /// Create a struct instance from a dictionary. If data isn't in the expected format, returns `nil`.
    static func instance(from dict: [String: Any]) -> GIFItem? {
        // Check if `type` key is of value `gif`, and there's an `id` value present.
        guard let typeValue = dict["type"] as? String,
              typeValue == "gif" else { return nil }
        guard let giphyID = dict["id"] as? String else { return nil }
        
        // Check if there is a valid URL for original image
        guard let imagesDict = dict["images"] as? [String: Any] else { return nil }
        guard let originalImageDict = imagesDict["original"] as? [String: Any],
              let originalImageURLString = originalImageDict["url"] as? String,
              let originalImageURL = URL(string: originalImageURLString)
        else { return nil }
        
        return GIFItem(id: giphyID, originalImageURL: originalImageURL)
    }
    
    /// Encode this instance into a dictionary for persistence.
    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [:]
        dict["type"] = "gif"
        dict["id"] = self.id
        dict["images"] = ["original": ["url": self.originalImageURL.absoluteString]]
        return dict
    }
}
