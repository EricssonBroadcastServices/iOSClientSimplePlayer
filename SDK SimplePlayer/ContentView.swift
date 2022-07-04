//
//  ContentView.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import SwiftUI
import iOSClientExposurePlayback

struct ContentView: View {
    
    @State var assetId: String = ""
    @State var shouldStartPlay: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                let playable = AssetPlayable(assetId: assetId)
                NavigationLink(destination: CustomVideoPlayer(playable: playable)) {
                    Text("Play Asset")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(15.0)
                }
                .navigationTitle("RBM SDK Player")
                .padding(20)
                
            }
        }
        
    }
    
    fileprivate func play() {
        print(" play clicked ")
        shouldStartPlay = true
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
