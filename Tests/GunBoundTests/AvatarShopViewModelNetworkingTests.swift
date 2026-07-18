import Foundation
import Testing
@testable import GunBound
@testable import GunBoundProtocol

/// Drives `AvatarShopViewModel`'s networking paths through the `GameClient`
/// seam: the inventory fetch on enter and the buy-then-refresh round trip.
@Suite(.serialized, .timeLimit(.minutes(1))) @MainActor
struct AvatarShopViewModelNetworkingTests {

    @Test func onEnterFetchesInventory() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        let viewModel = AvatarShopViewModel(delegate: delegate)

        viewModel.onEnter()
        #expect(await TestServer.wait { delegate.session.avatar != nil })
    }

    @Test func buyingTheSelectedItemRunsThePurchasePath() async throws {
        let (delegate, server) = try await TestServer.delegate("admin")
        defer { withExtendedLifetime(server) {} }
        let viewModel = AvatarShopViewModel(delegate: delegate)
        viewModel.onEnter()
        _ = await TestServer.wait { delegate.session.avatar != nil }

        // Catalog for the default (.head) tab, then select the first card.
        viewModel.setCatalog(
            [AvatarShopViewModel.ShopItem(id: 1, name: "Hat", gold: 100, cash: 0, isMale: true)],
            for: .head
        )
        let card = AvatarShopViewModel.cardRect(at: 0)
        viewModel.handle(.pointerDown(x: card.x + 5, y: card.y + 5))
        #expect(viewModel.selectedItem != nil)

        // Click Buy: the purchase Task runs (buyAvatarItem → refresh). It may
        // be rejected server-side, but the path executes either way.
        let buy = AvatarShopViewModel.buyRect
        viewModel.handle(.pointerDown(x: buy.x + 5, y: buy.y + 5))
        _ = await TestServer.wait { !viewModel.isLoading }
    }
}
