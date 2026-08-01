//
//  RunTogetherApp.swift
//  RunTogether
//
//  Created by William Pickard on 2026/08/01.
//

import SwiftUI

@main
struct RunTogetherApp: App {

    @State private var runners = RunnerStore()
    @State private var log = SessionLog()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(runners)
                .environment(log)
        }
    }
}
