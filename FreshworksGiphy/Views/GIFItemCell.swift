//
//  GifItemView.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-04.
//

import UIKit
import Combine

fileprivate let USER_DEFAULTS = UserDefaults.standard

class GIFItemCell: UICollectionViewCell {
    private var gifItem: GIFItem!
    
    public func configure(for gifItem: GIFItem) {
        self.gifItem = gifItem
        configureHierarchy()
        configureRefreshPipelines()
        refreshAppearance()
    }
    
    private let imageCache = GIFImageCache.shared
    private var imageView: UIImageView!
    private var favoriteButton: UIButton!
    
    private var configured = false
    private func configureHierarchy() {
        guard !configured else { return }
        configured = true
        imageView = {
            let v = UIImageView()
            v.translatesAutoresizingMaskIntoConstraints = false
            v.contentMode = .scaleAspectFill
            v.clipsToBounds = true
            v.backgroundColor = .secondarySystemFill
            self.contentView.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                v.topAnchor.constraint(equalTo: contentView.topAnchor),
                v.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
            return v
        }()
        favoriteButton = {
            let dia = CGFloat(36) // button diametre
            let padding = CGFloat(6) // button padding to edge
            let v = UIButton()
            v.translatesAutoresizingMaskIntoConstraints = false
            let font = UIFont.preferredFont(forTextStyle: .body)
            v.setPreferredSymbolConfiguration(.init(font: font), forImageIn: .normal)
            v.layer.cornerRadius = dia/2
            v.addTarget(self, action: #selector(didClickFavorite(_:)), for: .touchUpInside)
            v.imageView?.tintColor = .white
            v.backgroundColor = .black.withAlphaComponent(0.75)
            self.contentView.addSubview(v)
            NSLayoutConstraint.activate([
                v.widthAnchor.constraint(equalToConstant: dia),
                v.heightAnchor.constraint(equalToConstant: dia),
                v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
                v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            ])
            return v
        }()
    }
    
    @objc private func didClickFavorite(_ sender: UIButton) {
        if self.gifItem.isFavorited {
            self.gifItem.removeFromFavorite()
        } else {
            self.gifItem.addToFavorite()
        }
    }
    
    private var refreshPipelines: Set<AnyCancellable> = []
    private func configureRefreshPipelines() {
        refreshPipelines.removeAll()
        self.gifItem.objectWillChange.makeConnectable().autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
            }
            .store(in: &refreshPipelines)
        
        USER_DEFAULTS.publisher(for: \.favoriteGIFs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
            }
            .store(in: &refreshPipelines)
    }
    
    private var downloadImagePipelines: Set<AnyCancellable> = []
    private func downloadImage() {
        downloadImagePipelines.removeAll()
        guard let url = self.gifItem?.originalImageURL else {return}
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data: Data, response: URLResponse) in
                return data
            }
            .compactMap({UIImage.gifImageWithData($0)})
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // Download request failed. Consider adding mechanism to notify user, etc.
                return
            } receiveValue: { [weak self] image in
                guard let self = self else {return}
                self.imageCache.cacheObject(image, forItem: self.gifItem)
                self.refreshAppearance()
            }
            .store(in: &downloadImagePipelines)
    }
    
    private func refreshAppearance() {
        if let localImage = self.gifItem.localImage {
            self.imageView.contentMode = .scaleAspectFill
            self.imageView.image = localImage
        } else {
            self.imageView.contentMode = .center
            self.imageView.image = .init(systemName: "hourglass")
            self.imageView.tintColor = .label
            self.downloadImage()
        }
        
        if gifItem.isFavorited {
            self.favoriteButton.setImage(.init(systemName: "heart.fill"), for: .normal)
        } else {
            self.favoriteButton.setImage(.init(systemName: "heart"), for: .normal)
        }
        
        // Fill image from local cache/file storage first; if failed to
        // obtain image locally, download it from the internet.
//        if let localImage = self.template.image {
//            content.image = localImage
//            self.imageCache.setObject(localImage, forKey: NSString(string: self.template.id))
//        } else if let downloadedImage = self.imageCache.object(forKey: NSString(string: self.template.id)) {
//            content.image = downloadedImage
//        } else {
//            content.image = .init(systemName: "leaf")
//            self.downloadImage()
//        }
    }
}
