import Testing
@testable import GunBound
@testable import GunBoundProtocol

@Suite @MainActor
struct AvatarShopViewModelTests {

    private func makeViewModel() -> (AvatarShopViewModel, MockViewModelDelegate) {
        let network = NetworkConfig(username: "admin", password: "1234", serverAddress: "127.0.0.1", serverPort: 8370, brokerPort: 8372)
        let delegate = MockViewModelDelegate(network: network)
        return (AvatarShopViewModel(delegate: delegate), delegate)
    }

    @Test func itemSpriteNameIsFiveDigitPadded() {
        #expect(AvatarShopViewModel.itemSpriteName(for: 123) == "00123.img")
        #expect(AvatarShopViewModel.itemSpriteName(for: 7) == "00007.img")
        #expect(AvatarShopViewModel.itemSpriteName(for: 12345) == "12345.img")
    }

    @Test func itemGridLayout() {
        let (viewModel, _) = makeViewModel()
        let cell0 = viewModel.itemRect(at: 0)
        let cell1 = viewModel.itemRect(at: 1)
        let cell5 = viewModel.itemRect(at: 5)  // wraps to next row (5 columns)
        #expect(cell1.y == cell0.y && cell1.x > cell0.x)
        #expect(cell5.x == cell0.x && cell5.y > cell0.y)
    }

    @Test func itemsComeFromSessionAvatar() {
        let (viewModel, delegate) = makeViewModel()
        #expect(viewModel.items.isEmpty)
        delegate.session.avatar = PlayerAvatar(equipped: 0, inventory: [10, 20, 30])
        #expect(viewModel.items == [10, 20, 30])
    }

    @Test func itemsCappedToVisibleGrid() {
        let (viewModel, delegate) = makeViewModel()
        delegate.session.avatar = PlayerAvatar(equipped: 0, inventory: Array(0..<50).map(UInt32.init))
        #expect(viewModel.items.count == AvatarShopViewModel.maxVisibleItems)
    }

    @Test func categoryClickSelectsTab() {
        let (viewModel, _) = makeViewModel()
        viewModel.setRect(Rect(x: 100, y: 20, width: 60, height: 40), forCategoryAt: 2)
        viewModel.handle(.pointerDown(x: 120, y: 40))
        #expect(viewModel.selectedCategory == 2)
    }

    @Test func cancelReturnsToLobby() {
        let (viewModel, delegate) = makeViewModel()
        viewModel.cancelRect = Rect(x: 20, y: 540, width: 100, height: 40)
        viewModel.handle(.pointerDown(x: 40, y: 560))
        #expect(delegate.requestedTransitions == [.gameRoomList])
    }

    /// The decrypted avatar plaintext parses into equipped bitmask + item IDs.
    @Test func parseAvatarDecodesEquippedAndItems() {
        // equipped = 0x0102030405060708 (LE bytes), count = 2, items 100 & 256.
        var bytes: [UInt8] = [0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]
        bytes += [0x02, 0x00]                    // count = 2
        bytes += [100, 0, 0, 0]                  // item 100
        bytes += [0x00, 0x01, 0, 0]              // item 256
        let avatar = NetworkClient<GunBoundSocketIPv4TCP>.parseAvatar(bytes)
        #expect(avatar.equipped == 0x0102_0304_0506_0708)
        #expect(avatar.inventory == [100, 256])
    }

    @Test func parseAvatarToleratesShortData() {
        #expect(NetworkClient<GunBoundSocketIPv4TCP>.parseAvatar([1, 2, 3]).inventory.isEmpty)
    }
}
