//
//  YPAlert.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 26/01/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

struct YPAlert {
    static func videoTooLongAlert(_ sourceView: UIView) -> UIAlertController {
        let msg = String(format: YPConfig.wordings.videoDurationPopup.tooLongMessage,
                         "\(YPConfig.video.libraryTimeLimit)")
        let alert = UIAlertController(title: YPConfig.wordings.videoDurationPopup.title,
                                      message: msg,
                                      preferredStyle: .actionSheet)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = CGRect(x: sourceView.bounds.midX,
												  y: sourceView.bounds.midY,
												  width: 0,
												  height: 0)
            popoverController.permittedArrowDirections = []
        }
        alert.addAction(UIAlertAction(title: YPConfig.wordings.ok, style: UIAlertAction.Style.default, handler: nil))
        return alert
    }
    
    static func videoTooShortAlert(_ sourceView: UIView) -> UIAlertController {
        let msg = String(format: YPConfig.wordings.videoDurationPopup.tooShortMessage,
                         "\(YPConfig.video.minimumTimeLimit)")
        let alert = UIAlertController(title: YPConfig.wordings.videoDurationPopup.title,
                                      message: msg,
                                      preferredStyle: .actionSheet)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = CGRect(x: sourceView.bounds.midX,
												  y: sourceView.bounds.midY,
												  width: 0,
												  height: 0)
            popoverController.permittedArrowDirections = []
        }
        alert.addAction(UIAlertAction(title: YPConfig.wordings.ok, style: UIAlertAction.Style.default, handler: nil))
        return alert
    }
    
    static func showAlert(_ sourceView: UIView, title: String, message: String, okAction: @escaping() -> Void ) -> UIAlertController {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = CGRect(x: sourceView.bounds.midX,
                                                  y: sourceView.bounds.midY,
                                                  width: 0,
                                                  height: 0)
            popoverController.permittedArrowDirections = []
        }
        alert.addAction(UIAlertAction(title: YPConfig.wordings.ok, style: UIAlertAction.Style.default, handler: { (_) in
            okAction()
        }))
        return alert
    }
}
