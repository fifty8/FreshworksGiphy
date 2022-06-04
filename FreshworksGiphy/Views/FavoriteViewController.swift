//
//  ViewController.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-03.
//

import UIKit
import Combine

fileprivate let USER_DEFAULTS = UserDefaults.standard

class FavoriteViewController: UIViewController {

    private enum Section: Hashable { case main }
    private enum Item: Hashable {
        case gif(_: GIFItem)
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var collectionView: UICollectionView!
    private var segmentControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureDataSource()
        configurePipelines()
        reloadFavoriteItemsFromUserDefaults()
    }
    
    private enum LayoutMode {
        case grid, list
    }
    @Published private var layoutMode = LayoutMode.grid
    @Published private var favoritedGIFItems: [GIFItem] = []
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnv in
            let layoutMode = self?.layoutMode ?? .grid
            let s = CGFloat(10) // spacing
            
            switch layoutMode {
            case .grid:
                // Sizes
                let narrowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1))
                let wideSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(2/3), heightDimension: .fractionalHeight(1))
                let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(100))
                let sectionGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(400))
                
                // Items
                let narrowItem = NSCollectionLayoutItem(layoutSize: narrowSize)
                narrowItem.contentInsets = .init(top: s/2, leading: s/2, bottom: s/2, trailing: s/2)
                let wideItem = NSCollectionLayoutItem(layoutSize: wideSize)
                wideItem.contentInsets = .init(top: s/2, leading: s/2, bottom: s/2, trailing: s/2)
                
                // Groups
                let group111 = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [narrowItem, narrowItem, narrowItem])
//                group111.interItemSpacing = .fixed(s)
                let group21 = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [wideItem, narrowItem])
//                group21.interItemSpacing = .fixed(s)
                let group12 = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [narrowItem, wideItem])
//                group12.interItemSpacing = .fixed(s)
                
                // Section Group
                let sectionGroup = NSCollectionLayoutGroup.vertical(layoutSize: sectionGroupSize, subitems: [group111, group21, group111, group12])
//                sectionGroup.interItemSpacing = .fixed(s)
                
                let section = NSCollectionLayoutSection(group: sectionGroup)
                section.contentInsets = .init(top: s/2, leading: s/2, bottom: s/2, trailing: s/2)
//                section.interGroupSpacing = s
                return section
            case .list:
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(150))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = s
                section.contentInsets = .init(top: s, leading: s, bottom: s, trailing: s)
                return section
            }
        }
        return layout
    }
    
    private func configureHierarchy() {
        view.backgroundColor = .systemBackground
        
        collectionView = {
            let v = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            v.delegate = self
            self.view.addSubview(v)
            return v
        }()
        
        segmentControl = {
            let v = UISegmentedControl(items: ["Grid", "List"])
            v.translatesAutoresizingMaskIntoConstraints = false
            v.selectedSegmentIndex = 0
            v.addTarget(self, action: #selector(didChangeLayoutMode(_:)), for: .valueChanged)
            navigationItem.titleView = v
            return v
        }()
        
        // Navigation Items
        navigationItem.title = "Favorites"
    }
    
    private func configureDataSource() {
        
        let reg = UICollectionView.CellRegistration<GIFItemCell, GIFItem> { cell, indexPath, gifItem in
            cell.configure(for: gifItem)
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: self.collectionView)
        { collectionView, indexPath, item in
            switch item {
            case .gif(let gifItem):
                return collectionView.dequeueConfiguredReusableCell(using: reg, for: indexPath, item: gifItem)
            }
        }
        
    }
    
    private func reloadFavoriteItemsFromUserDefaults() {
        let userDefaults = USER_DEFAULTS
        let fetchedGIFs = userDefaults.favoriteGIFs.values
            .compactMap({ info -> GIFItem? in
                if let dict = info as? [String: Any],
                   let item = GIFItem.instance(from: dict) {
                    return item
                } else {
                    return nil
                }
            })
            .filter({$0.isFavorited})
            .sorted { lhs, rhs in
                if let lhsDate = lhs.dateFavorited, let rhsDate = rhs.dateFavorited {
                    return lhsDate > rhsDate
                } else {
                    return true
                }
            }
        self.favoritedGIFItems = fetchedGIFs
    }
    
    private func refreshDataSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(favoritedGIFItems.map({Item.gif($0)}))
        print(favoritedGIFItems.count, "Items Loaded")
        dataSource.apply(snapshot)
    }
    
    // MARK: - Refresh Pipelines
    private var refreshPipelines: Set<AnyCancellable> = []
    private func configurePipelines() {
        refreshPipelines.removeAll()
        
        $favoritedGIFItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDataSnapshot()
            }
            .store(in: &refreshPipelines)
        
        $layoutMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.collectionViewLayout.invalidateLayout()
            }
            .store(in: &refreshPipelines)
        
        USER_DEFAULTS.publisher(for: \.favoriteGIFs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadFavoriteItemsFromUserDefaults()
            }
            .store(in: &refreshPipelines)
        
    }
    
    // MARK: - Actions
    @objc private func didChangeLayoutMode(_ sender: UISegmentedControl) {
        self.layoutMode = sender.selectedSegmentIndex == 0 ? .grid : .list
    }
}

extension FavoriteViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .gif(gif) = item else { return }
        if let image = gif.localImage {
            let shareSheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            self.present(shareSheet, animated: true)
        } else {
            let alert = UIAlertController(title: "Image Downloading", message: "Please try again in a bit", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .cancel))
            self.present(alert, animated: true)
        }
    }
}

