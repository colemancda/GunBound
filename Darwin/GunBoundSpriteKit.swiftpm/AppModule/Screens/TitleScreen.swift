//
//  TitleScreen.swift
//  GunBoundSpriteKit
//
//  Preview for the Title screen (state 1) — `titlemode.img`, advance on tap.
//

import SwiftUI
import GunBound
import GunBoundClient

#Preview("Title") {
    let delegate = ScreenPreviewDelegate()
    return ScreenPreviewView(screen: TitleScreen(viewModel: TitleViewModel(delegate: delegate)))
        .frame(width: 800, height: 600)
}
