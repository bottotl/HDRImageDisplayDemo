//
//  ViewController.swift
//  HDRDisplay
//
//  Created by jft0m on 2025/5/22.
//

import UIKit
import Photos
import CoreImage

class ViewController: UIViewController {

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 15.0, *) {
            imageView.preferredImageDynamicRange = .high
        }
        return imageView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = .black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestPhotoLibraryAccess()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(imageView)
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.fetchFirstImage()
                case .denied, .restricted:
                    self?.showAlert(message: "请在设置中允许访问相册")
                case .notDetermined:
                    break
                case .limited:
                    self?.fetchFirstImage()
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func fetchFirstImage() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // 专门获取 HDR 图片
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var hdrAsset: PHAsset?
        
        // 遍历查找第一张 HDR 图片
        fetchResult.enumerateObjects { asset, index, stop in
            if asset.mediaSubtypes.contains(.photoHDR) {
                hdrAsset = asset
                stop.pointee = true
            }
        }
        
        // 如果找到 HDR 图片就使用它，否则使用第一张图片
        let targetAsset = hdrAsset ?? fetchResult.firstObject
        
        if let firstAsset = targetAsset {
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isSynchronous = true
            option.deliveryMode = .highQualityFormat
            option.isNetworkAccessAllowed = true
            option.version = .current
            
            // 检查设备是否支持 HDR
            let isHDRSupported = UIScreen.main.traitCollection.displayGamut == .P3
            updateStatus("设备HDR支持: \(isHDRSupported ? "是" : "否")")
            
            manager.requestImageDataAndOrientation(for: firstAsset, options: option) { [weak self] imageData, dataUTI, orientation, info in
                DispatchQueue.main.async {
                    if let imageData = imageData {
                        // 创建临时文件来保存图片数据
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".heic")
                        
                        do {
                            try imageData.write(to: tempFile)
                            
                            // 使用 UIImageReader 加载图片
                            if #available(iOS 15.0, *) {
                                if let image = UIImageReader.default.image(contentsOf: tempFile) {
                                    self?.imageView.image = image
                                    
                                    // 检查图片是否支持 HDR
                                    let isHDRImage = firstAsset.mediaSubtypes.contains(.photoHDR)
                                    let imageSize = image.size
                                    self?.updateStatus("设备HDR支持: \(isHDRSupported ? "是" : "否")\n图片HDR支持: \(isHDRImage ? "是" : "否")\n图片尺寸: \(Int(imageSize.width))x\(Int(imageSize.height))\n图片格式: \(dataUTI ?? "未知")")
                                }
                            }
                            
                            // 删除临时文件
                            try? FileManager.default.removeItem(at: tempFile)
                        } catch {
                            self?.updateStatus("图片加载失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else {
            updateStatus("未找到任何图片")
        }
    }
    
    private func updateStatus(_ text: String) {
        statusLabel.text = text
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

