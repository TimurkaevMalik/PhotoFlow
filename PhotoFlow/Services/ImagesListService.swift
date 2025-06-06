//
//  ImagesListService.swift
//  PhotoFlow
//
//  Created by Malik Timurkaev on 12.03.2024.
//

import Foundation

final class ImagesListService {
    
    static let shared = ImagesListService()
    var photos: [Photo] = []
    private let oauth2TokenStorage = OAuth2TokenStorage()
    static let didChangeNotification = Notification.Name(rawValue: "ImagesListServiceDidChange")
    static let didChangeLikeValue = Notification.Name(rawValue: "ImagesListServiceDidChangeLikeValue")
    
    private var lastLoadedPage: Int?
    private var fetchingPhotosTask: URLSessionTask?
    
    private init(){}
    
    private enum ImagesListServiceError: Error {
        case codeError
        case responseError
        case invalidRequest
        case dataError
    }
    
    func removePhotos(){
        self.photos.removeAll()
    }
    
    func fetchPhotosNextPage(token: String, comletion: @escaping (Result<[Photo],Error>) -> Void) {
        
        guard fetchingPhotosTask == nil else {
            return
        }
        
        let nextPage = (lastLoadedPage ?? 0) + 1
        lastLoadedPage = nextPage
        
        guard let request = makeRequstBody(pageNumber: nextPage, token: token) else {
            comletion(.failure(ImagesListServiceError.codeError))
            return
        }
        
        let session = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            DispatchQueue.main.async {
                
                guard let self = self else {
                    return
                }
                
                if let error = error {
                    comletion(.failure(error))
                    return
                }
                
                if let response = response as? HTTPURLResponse,
                   response.statusCode < 200 || response.statusCode >= 300 {
                    
                    comletion(.failure(ImagesListServiceError.responseError))
                    return
                }
                
                if let data = data {
                    do {
                        
                        let decodedData = try JSONDecoder().decode([PhotoResult].self, from: data)
                        
                        for photo in decodedData {
                            self.photos.append(Photo(photoResult: photo))
                        }
                        
                        NotificationCenter.default.post(
                            name: ImagesListService.didChangeNotification,
                            object: self,
                            userInfo: ["photos": decodedData])
                        
                        comletion(.success(self.photos))
                    } catch {
                        
                        comletion(.failure(ImagesListServiceError.dataError))
                    }
                } else {
                    comletion(.failure(ImagesListServiceError.dataError))
                }
                self.fetchingPhotosTask = nil
            }
        }
        fetchingPhotosTask = session
        session.resume()
    }
    
    
    func changeLike(photoId: String, isLike: Bool, token: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        
        guard let request = makeLikeRequestBody(photoId: photoId, isLike: isLike, token: token) else {
            completion(.failure(ImagesListServiceError.codeError))
            return
        }
        
        let session = URLSession.shared.dataTask(with: request) {[weak self] data, response, error in
            
            DispatchQueue.main.async {
                
                guard let self = self else {
                    return
                }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode < 200 || response.statusCode >= 300 {
                    
                    
                    completion(.failure(ImagesListServiceError.responseError))
                    return
                }
                
                if let data = data {
                    do {
                        
                        let decodedData = try JSONDecoder().decode(SinglePhotoDecoder.self, from: data)
                        
                        
                        if let index = self.photos.firstIndex(where: { $0.id == photoId }) {
                            
                            var photo = self.photos[index]
                            
                            photo.isLiked = decodedData.photo.isLiked
                            
                            self.photos.remove(at: index)
                            self.photos.insert(photo, at: index)
                            
                            NotificationCenter.default.post(
                                name: ImagesListService.didChangeLikeValue,
                                object: self,
                                userInfo: ["isLiked" : decodedData])
                            
                            completion(.success(decodedData.photo.isLiked))
                        } else {
                            completion(.failure(ImagesListServiceError.codeError))
                        }
                    } catch {
                        completion(.failure(ImagesListServiceError.codeError))
                    }
                }
            }
        }
        session.resume()
    }
    
    private func makeLikeRequestBody(photoId: String, isLike: Bool, token: String) -> URLRequest? {
        
        guard let url = URL(string: "https://api.unsplash.com/photos/\(photoId)/like") else {
            assertionFailure("Failed to create URL")
            return nil}
        
        var request = URLRequest(url: url)
        
        request.httpMethod = isLike ? "DELETE" : "POST"
        
        request.setValue("Bearer \(token))", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    private func makeRequstBody(pageNumber: Int, token: String) -> URLRequest? {
        var urlComponents = URLComponents(string: "https://api.unsplash.com/photos")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "page", value: "\(pageNumber)"),
            URLQueryItem(name: "per_page", value: "10"),
            URLQueryItem(name: "order_by", value: "latest")
        ]
        
        guard let url = urlComponents?.url else {
            assertionFailure("Failed to create URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token))", forHTTPHeaderField: "Authorization")
        
        return request
    }
}
