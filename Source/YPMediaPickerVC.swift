//
//  YPMediaPicker.swift
//  YPImagePicker
//
//  Created by Rahul RJ on 03/05/21.
//  Copyright © 2021 Yummypets. All rights reserved.
//

import Foundation
import Stevia
import Photos

open class YPMediaPickerVC: YPBottomPager, YPBottomPagerDelegate {
    
    let albumsManager = YPAlbumsManager()
    var shouldHideStatusBar = false
    var initialStatusBarHidden = false
    weak var imagePickerDelegate: ImagePickerDelegate?
    
    override open var prefersStatusBarHidden: Bool {
        return (shouldHideStatusBar || initialStatusBarHidden) && YPConfig.hidesStatusBar
    }
    
    /// Private callbacks to YPImagePicker
    public var didClose:(() -> Void)?
    public var didSelectItems: (([YPMediaItem]) -> Void)?
    
    enum Mode {
        case library
        case camera
        case video
    }
    
    private var libraryVC: YPLibraryVC?
    private var cameraVC: YPCameraVC?
    private var videoVC: YPVideoCaptureVC?
    
    var mode = Mode.camera
    var currentAlbumTitle: String?
    var previousSelectedButton: UIButton?

    var capturedImage: UIImage?
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = YPConfig.colors.safeAreaBackgroundColor
        
        delegate = self
        v.header.isHidden = true
        // Force Library only when using `minNumberOfItems`.
        if YPConfig.library.minNumberOfItems > 1 {
            YPImagePickerConfiguration.shared.screens = [.library]
        }
        
        // Library
        if YPConfig.screens.contains(.library) {
            libraryVC = YPLibraryVC()
            libraryVC?.delegate = self
        }
        
        // Camera
        if YPConfig.screens.contains(.photo) {
            cameraVC = YPCameraVC()
            cameraVC?.didCapturePhoto = { [weak self] img in
                self?.didSelectItems?([YPMediaItem.photo(p: YPMediaPhoto(image: img,
                                                                        fromCamera: true))])
            }
        }

        // Video
        if YPConfig.screens.contains(.video) {
            videoVC = YPVideoCaptureVC()
            videoVC?.didCaptureVideo = { [weak self] videoURL in
                self?.didSelectItems?([YPMediaItem
                    .video(v: YPMediaVideo(thumbnail: thumbnailFromVideoPath(videoURL),
                                           videoURL: videoURL,
                                           fromCamera: true))])
            }
        }
        
        // Show screens
        var vcs = [UIViewController]()
        for screen in YPConfig.screens {
            switch screen {
            case .library:
                if let libraryVC = libraryVC {
                    vcs.append(libraryVC)
                }
            case .photo:
                if let cameraVC = cameraVC {
                    vcs.append(cameraVC)
                }
            case .video:
                if let videoVC = videoVC {
                    vcs.append(videoVC)
                }
            }
        }
        controllers = vcs
        
        // Select good mode
        if YPConfig.screens.contains(YPConfig.startOnScreen) {
            switch YPConfig.startOnScreen {
            case .library:
                mode = .library
            case .photo:
                mode = .camera
            case .video:
                mode = .video
            }
        }
        
