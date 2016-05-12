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
            
            
        }catch let error as NSError{
            print(error.description)
        }
    
    }
    
    func createContactsFile()  {
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
        let documentsDirectoryPath = NSURL(string: documentsDirectoryPathString)!
        
        
        let contactsURL = documentsDirectoryPath.URLByAppendingPathComponent("contacts.json")
        
        let fileManager = NSFileManager.defaultManager()
        
        if let dir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = NSURL(fileURLWithPath: dir).URLByAppendingPathComponent("contacts.json")
            
            //writing
            do {
                try contactsJSONString!.writeToURL(path, atomically: false, encoding: NSUTF8StringEncoding)
                print("file written")
            }
            catch {
                /* error handling here */
                print("cant write to file")
            }
            
            do {
                let text2 = try NSString(contentsOfURL: path, encoding: NSUTF8StringEncoding)
                
                print(text2)
            }
            catch {/* error handling here */}
            
            
        }
    }
    
    
    @IBAction func uploadTapped(sender: UIButton) {
        
        print("upload button tapped")
        
        if (imagePicked == 1 && self.contactsAdded == 1) {
            
            let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1,
                                                                    identityPoolId:"us-east-1:4e039830-2c72-488c-b583-2ff365c828dd")
            
            let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
            
            AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
            
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
            
            createContactsFile()
        
        } else {
            // Tasks not completed yet
            print("Tasks not completed yet")
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

