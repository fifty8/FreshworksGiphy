//
//  ViewController.swift
//  FreshworksGiphy
//
//  Created by Teng Liu on 2022-06-03.
//

import UIKit
import CoreData
import Combine

fileprivate let GIPHY_API_KEY = "7IR46B8acr0j2ZvpjJMk43WjPGZagCu5"

class SearchViewController: UIViewController {

    private enum Section: Hashable { case main }
    private enum Item: Hashable {
        case gif(_: GIFItem)
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var collectionView: UICollectionView!
    private var searchController: UISearchController!
    @Published private var trendingGIFs: [GIFItem] = []
    @Published private var searchedGIFs: [GIFItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureDataSource()
        configurePipelines()
        fetchTrendingGIFItems()
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let s = CGFloat(10) // spacing
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(150))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = s
        section.contentInsets = .init(top: s, leading: s, bottom: s, trailing: s)
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func configureHierarchy() {
        view.backgroundColor = .systemBackground
        
        searchController = {
            let c = UISearchController(searchResultsController: nil)
            c.searchBar.placeholder = "Search GIFs"
            c.searchResultsUpdater = self
            c.obscuresBackgroundDuringPresentation = false
            self.navigationItem.searchController = c
            return c
        }()
        
        collectionView = {
            let v = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            v.delegate = self
            self.view.addSubview(v)
            return v
        }()
        
        // Navigation Items
        navigationItem.title = "Search GIFs"
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
    
    private func refreshDataSnapshot() {
        if let _ = formattedSearchTerm() {
            // Should display search results
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.main])
            snapshot.appendItems(searchedGIFs.map({Item.gif($0)}))
            dataSource.apply(snapshot)
        } else {
            // Should display trending
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.main])
            snapshot.appendItems(trendingGIFs.map({Item.gif($0)}))
            dataSource.apply(snapshot)
        }
    }
    
    // MARK: - Refresh Pipelines
    private var refreshPipelines: Set<AnyCancellable> = []
    private func configurePipelines() {
        refreshPipelines.removeAll()
        
        $trendingGIFs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDataSnapshot()
            }
            .store(in: &refreshPipelines)
        
        $searchTerm
            .debounce(for: 0.50, scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.refreshDataSnapshot()
                self.configureSearchRequestPipelines()
            }
            .store(in: &refreshPipelines)
        
        $searchedGIFs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDataSnapshot()
            }
            .store(in: &refreshPipelines)
    }
    
    // MARK: - Trending Web Request
    private var trendingRequestPipelines: Set<AnyCancellable> = []
    private func createTrendingRequest() -> URLRequest {
        let url = URL(string: "https://api.giphy.com/v1/gifs/trending?api_key=\(GIPHY_API_KEY)&limit=25&rating=g")!
        return URLRequest(url: url)
    }
    private func fetchTrendingGIFItems() {
        trendingRequestPipelines.removeAll()
        URLSession.shared.dataTaskPublisher(for: createTrendingRequest())
            .retry(1)
            .tryMap { element -> [String: Any] in
                guard let httpResponse = element.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else { throw URLError(.badServerResponse) }
                let json = try JSONSerialization.jsonObject(with: element.data, options: [])
                if let dict = json as? [String: Any] {
                    return dict
                } else {
                    throw URLError(.cannotParseResponse)
                }
            }
            .timeout(5, scheduler: RunLoop.main, customError: {
                return URLError(.timedOut)
            })
            .map { dict -> [GIFItem] in
                let imageInfoArray = dict["data"] as? [[String: Any]] ?? []
                return imageInfoArray.compactMap({GIFItem.instance(from: $0)})
            }
            .sink { [weak self] completion in
                #warning("Pending implementation")
                switch completion {
                case .failure(let error):
                    break
//                    self?.searchStatus = .error(error)
                case .finished:
                    break
//                    self?.searchStatus = .success
                }
            } receiveValue: { [weak self] receivedItems in
                self?.trendingGIFs = receivedItems
            }
            .store(in: &trendingRequestPipelines)
    }
    
    // MARK: - Search Web Request
    @Published private var searchTerm: String?
    private func createSearchURLRequest(with searchTerm: String) -> URLRequest {
        let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let url = URL(string: "https://api.giphy.com/v1/gifs/search?api_key=\(GIPHY_API_KEY)&q=\(encodedSearchTerm)&limit=25&offset=0&rating=g&lang=en")!
        return URLRequest(url: url)
    }
    private var searchRequestPipelines: Set<AnyCancellable> = []
    private func configureSearchRequestPipelines() {
        searchRequestPipelines.removeAll()
        guard let searchTerm = searchTerm, !searchTerm.isEmpty else {
            // do nothing. The preceeding `removeAll` shall stop any pending request
            return
        }
        let request = createSearchURLRequest(with: searchTerm)
        URLSession.shared.dataTaskPublisher(for: request)
            .retry(1)
            .tryMap { element -> [String: Any] in
                guard let httpResponse = element.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else { throw URLError(.badServerResponse) }
                let json = try JSONSerialization.jsonObject(with: element.data, options: [])
                if let dict = json as? [String: Any] {
                    return dict
                } else {
                    throw URLError(.cannotParseResponse)
                }
            }
            .timeout(5, scheduler: RunLoop.main, customError: {
                return URLError(.timedOut)
            })
            .map { dict -> [GIFItem] in
                let plantTemplateInfo = dict["data"] as? [[String: Any]] ?? []
                return plantTemplateInfo.compactMap({GIFItem.instance(from: $0)})
            }
            .sink { [weak self] completion in
                #warning("Implementation pending")
//                switch completion {
//                case .failure(let error):
//                    self?.searchStatus = .error(error)
//                case .finished:
//                    self?.searchStatus = .success
//                }
            } receiveValue: { [weak self] receivedItems in
                self?.searchedGIFs = receivedItems
            }
            .store(in: &searchRequestPipelines)
    }
}

extension SearchViewController: UISearchResultsUpdating {
    private func formattedSearchTerm() -> String? {
        if let trimmed = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        } else {
            return nil
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        // assign new value of search term and wait for `debounce` to kick in
        self.searchTerm = formattedSearchTerm()
    }
}

extension SearchViewController: UICollectionViewDelegate {
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
