import Foundation
import Socket

/// GunBound Classic Server
public final class GunBoundServer {
    
    public let address: IPv4SocketAddress
    
    public init(address: IPv4SocketAddress) {
        self.address = address
    }
}
