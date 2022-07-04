//
//  DownloadManager.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import Foundation
import iOSClientDownload
import iOSClientExposure
import iOSClientExposureDownload

final class DownloadManager: EnigmaDownloadManager {
    static let shared = DownloadManager()


    var assetId: String = ""
    
    var env: iOSClientExposure.Environment {
        .init(
            baseUrl: "",
            customer: "",
            businessUnit: ""
        )
    }

    var sessionToken: SessionToken {
        .init(
            value: ""
        )
    }

    var exposureDownloadTask: ExposureDownloadTask?

    func download( assetId: String ) {
        
        self.assetId = assetId
        
        exposureDownloadTask = self.enigmaDownloadManager.download(
            assetId: assetId,
            sessionToken: self.sessionToken,
            environment: self.env
        ).prepare(lazily: false )

 
        exposureDownloadTask?.onPrepared(callback: { task in
            print("Foo: onPrepared")
            self.exposureDownloadTask?.resume()
        })
        .onResumed(callback: { _ in
            print("Foo: onResumed")
        })
        .onProgress { _, progress in
            print("Foo: onProgress \(progress)")
        }
        .onSuspended(callback: { _ in
            print("Foo: onSuspended")
        })
        .onCompleted { task, url in
            print("Foo: onCompleted")
        }
        .onError { _, _, error in
            print("Foo: onError \(error)")
            
            self.exposureDownloadTask?.cancel()
            let _ = self.enigmaDownloadManager.removeDownloadedAsset(assetId: assetId, sessionToken: self.sessionToken, environment: self.env)
        }

        
    }

    func suspend() {
        exposureDownloadTask?.suspend()
    }
    
    func cancel() {
        exposureDownloadTask?.cancel()
        let _ = self.enigmaDownloadManager.removeDownloadedAsset(assetId: self.assetId, sessionToken: self.sessionToken, environment: self.env)
    }

    func resume() {
        exposureDownloadTask?.resume()
    }
    
}
