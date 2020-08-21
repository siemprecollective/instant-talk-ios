//
//  ViewController.swift
//  SiempreOne
//


import UIKit
import Firebase

class LoginViewController: UIViewController {
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var idField: UITextField!

    struct SiempreConfig : Codable {
        var userId: String
        var userName: String
    }
    
    var appdelegate: AppDelegate!
    var firestore: Firestore!
    var configFile: URL!

    override func viewDidLoad() {
        super.viewDidLoad()

        appdelegate = UIApplication.shared.delegate as? AppDelegate
        firestore = Firestore.firestore()
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("No document directory found in application bundle.")
        }
        configFile = documentsDirectory.appendingPathComponent("Configuration.plist")
        guard let configData = try? Data(contentsOf: configFile) else {
            return
        }
        let decoder = PropertyListDecoder()
        guard let config = try? decoder.decode(SiempreConfig.self, from: configData) else {
            return
        }
        tryLogin(userName: config.userName, userId: config.userId)
    }
    
    @IBAction func buttonPressed(_ sender: Any) {
        tryLogin(userName: nameField.text!, userId: idField.text!)
    }
    
    func tryLogin(userName: String, userId: String) {
        let currentUserDoc = firestore.collection("users").document(userId)
        currentUserDoc.getDocument{ (document, error) in
            if let document = document, document.exists,
                document.data()!["name"] as? String == userName {
                // save userName, userId
                let config = SiempreConfig(userId: userId, userName: userName)
                let encoder = PropertyListEncoder()
                guard let configData = try? encoder.encode(config) else {
                    fatalError("failed to write config plist")
                }
                try! configData.write(to: self.configFile)
                // transition to main view
                self.appdelegate.currentUserId = userId
                self.performSegue(withIdentifier: "LoggedinSegue", sender: nil)
            } else {
                let alertController = UIAlertController(title: "Login failed", message: "Check your Name and ID and try again", preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "Try again", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