        // Select good screen
        if let index = YPConfig.screens.firstIndex(of: YPConfig.startOnScreen) {
            startOnPage(index)
        }
        
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
    }

    @objc func addAction() {
        print("Add")
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraVC?.v.shotButton.isEnabled = true
        self.navigationController?.isToolbarHidden = false
        updateMode(with: currentController)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldHideStatusBar = true
        initialStatusBarHidden = true
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    internal func pagerScrollViewDidScroll(_ scrollView: UIScrollView) { }
    
    func modeFor(vc: UIViewController) -> Mode {
        switch vc {
        case is YPLibraryVC:
            return .library
        case is YPCameraVC:
            return .camera
        case is YPVideoCaptureVC:
            return .video
        default:
            return .camera
        }
    }
    
    func pagerDidSelectController(_ vc: UIViewController) {
        updateMode(with: vc)
    }
    
    func updateMode(with vc: UIViewController) {
        stopCurrentCamera()
        
        // Set new mode
        mode = modeFor(vc: vc)
        
        // Re-trigger permission check
        if let vc = vc as? YPLibraryVC {
            vc.checkPermission()
        } else if let cameraVC = vc as? YPCameraVC {
            cameraVC.start()
        } else if let videoVC = vc as? YPVideoCaptureVC {
            videoVC.start()
        }
    
        updateUI()
    }
    
    func stopCurrentCamera() {
        switch mode {
        case .library:
            libraryVC?.pausePlayer()
        case .camera:
            cameraVC?.stopCamera()
        case .video:
            videoVC?.stopCamera()
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.isToolbarHidden = true
        shouldHideStatusBar = false
        stopAll()
    }
    
    @objc
    func navBarTapped() {
        let vc = YPAlbumVC(albumsManager: albumsManager)
        let navVC = UINavigationController(rootViewController: vc)
        navVC.navigationBar.tintColor = .ypLabel
        
        vc.didSelectAlbum = { [weak self] album in
            self?.libraryVC?.setAlbum(album)
            self?.currentAlbumTitle = album.title
            self?.setTitleViewWithTitle()
            navVC.dismiss(animated: true, completion: nil)
        }
        present(navVC, animated: true, completion: nil)
    }
    
    func updateUI() {
        if !YPConfig.hidesCancelButton {
            // Update Nav Bar state.
            if YPConfig.icons.showIconBackButton {
                navigationItem.leftBarButtonItem = UIBarButtonItem(image: YPConfig.icons.pickerBackButtonIcon, style: .done, target: self, action: #selector(close))
            } else {
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.cancel,
                                                                   style: .plain,
                                                                   target: self,
                                                                   action: #selector(close))
            }
        }
        switch mode {
        case .library:
            title = YPConfig.wordings.newPostTitle
            self.currentAlbumTitle = libraryVC?.title ?? ""
            setTitleViewWithTitle()
            let nextButton = UIButton()
            nextButton.addTarget(self, action: #selector(done), for: .touchUpInside)
            nextButton.setTitle(YPConfig.wordings.next, for: .normal)
            nextButton.setTitleColor(YPConfig.colors.navigationRightButtonTextColor, for: .normal)
            nextButton.setBackgroundColor(YPConfig.colors.navigationRightButtonColor, forState: .normal)
            nextButton.layer.masksToBounds = true
            nextButton.layer.cornerRadius = 4.0
            nextButton.titleLabel?.font = YPConfig.fonts.rightBarButtonFont
            nextButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
            nextButton.heightAnchor.constraint(equalToConstant: 24.0).isActive = true
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: nextButton)

            // Disable Next Button until minNumberOfItems is reached.
            navigationItem.rightBarButtonItem?.isEnabled =
                libraryVC!.selection.count >= YPConfig.library.minNumberOfItems

        case .camera:
            navigationItem.titleView = nil
            title = YPConfig.wordings.cameraTabTitle//cameraVC?.title
            navigationItem.rightBarButtonItem = nil
        case .video:
            navigationItem.titleView = nil
            title = YPConfig.wordings.cameraTabTitle//videoVC?.title
            navigationItem.rightBarButtonItem = nil
        }

        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .normal)
        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .disabled)
        navigationItem.leftBarButtonItem?.setFont(font: YPConfig.fonts.leftBarButtonFont, forState: .normal)
    }
    
    @objc
    func close() {
        if mode == .library {
            // Cancelling exporting of all videos
            print(mode)
            if let libraryVC = libraryVC {
                libraryVC.mediaManager.forseCancelExporting()
            }
            if let videoVC = videoVC {
                videoVC.videoHelper.cancelledRecording = true
            }
            self.didClose?()
        } else {
//            self.navigationController?.isToolbarHidden = false
            setTitleViewWithTitle()
            showPage(0)
        }
    }
    
    // When pressing "Next"
    @objc
    func done() {
        guard let libraryVC = libraryVC else { print("⚠️ YPPickerVC >>> YPLibraryVC deallocated"); return }
        
        if mode == .library {
            libraryVC.doAfterPermissionCheck { [weak self] in
                libraryVC.selectedMedia(photoCallback: { photo in
                    self?.didSelectItems?([YPMediaItem.photo(p: photo)])
                }, videoCallback: { video in
                    self?.didSelectItems?([YPMediaItem
                        .video(v: video)])
                }, multipleItemsCallback: { items in
                    self?.didSelectItems?(items)
                })
            }
        }
    }
    
    func stopAll() {
        libraryVC?.v.assetZoomableView.videoView.deallocate()
        videoVC?.stopCamera()
        cameraVC?.stopCamera()
    }
}

