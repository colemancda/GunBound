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

    private func item(_ id: Int, _ name: String = "Part") -> AvatarShopViewModel.ShopItem {
        AvatarShopViewModel.ShopItem(id: id, name: name, gold: 10_000, cash: 1_000, isMale: true)
    }

    /// 3×3 cards at the screenshot-measured origin/pitch.
    @Test func cardGridLayout() {
        let cell0 = AvatarShopViewModel.cardRect(at: 0)
        let cell1 = AvatarShopViewModel.cardRect(at: 1)
        let cell3 = AvatarShopViewModel.cardRect(at: 3)
        #expect(cell0 == Rect(x: 22, y: 70, width: 160, height: 156))
        #expect(cell1.x == 182 && cell1.y == cell0.y)
        #expect(cell3.x == 22 && cell3.y == 231)
    }

    /// The four bottom-left tabs map cap/cloth/glasses/flag to the Head /
    /// Body / Glasses / Flag part tables, per the store screen doc.
    @Test func categoryTabs() {
        #expect(AvatarShopViewModel.categoryTabs.map(\.category) == [.head, .body, .glasses, .flag])
        #expect(AvatarShopViewModel.categoryTabRect(at: 0) == Rect(x: 37, y: 561, width: 49, height: 32))
        #expect(AvatarShopViewModel.categoryTabRect(at: 3).x == 37 + 3 * 53)
    }

    /// Clicking a tab switches category and resets page/selection; the shop
    /// opens on Head (the original shows helmets first).
    @Test func tabClickSwitchesCategory() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.selectedCategory == .head)

        let tab = AvatarShopViewModel.categoryTabRect(at: 1)
        viewModel.handle(.pointerDown(x: tab.x + 2, y: tab.y + 2))
        #expect(viewModel.selectedCategory == .body)
    }

    /// The catalog pages 9 cards at a time; the pager clamps to the ends.
    @Test func catalogPaging() {
        let (viewModel, _) = makeViewModel()
        viewModel.setCatalog((0..<20).map { item($0) }, for: .head)
        #expect(viewModel.pageCount == 3)
        #expect(viewModel.visibleItems.count == 9)
        #expect(viewModel.visibleItems.first?.id == 0)

        let down = AvatarShopViewModel.scrollDownRect
        viewModel.handle(.pointerDown(x: down.x + 2, y: down.y + 2))
        #expect(viewModel.visibleItems.first?.id == 9)
        viewModel.handle(.pointerDown(x: down.x + 2, y: down.y + 2))
        #expect(viewModel.visibleItems.count == 2)  // 20 items → last page
        viewModel.handle(.pointerDown(x: down.x + 2, y: down.y + 2))
        #expect(viewModel.page == 2)  // clamped

        let up = AvatarShopViewModel.scrollUpRect
        viewModel.handle(.pointerDown(x: up.x + 2, y: up.y + 2))
        #expect(viewModel.page == 1)
    }

    /// Clicking a card selects it; Try re-dresses the local preview with the
    /// selected part (bit 15 = gender, bits 0–14 = id, in the tab's slot).
    @Test func selectAndTryOn() {
        let (viewModel, _) = makeViewModel()
        viewModel.setCatalog([item(0, "Space Marine"), item(5, "Rome Helmet")], for: .head)

        let card = AvatarShopViewModel.cardRect(at: 1)
        viewModel.handle(.pointerDown(x: card.x + 5, y: card.y + 5))
        #expect(viewModel.selectedItem?.name == "Rome Helmet")

        let baseline = viewModel.previewEquipped
        viewModel.handle(.pointerDown(x: AvatarShopViewModel.tryRect.x + 2, y: AvatarShopViewModel.tryRect.y + 2))
        let worn = AvatarEquipment(rawValue: viewModel.previewEquipped)
        #expect(worn.head.rawValue == 0x8005)
        #expect(viewModel.previewEquipped != baseline || AvatarEquipment(rawValue: baseline).head.rawValue == 0x8005)
    }

    /// The preview wears the fetched outfit when there's no try-on override,
    /// and the standard kit when nothing is known.
    @Test func previewFollowsSessionAvatar() {
        let (viewModel, delegate) = makeViewModel()
        #expect(viewModel.previewEquipped == AvatarShopViewModel.standardOutfit)

        delegate.session.avatar = PlayerAvatar(equipped: 0x0001_8001_8000_8005, inventory: [7])
        #expect(viewModel.previewEquipped == 0x0001_8001_8000_8005)
        #expect(viewModel.inventory == [7])
    }

    @Test func exitReturnsToLobby() {
        let (viewModel, delegate) = makeViewModel()
        let exit = AvatarShopViewModel.exitRect
        viewModel.handle(.pointerDown(x: exit.x + 5, y: exit.y + 5))
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
