//
//  Networking.swift
//  CSDTModelViewer
//
//  Created by Jing Wei Li on 5/1/21.
//  Copyright © 2021 Jing Wei Li. All rights reserved.
//

import Alamofire
import Combine
import Foundation

enum Networking {
    /// Download a file at the given url, returns a publisher in combine
    static func downloadFile(
        at link: String,
        headers: HTTPHeaders = [:],
        renameToExtension ext: String? = nil
    ) -> Future<URL, Error> {
        var dest: DownloadRequest.Destination? = nil
        if let ext = ext {
            dest = { url, res -> (URL, DownloadRequest.Options) in
                (
                    url.deletingPathExtension().appendingPathExtension(ext),
                    .removePreviousFile
                )
            }
        }
        
        return Future { promise in
            AF.download(link,headers: headers, to: dest).responseData { res in
                if let url = res.fileURL {
                    promise(.success(url))
                } else if let error = res.error {
                    promise(.failure(error))
                }
            }
        }
    }
}