extension YPMediaPickerVC: YPLibraryViewDelegate {
    
    public func libraryViewDidTapNext() {
        libraryVC?.isProcessing = true
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = false
            self.libraryVC?.v.fadeInLoader()
            self.navigationItem.rightBarButtonItem = YPLoaders.defaultLoader
        }
    }
    
    public func libraryViewStartedLoadingImage() {
        //TODO remove to enable changing selection while loading but needs cancelling previous image requests.
        libraryVC?.isProcessing = true
        DispatchQueue.main.async {
            self.libraryVC?.v.fadeInLoader()
        }
    }
    
    public func libraryViewFinishedLoading() {
        libraryVC?.isProcessing = false
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = YPConfig.isScrollToChangeModesEnabled
            self.libraryVC?.v.hideLoader()
            self.updateUI()
        }
    }
    
    public func libraryViewDidToggleMultipleSelection(enabled: Bool) {
        var offset = v.header.frame.height
        if #available(iOS 11.0, *) {
            offset += v.safeAreaInsets.bottom
        }
        
        v.header.bottomConstraint?.constant = enabled ? offset : 0
        v.layoutIfNeeded()
        updateUI()
    }
    
    public func noPhotosForOptions() {
//        self.dismiss(animated: true) {
        self.imagePickerDelegate?.noPhotos()
        self.libraryVC?.v.hideLoader()
        self.showNoPhotosAlert()
//        }
    }
    
    public func libraryViewShouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool {
        return imagePickerDelegate?.shouldAddToSelection(indexPath: indexPath, numSelections: numSelections) ?? true
    }

//    Alert to be shown if no image is available in library
    public func showNoPhotosAlert() {
        let alert = UIAlertController(title:YPConfig.noPhotosErrorTitle , message: YPConfig.noPhotosErrorMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: YPConfig.noPhotosAlertButtonTitle, style: .default) { _ in
            print("Ok action")
            self.cameraTapped()
        }
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
}

