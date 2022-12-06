import Foundation
import Socket

/// GunBound Classic Server
public actor GunBoundServer {
    
    public let address: IPv4SocketAddress
    
    public init(address: IPv4SocketAddress) {
        self.address = address
    }
    
    
}

internal extension GunBoundServer {
    
    actor Connection {
        
        let address: IPv4SocketAddress
        
        public init(address: IPv4SocketAddress) {
            self.address = address
        }
    }
}
