//
//  ProfileService.swift
//  PhotoFlow
//
//  Created by Malik Timurkaev on 29.02.2024.
//

import UIKit

final class ProfileService {
    
    private(set) var profile: Profile?
    static let shared = ProfileService()
    
    private var task: URLSessionTask?
    let oauth2TokenStorage = OAuth2TokenStorage()
    
    private init() {}
    
    private enum ProfileServiceError: Error {
        case codeError
        case responseError
        case invalidRequest
    }
    
    func removeProfileInfo(){
        profile = nil
    }
    
    func fecthProfile(_ token: String, completion: @escaping (Result<Profile,Error>) -> Void) {
        
        assert(Thread.isMainThread)
        
        if task != nil {
            task?.cancel()
        }
        
        guard let request = makeRequstBody(token: token) else {
            completion(.failure(ProfileServiceError.codeError))
            return
        }
        
        let session: URLSessionDataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            DispatchQueue.main.async { [weak self] in
                
                guard let self = self else {return}
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode < 200 || response.statusCode  >= 300 {
                    
                    completion(.failure(ProfileServiceError.responseError))
                    return
                }
                
                if let data = data {
                    
                    do {
                        let profileResultInfo = try JSONDecoder().decode(ProfileResult.self, from: data)
                        let profile = Profile(profileResultInfo)
                        self.profile = profile
                        
                        completion(.success(profile))
                    } catch {
                        completion(.failure(ProfileServiceError.codeError))
                    }
                }
                self.task = nil
            }
        }
        
        task = session
        session.resume()
    }
    
    func makeRequstBody(token: String) -> URLRequest? {
        
        guard let url = URL(string: "https://api.unsplash.com/me") else {
            assertionFailure("Failed to create URL")
            return nil
        }
        
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(String(describing: token))", forHTTPHeaderField: "Authorization")
        
        return request
    }
}
