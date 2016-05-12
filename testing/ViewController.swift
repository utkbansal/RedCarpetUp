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

import AWSCore
import AWSS3

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let S3BucketName = "test-redcarpet"
    
    let imagePicker = UIImagePickerController()
    
    // All contacts NOT in JSON
    var finalContacts = [String: [String]]()
    // Image to be sent to server
    var imageData: NSData? = nil
    
    
    // URL of the image to be uploaded
    var imageURL: NSURL?
    
    var imagePicked = 0
    var contactsAdded = 0
    @IBOutlet weak var image: UIImageView!
    
    @IBAction func imageButtonTapped(sender: AnyObject) {
        
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .PhotoLibrary
        
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            // Save data to be uploaded
            self.imageData  = UIImagePNGRepresentation(pickedImage)
            
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
            CNContactEmailAddressesKey,
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
        
        for var contact in contacts {
            
            var name = ("\(contact.givenName) \(contact.familyName)")
            var numbers = [String]()
            
            for var number in contact.phoneNumbers {
                let finalNumber = number.value as! CNPhoneNumber
                
                numbers.append("\(finalNumber.stringValue)")
            }
            
            self.finalContacts[name] = numbers
        }
        print(finalContacts)
        
        do {
            
            // serialize data into JSOn
            let jsonData = try NSJSONSerialization.dataWithJSONObject(finalContacts, options: NSJSONWritingOptions.PrettyPrinted)
            
            let string = NSString(data: jsonData, encoding: NSUTF8StringEncoding)
            print(string)
            
            
        }catch let error as NSError{
            print(error.description)
        }
    
    }
    
    
    @IBAction func uploadTapped(sender: UIButton) {
        
        print("upload button tapped")
        
        if (imagePicked == 1) {
            
            print("making POST request")
            // make post request to s3
            
            Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
                .responseJSON { response in
                    print(response.request)  // original URL request
                    print(response.response) // URL response
                    print(response.data)     // server data
                    print(response.result)   // result of response serialization
                    
                    if let JSON = response.result.value {
                        print("JSON: \(JSON)")
                    }
            }
            
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        
//        print(amazonS3Manager.getObject("/"))
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

