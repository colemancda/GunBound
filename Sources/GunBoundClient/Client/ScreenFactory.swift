import GunBound

/// Builds the `GameScreen` (view + view model pair) for a given `ClientMode`
/// — the one place that knows the full screen flow (Logo1 -> Logo2 -> Title
/// -> ServerSelect -> RoomList -> ReadyRoom/AvatarShop -> Loading ->
/// InBattle). Shared by every rendering backend (`GunBoundSDL3` today, a
/// future SpriteKit client tomorrow) so the flow only needs to be defined
/// once.
@MainActor
public func makeGameScreen(for mode: ClientMode, delegate: ViewModelDelegate) -> GameScreen? {
    switch mode {
    case .logo1:
        return LogoScreen(viewModel: LogoViewModel(imageName: "logomode.img", musicName: "logo.mp3", next: .logo2, delegate: delegate))
    case .logo2:
        return LogoScreen(viewModel: LogoViewModel(imageName: "logomode2.img", musicName: "logo2.mp3", next: .title, delegate: delegate))
    case .title:
        return TitleScreen(viewModel: TitleViewModel(delegate: delegate))
    case .serverSelect:
        return ServerSelectScreen(viewModel: ServerSelectViewModel(delegate: delegate))
    case .gameRoomList:
        return GameRoomListScreen(viewModel: GameRoomListViewModel(delegate: delegate))
    case .readyRoom:
        return ReadyRoomScreen(viewModel: ReadyRoomViewModel(delegate: delegate))
    case .avatarShop:
        return AvatarShopScreen(viewModel: AvatarShopViewModel(delegate: delegate))
    case .loading:
        return LoadingScreen(viewModel: LoadingViewModel(delegate: delegate))
    case .inGameSession:
        return InBattleScreen(viewModel: InBattleViewModel(delegate: delegate))
    default:
        return nil
    }
}
