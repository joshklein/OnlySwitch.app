//
//  CheckUpdateTool.swift
//  OnlySwitch
//
//  Created by Jacklandrin on 2021/12/21.
//

import Foundation
import Alamofire
import SwiftUI

class GitHubPresenter: ObservableObject, GitHubRepositoryProtocol{
    
    static let shared = GitHubPresenter()
    
    @Published private var interactor = GitHubInteractor()
    var session = URLSession.shared

    var latestVersion:String {
        return interactor.latestVersion
    }
    
    var downloadURL:String {
        return interactor.downloadURL
    }
    
    var isTheNewestVersion: Bool {
        return interactor.isTheNewestVersion
    }
    
    var downloadCount:Int {
        return interactor.downloadCount
    }
    
    var updateHistoryInfo:String {
        return interactor.updateHistoryInfo
    }
    
    var updateHistoryList:[String] {
        return interactor.updateHistoryList
    }
    
    func checkUpdate(complete:@escaping (Result<Void,Error>) -> Void) {
        guard let url = makeRequestURL(path: .latestRelease) else {
            complete(.failure(RequestError.invalidURL))
            return
        }
        let request = AF.request(url)
        request.responseDecodable(of:GitHubRelease.self) { response in
            guard let latestRelease = response.value else {
                complete(.failure(RequestError.failed))
                return
            }
            do {
                try self.interactor.analyzeLastRelease(model: latestRelease)
                complete(.success(()))
            } catch {
                complete(.failure(error))
            }
        }
    }
    
    func requestReleases(complete:@escaping (Result<Void,Error>) -> Void) {
        guard let url = makeRequestURL(path: .releases) else {
            complete(.failure(RequestError.invalidURL))
            return
        }
        let request = AF.request(url, parameters: ["per_page": 100])

        request.responseDecodable(of:[GitHubRelease].self) { response in
            guard let releases = response.value else {
                complete(.failure(RequestError.failed))
                return
            }
            self.interactor.analyzeReleases(models: releases)
            complete(.success(()))
        }
    }
    
    func downloadDMG(complete:@escaping (Result<String,Error>) -> Void ) {
        let filePath = myAppPath?.appendingPathComponent(string: "OnlySwitch.dmg")
        guard let filePath = filePath else {
            complete(.failure(RequestError.invalidURL))
            return
        }
        let destination: DownloadRequest.Destination = { _, _ in
            return (URL(fileURLWithPath: filePath), [.removePreviousFile, .createIntermediateDirectories])
        }

        let request = AF.download(downloadURL, to: destination)
        request.response { response in
            if response.error == nil, let path = response.fileURL?.path {
                complete(.success(path))
            } else {
                complete(.failure(RequestError.failed))
            }
        }
    }
    
    func requestShortcutsJson(complete:@escaping (Result<[ShortcutOnMarket], Error>) -> Void) {
        guard let url = makeRequestURL(host:.userContent, path: .shortcutsJson) else {
            complete(.failure(RequestError.invalidURL))
            return
        }
        let request = AF.request(url)
        request.responseDecodable(of:[ShortcutOnMarket].self) { response in
            guard let list = response.value else {
                complete(.failure(RequestError.failed))
                return
            }
            complete(.success(list))
        }
    }
    
    func requestEvolutionJson() async throws -> [EvolutionGalleryModel] {
        guard let url = makeRequestURL(host: .userContent, path: .evolutionJson) else {
            throw RequestError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = ["Accept": "application/json"]
        request.timeoutInterval = 60
        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try decode(data: data, type: [EvolutionGalleryModel].self)
        return result
    }

    func downloadFile(from url: URL, to desination: URL) async throws {
        let (localURL, _) = try await session.download(from: url)
        do {
            let folderUrl = desination.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: folderUrl.path) {
               try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
            }
            try FileManager.default.moveItem(at: localURL, to: desination)
        } catch {
            print(error.localizedDescription)
        }
    }

    func downloadFile(from url: URL, name: String) async throws -> String {
        let destination = myAppPath?.appendingPathComponent(string: name)
        guard let destination else {
            throw RequestError.invalidURL
        }
        try await downloadFile(from: url, to: URL(fileURLWithPath: destination))
        return destination
    }
}
