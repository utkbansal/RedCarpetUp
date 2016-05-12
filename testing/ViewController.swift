//
//  ViewController.swift
//  testing
//
//  Created by Utkarsh Bansal on 11/05/16.
//  Copyright © 2016 Software Incubator. All rights reserved.
//

import UIKit
import Contacts
import Alamofire
import AWSS3


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let S3BucketName = "test-redcarpet"
    
    let imagePicker = UIImagePickerController()
    
    // URL of the image to be uploaded
    var imageURL: NSURL?
    var contactsJSONString: NSString?
    var contactsURL: NSURL?
    
    var imagePicked = 0
    var contactsAdded = 0
    
    @IBOutlet weak var image: UIImageView!
    
    @IBAction func imageButtonTapped(sender: AnyObject) {
        
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .PhotoLibrary
        
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    @IBOutlet weak var imageSelectCheck: UIImageView!
    @IBOutlet weak var contactSelectCheck: UIImageView!
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        // Image to be sent to server
        var imageData: NSData? = nil
        
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            // Save data to be uploaded
            imageData  = UIImagePNGRepresentation(pickedImage)
            
            //upload code
            let uploadFileURL = info[UIImagePickerControllerReferenceURL] as! NSURL

            let imageName = uploadFileURL.lastPathComponent
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as String
            let localPath = (documentDirectory as NSString).stringByAppendingPathComponent(imageName!)
            
            imageData!.writeToFile(localPath, atomically: true)
            imageURL = NSURL(fileURLWithPath: localPath)
            
            image.contentMode = .ScaleAspectFit
            image.image = pickedImage
            self.imagePicked = 1
            imageSelectCheck.hidden = false
        }
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // get data when needed
    lazy var contacts: [CNContact] = {
        let contactStore = CNContactStore()
        let keysToFetch = [
            CNContactFormatter.descriptorForRequiredKeysForStyle(.FullName),
            CNContactPhoneNumbersKey,
        ]
        
        var allContainers: [CNContainer] = []
        do {
            allContainers = try contactStore.containersMatchingPredicate(nil)
        } catch {
            print("Error fetching containers")
        }
        
        var results: [CNContact] = []
        
        // add all contents to results list
        for container in allContainers {
            let fetchPredicate = CNContact.predicateForContactsInContainerWithIdentifier(container.identifier)
            
            do {
                let containerResults = try contactStore.unifiedContactsMatchingPredicate(fetchPredicate, keysToFetch: keysToFetch)
                results.appendContentsOf(containerResults)
            } catch {
                print("Error fetching results for container")
            }
            
        }
        
        return results
    }()
    
    @IBAction func getContacts(sender: UIButton) {
        
        var contactsData = [String: [String]]()
        
        // MAke a list of all contacts in text format
        for var contact in contacts {
            
            var name = ("\(contact.givenName) \(contact.familyName)")
            var numbers = [String]()
            
            for var number in contact.phoneNumbers {
                let finalNumber = number.value as! CNPhoneNumber
                
                numbers.append("\(finalNumber.stringValue)")
            }
            
            contactsData[name] = numbers
        }
        
        // serialize data into JSON
        do {
            
            let jsonData = try NSJSONSerialization.dataWithJSONObject(contactsData, options: NSJSONWritingOptions.PrettyPrinted)
            
            contactsJSONString = NSString(data: jsonData, encoding: NSUTF8StringEncoding)
            print(contactsJSONString)
            self.contactsAdded = 1
            contactSelectCheck.hidden = false
            
            
        }catch let error as NSError{
            print(error.description)
        }
    
    }
    
    func createContactsFile()  {
        
        if let dir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = NSURL(fileURLWithPath: dir).URLByAppendingPathComponent("contacts.json")
            
            contactsURL = path
            
            //writing
            do {
                try contactsJSONString!.writeToURL(path, atomically: false, encoding: NSUTF8StringEncoding)
                print("file written")
            }
            catch {
                print("cant write to file")
            }
            
            do {
                let text2 = try NSString(contentsOfURL: path, encoding: NSUTF8StringEncoding)
                
                print(text2)
            } catch {
                /* error handling here */
            
            }
            
            
        }
    }
    
    
    @IBAction func uploadTapped(sender: UIButton) {
        if (imagePicked == 1 && self.contactsAdded == 1) {
            
            createContactsFile()
            uploadImage()
            uploadContacts()
            
            
        
        } else {
            // Tasks not completed yet
            print("Tasks not completed yet")
            
            let alert = UIAlertController(title: "", message: "Tasks not completed yet", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            
        }
    }
    
    func uploadImage()  {
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.body = imageURL
        uploadRequest.key = NSProcessInfo.processInfo().globallyUniqueString + "." + "png"
        uploadRequest.bucket = S3BucketName
        uploadRequest.contentType = "image/" + "png"
        
        let transferManager = AWSS3TransferManager.defaultS3TransferManager()
        transferManager.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
            if let error = task.error {
                print("Upload failed ❌ (\(error))")
            }
            if let exception = task.exception {
                print("Upload failed ❌ (\(exception))")
            }
            if task.result != nil {
                let s3URL = NSURL(string: "http://s3.amazonaws.com/\(self.S3BucketName)/\(uploadRequest.key!)")!
                print("Uploaded to:\n\(s3URL)")
            }
            else {
                print("Unexpected empty result.")
            }
            return nil
        }

    }
    
    func uploadContacts()  {
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.body = contactsURL
        uploadRequest.key = NSProcessInfo.processInfo().globallyUniqueString + "." + "json"
        uploadRequest.bucket = S3BucketName
        uploadRequest.contentType = "application/json"
        
        let transferManager = AWSS3TransferManager.defaultS3TransferManager()
        transferManager.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
            if let error = task.error {
                print("Upload failed ❌ (\(error))")
            }
            if let exception = task.exception {
                print("Upload failed ❌ (\(exception))")
            }
            if task.result != nil {
                let s3URL = NSURL(string: "http://s3.amazonaws.com/\(self.S3BucketName)/\(uploadRequest.key!)")!
                print("JSON Uploaded to:\n\(s3URL)")
            }
            else {
                print("Unexpected empty result.")
            }
            return nil
        }

    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imageSelectCheck.hidden = true
        contactSelectCheck.hidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

