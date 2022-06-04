//
//  GIFCache.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-04.
//

import UIKit

class GIFImageCache: NSCache<NSString, UIImage> {
    
    /// The singleton instance of this class. (Use of singleton is selected, because a. we are
    /// not scoping this up for this exercise, and b. this is a transient cache and we likely won't need
    /// more than one cache even if we decided to scale the app. Also, another caching mechanism
    /// will have been developed by the time we need to scale this up anyway.)
    static let shared = GIFImageCache()
    
    func object(forItem item: GIFItem) -> UIImage? {
        let key = NSString(string: item.id)
        return self.object(forKey: key)
    }
    
    func cacheObject(_ image: UIImage, forItem item: GIFItem) {
        let key = NSString(string: item.id)
        self.setObject(image, forKey: key)
    }
    
}
