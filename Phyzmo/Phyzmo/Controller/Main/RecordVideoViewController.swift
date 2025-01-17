//
//  RecordVideoViewController.swift
//  Phyzmo
//
//  Created by Athena Leong on 11/9/19.
//  Copyright © 2019 Athena. All rights reserved.
//

import Foundation
import MobileCoreServices
import Firebase
import AVKit
import AVFoundation
import Firebase

extension MainViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        
        guard
            let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
          mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL,
          UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path)
          else {
            return
        }
        
        // Handle a movie capture
        print("url.path", url.path)
        print("info", info)
        loading.isHidden = false
        loading.startAnimating()
        blurEffectView.isHidden = false
        encodeVideo(at: url, completionHandler: uploadToFirebase)
        
    }
    
    /* CONVERT TO MP4 */
    func encodeVideo(at videoURL: URL, completionHandler: ((URL?, Error?) -> Void)?)  {
        let avAsset = AVURLAsset(url: videoURL, options: nil)
            
        let startDate = Date()
            
        //Create Export session
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
            completionHandler?(nil, nil)
            return
        }
            
        //Creating temp path to save the converted video
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        let filePath = documentsDirectory.appendingPathComponent("rendered-Video.mp4")
            
        //Check if the file already exists then remove the previous file
        if FileManager.default.fileExists(atPath: filePath.path) {
            do {
                try FileManager.default.removeItem(at: filePath)
            } catch {
                completionHandler?(nil, error)
            }
        }
            
        exportSession.outputURL = filePath
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 0)
        let range = CMTimeRangeMake(start: start, duration: avAsset.duration)
        exportSession.timeRange = range
            
        exportSession.exportAsynchronously(completionHandler: {() -> Void in
            switch exportSession.status {
            case .failed:
                print(exportSession.error ?? "NO ERROR")
                completionHandler?(nil, exportSession.error)
            case .cancelled:
                print("Export canceled")
                completionHandler?(nil, nil)
            case .completed:
                //Video conversion finished
                let endDate = Date()
                    
                let time = endDate.timeIntervalSince(startDate)
                print(time)
                print("Successful!")
                print(exportSession.outputURL ?? "NO OUTPUT URL")
                completionHandler?(exportSession.outputURL, nil)
                    
                default: break
            }
                
        })
    }
    func uploadToFirebase(url: URL?, error: Error?) {
        DispatchQueue.main.async {
            self.blurEffectView.isHidden = false
            self.logOutButton.isEnabled = false
            self.selectButton.isEnabled = false
            self.collectionView.isUserInteractionEnabled = false
            self.cameraButton.isEnabled = false
            self.statusLabel.isHidden = false
            self.statusLabel.text = "Uploading video"
            self.statusLabel.textColor = .white
        }
        
        if error != nil {
            return
        }
        let currentUserId = Auth.auth().currentUser!.uid
        print("currentUserId", currentUserId)
        let databaseReference = Database.database().reference().child("Users").child(currentUserId)
        
        print("databaseReference", databaseReference)
        videoId = databaseReference.childByAutoId().key
        let videoReference = Database.database().reference().child("Videos").child("\(self.videoId!)")
        print("videoId", videoId)
        let storageReference = Storage.storage().reference().child("\(videoId!).mp4")

        // Start the video storage process
        storageReference.putFile(from: url as! URL, metadata: nil, completion: { (metadata, error) in
            if error == nil {
                print("Successful video upload")
                
            } else {
                print(error?.localizedDescription)
            }
            print("api call starting")
            self.statusLabel.text = "Detecting Objects"
            print("detecting objects")
            APIClient.getAllPositionCV(videoPath: "gs://phyzmo.appspot.com/\(self.videoId!).mp4") { (objectsData) in
                // API call done
                print("api call done")
                databaseReference.child("videoId").observeSingleEvent(of: .value, with: { (snapshot) in
                    print("key", snapshot.key)
                    print("value", snapshot.value)
                    if snapshot.value is [AnyObject] {
                        databaseReference.updateChildValues(["videoId":(snapshot.value as! [String]) + [self.videoId!]])
                        videoReference.setValue(["objects_selected": []])
                        
                    } else {
                        databaseReference.updateChildValues(["videoId":[self.videoId!]])
                    }
                    self.shouldSegue = true
                }) { (error) in
                    print(error.localizedDescription)
                }
    
            }
        })
        
        
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //segue to detailed view
        if segue.identifier == "MainToVideo" {
            let controller =  segue.destination as! DataViewController
            controller.video = self.video
        }
    }
    
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
      let title = (error == nil) ? "Success" : "Error"
      let message = (error == nil) ? "Video was saved" : "Video failed to save"
      
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
    }
}


extension MainViewController: UINavigationControllerDelegate {
}

