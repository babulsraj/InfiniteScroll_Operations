import SwiftUI

struct ContentView: View {
    @StateObject private var presenter = Presenter()
    
    var body: some View {
        List(presenter.users, id: \.id) { user in
            HStack {
                if let image = user.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                }
                
                Text(user.login)
                    .font(.headline)
            }
            .onAppear {
                if presenter.shouldLoadData(id: user.id) {
                    presenter.getData(index: user.id)
                }
                presenter.getImage(index: presenter.users.firstIndex(of: user) ?? 0)
            }
        }
        .onAppear {
            if presenter.users.isEmpty {
                presenter.getData(index: 0)
            }
        }
    }
}