extension YPMediaPickerVC {
    func setTitleViewWithTitle(aTitle: String? = nil) {
        let titleViewWidth = UIScreen.main.bounds.size.width / 2
        let libraryTitleView = UIView()
        libraryTitleView.frame = CGRect(x: 0, y: 0, width: titleViewWidth, height: 50)

        let label = UILabel()
        label.text = currentAlbumTitle ?? YPWordings().libraryTabTitle
        // Use YPConfig font
        label.font = YPConfig.fonts.pickerTitleFont
        label.font = YPConfig.fonts.segmentBarSelectedFont

        // Use custom textColor if set by user.
        label.textColor = YPConfig.colors.libraryTabSelectedColor

        let arrow = UIImageView()
        arrow.image = YPConfig.icons.arrowDownIcon
        arrow.image = arrow.image?.withRenderingMode(.alwaysTemplate)
        arrow.tintColor = YPConfig.colors.libraryTabSelectedColor
//
//        let attributes = UINavigationBar.appearance().titleTextAttributes
//        if let attributes = attributes, let foregroundColor = attributes[.foregroundColor] as? UIColor {
//            arrow.image = arrow.image?.withRenderingMode(.alwaysTemplate)
//            arrow.tintColor = foregroundColor
//        }

        let button = UIButton()
        button.addTarget(self, action: #selector(navBarTapped), for: .touchUpInside)
        button.setBackgroundColor(UIColor.white.withAlphaComponent(0.5), forState: .highlighted)

        libraryTitleView.sv(
            label,
            arrow,
            button
        )
        button.fillContainer()
        |-(>=8)-label.centerHorizontally()-arrow-(>=8)-|
        align(horizontally: label-arrow)

        label.firstBaselineAnchor.constraint(equalTo: libraryTitleView.bottomAnchor, constant: -14).isActive = true

        libraryTitleView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let cameraTitleView = UIView()
        cameraTitleView.frame = CGRect(x: 0, y: 0, width: titleViewWidth, height: 50)
        
        let cameraLabel = UILabel()
        cameraLabel.text = YPConfig.wordings.cameraTabTitle
        // Use YPConfig font
        cameraLabel.font = YPConfig.fonts.segmentBarFont
        
        // Use custom textColor if set by user.
        if let navBarTitleColor = UINavigationBar.appearance().titleTextAttributes?[.foregroundColor] as? UIColor {
            cameraLabel.textColor = navBarTitleColor
        }
            
        let cameraButton = UIButton()
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        cameraButton.setBackgroundColor(UIColor.white.withAlphaComponent(0.5), forState: .highlighted)
        
        cameraTitleView.sv(
            cameraLabel,
            cameraButton
        )
        cameraButton.fillContainer()
        |-(>=8)-cameraLabel.centerHorizontally()-(>=8)-|
        align(horizontally: cameraLabel)
        
        cameraLabel.firstBaselineAnchor.constraint(equalTo: cameraTitleView.bottomAnchor, constant: -14).isActive = true
        
        cameraTitleView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        self.navigationController?.isToolbarHidden = false

        if mode == .library {
            let stackView = UIStackView(arrangedSubviews: [libraryTitleView, cameraTitleView])
            stackView.distribution = .fillEqually
            let libraryTabButton = UIBarButtonItem(customView: stackView)
            self.toolbarItems = [libraryTabButton]
        } else {
//            let toolBarItems = [YPWordings().camera,YPWordings().videoTitle]
//            let segmentedControl = UISegmentedControl(items: toolBarItems)
//            segmentedControl.selectedSegmentIndex = 0
//            segmentedControl.backgroundColor = UIColor.clear
//            if #available(iOS 13.0, *) {
//                segmentedControl.selectedSegmentTintColor = UIColor(red: (85.0/255.0), green: (25.0/255.0), blue: (139.0/255.0), alpha: 1.0)
//            } else {
//                // Fallback on earlier versions
//            }
//            segmentedControl.addTarget(self, action: #selector(self.segmentedValueChanged(_:)), for: .valueChanged)
//            self.toolbarItems = [UIBarButtonItem(customView: segmentedControl)]
            let selectedColor = UIColor(red: (85.0/255.0), green: (25.0/255.0), blue: (139.0/255.0), alpha: 1.0)
            let photoButton = UIButton()
            photoButton.tag = 1
            photoButton.setTitle(YPWordings().cameraTitle, for: .normal)
            photoButton.setBackgroundColor(UIColor.clear, forState: .normal)
            photoButton.setBackgroundColor(selectedColor, forState: .selected)
            photoButton.setTitleColor(UIColor.darkGray, for: .normal)
            photoButton.setTitleColor(UIColor.white, for: .selected)
            photoButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
            photoButton.layer.masksToBounds = true
            photoButton.layer.cornerRadius = 16.0
            photoButton.titleLabel?.font = YPConfig.fonts.segmentBarFont
            photoButton.addTarget(self, action: #selector(self.segmentedValueChanged(_:)), for: .touchUpInside)
            let videoButton = UIButton()
            videoButton.tag = 2
            videoButton.setTitle(YPWordings().videoTitle, for: .normal)
            videoButton.setBackgroundColor(UIColor.clear, forState: .normal)
            videoButton.setBackgroundColor(selectedColor, forState: .selected)
            videoButton.setTitleColor(UIColor.darkGray, for: .normal)
            videoButton.setTitleColor(UIColor.white, for: .selected)
            videoButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
            videoButton.layer.masksToBounds = true
            videoButton.layer.cornerRadius = 16.0
            videoButton.titleLabel?.font = YPConfig.fonts.segmentBarFont
            videoButton.addTarget(self, action: #selector(self.segmentedValueChanged(_:)), for: .touchUpInside)

            let stackView = UIStackView(arrangedSubviews: [photoButton, videoButton])
            photoButton.isSelected = true
            previousSelectedButton = photoButton
            stackView.distribution = .fillEqually
            stackView.centerHorizontally()
            stackView.spacing = 10.0
            self.toolbarItems = [UIBarButtonItem(customView: stackView)]
        }
    }
    
    @objc func segmentedValueChanged(_ sender: UIButton?)
    {
        print("Selected Segment Index is : \(sender?.tag)")
        previousSelectedButton?.isSelected = false
        sender?.isSelected = true
        if sender?.tag == 1 {
            showPage(1)
        } else {
            showPage(2)
        }
        previousSelectedButton = sender
    }
    
    @objc func cameraTapped() {
        showPage(1)
        setTitleViewWithTitle()
    }
}
