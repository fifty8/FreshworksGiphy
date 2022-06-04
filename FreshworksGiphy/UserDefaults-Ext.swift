//
//  UserDefaults-Ext.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-04.
//

import Foundation

extension UserDefaults {
    /// We are adopting UserDefaults as the store for favourited GIFs. This might get unwieldy
    /// if we are talking about 10,000 of favourited items, but for now it will do just fine. Core
    /// Data might be a candidate for future optimization on info persistence.
    @objc var favoriteGIFs: [String: Any] {
        get {
            return dictionary(forKey: "favorite_gifs") ?? [:]
        }
        set {
            self.set(newValue, forKey: "favorite_gifs")
        }
    }
}
