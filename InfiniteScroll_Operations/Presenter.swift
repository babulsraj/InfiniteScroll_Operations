import Foundation
import UIKit

struct User: Codable, Equatable {
    var id: Int
    var avatar_url: String
    var login: String
    var image: UIImage? = nil
    
    private enum CodingKeys: String, CodingKey {
        case id, avatar_url, login
    }
    
    init(id: Int, avatar_url: String, login: String) {
        self.id = id
        self.avatar_url = avatar_url
        self.login = login
        self.image = nil
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

class Presenter: ObservableObject {
    @Published var users: [User] = []
    private var operations: [Int: ImageDownload] = [:]
    let downloadQueue = OperationQueue()
    
    init() {
        downloadQueue.maxConcurrentOperationCount = 5
    }
    
    func getData(index: Int) {
        let url = URL(string: "https://api.github.com/users?per_page=30&since=\(index+1)")!
        
        let session = URLSession.shared
        session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let users = try JSONDecoder().decode([User].self, from: data)
                DispatchQueue.main.async {
                    self?.users.append(contentsOf: users)
                }
            } catch {
                print("Error parsing users: \(error)")
            }
        }.resume()
    }
    
    func getImage(index: Int) -> Bool {
        guard index < users.count else { return false }
        
        // Cancel existing operation if any
        if let existingOperation = operations[index] {
            existingOperation.cancel()
            operations.removeValue(forKey: index)
        }
        
        let operation = ImageDownload(user: users[index])
        operations[index] = operation
        
        operation.completionBlock = { [weak self, weak operation] in
            guard let operation = operation, !operation.isCancelled else { return }
            
            DispatchQueue.main.async {
                if let image = operation.downloadedImage {
                    self?.users[index].image = image
                }
                self?.operations.removeValue(forKey: index)
            }
        }
        
        downloadQueue.addOperation(operation)
        return true
    }
    
    func shouldLoadData(id: Int) -> Bool {
        return (users.count - 3) == id
    }
}

class ImageDownload: AsyncOperation {
    private let user: User?
    private let url: URL?
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private(set) var downloadedImage: UIImage?
    
    init(user: User?) {
        self.user = user
        self.url = URL(string: user?.avatar_url ?? "")
        super.init()
    }
    
    override func main() {
        guard !isCancelled else {
            state = .isFinished
            return
        }
        
        guard let url = url else {
            state = .isFinished
            return
        }
        
        urlSession = URLSession(configuration: .default)
        dataTask = urlSession?.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, !self.isCancelled else { return }
            
            if let error = error {
                print("Error downloading image: \(error)")
                self.state = .isFinished
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                self.downloadedImage = image
            }
            
            self.state = .isFinished
        }
        
        dataTask?.resume()
    }
    
    override func cancel() {
        dataTask?.cancel()
        super.cancel()
    }
}

class AsyncOperation: Operation {
    enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }
    
    var state: State = .isReady {
        willSet {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }
    
    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool { state == .isExecuting }
    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }
    
    override func start() {
        guard !isCancelled else {
            state = .isFinished
            return
        }
        state = .isExecuting
        main()
    }
    
    override func cancel() {
        state = .isFinished
        super.cancel()
    }
}
