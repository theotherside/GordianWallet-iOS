//
//  WordRecoveryViewController.swift
//  FullyNoded2
//
//  Created by Peter on 12/04/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//

import UIKit
import LibWally

class WordRecoveryViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var seedArray = [String]()/// Used to recover multi-sig wallets with seed words only.
    var recoveringMultiSigWithWordsOnly = Bool()
    let cv = ConnectingView()
    var testingWords = Bool()
    var words:String?
    var walletNameHash = ""
    var derivation:String?
    var recoveryDict = [String:Any]()
    var addedWords = [String]()
    var justWords = [String]()
    var bip39Words = [String]()
    let label = UILabel()
    let tap = UITapGestureRecognizer()
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    var onWordsDoneBlock: ((Bool) -> Void)?
    var onSeedDoneBlock: ((String) -> Void)?
    var addingSeed = Bool()
    var addingIndpendentSeed = Bool()
    var index = 0
    var processedPrimaryDescriptors:[String] = []
    var processedChangeDescriptors:[String] = []
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var wordView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        textField.delegate = self
        tap.addTarget(self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
        wordView.layer.cornerRadius = 8
        bip39Words = Bip39Words.validWords
        updatePlaceHolder(wordNumber: 1)
        
        if addingSeed || addingIndpendentSeed {
            
            navigationItem.title = "Add BIP39 Phrase"
            
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.textField.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
            
        }
        
    }
    
    @objc func handleTap() {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.textField.resignFirstResponder()
            
        }
        
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        
        if self.justWords.count > 0 {
            
            DispatchQueue.main.async { [unowned vc = self] in
                
                vc.label.removeFromSuperview()
                vc.label.text = ""
                vc.addedWords.removeAll()
                vc.justWords.remove(at: vc.justWords.count - 1)
                
                for (i, word) in vc.justWords.enumerated() {
                    
                    vc.addedWords.append("\(i + 1). \(word)\n")
                    if i == 0 {
                        vc.updatePlaceHolder(wordNumber: i + 1)
                    } else {
                        vc.updatePlaceHolder(wordNumber: i + 2)
                    }
                }
                
                vc.label.textColor = .systemGreen
                vc.label.text = vc.addedWords.joined(separator: "")
                vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
                vc.label.numberOfLines = 0
                vc.label.sizeToFit()
                vc.wordView.addSubview(vc.label)
                
                if vc.justWords.count == 12 || vc.justWords.count == 24 {
                    
                    vc.validWordsAdded()
                    
                }
                
            }
            
        }
        
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    private func chooseDerivation() {
        
        Encryption.getNode { [unowned vc = self] (node, error) in
            
            if !error && node != nil {
                
                DispatchQueue.main.async {
                    
                    let network = node!.network
                    vc.recoveryDict["nodeId"] = node!.id
                    var chain = ""
                    
                    let alert = UIAlertController(title: "Choose a derivation", message: "When only using words to recover you need to let us know which derivation scheme you want to utilize, if you are not sure you can recover the wallet three times, once for each derivation.", preferredStyle: .actionSheet)
                    
                    switch network {
                    case "testnet":
                        chain = "1'"
                    case "mainnet":
                        chain = "0'"
                    default:
                        break
                    }
                    
                    alert.addAction(UIAlertAction(title: "Segwit - BIP84 - m/84'/\(chain)/0'/0", style: .default, handler: { action in
                        
                        switch network {
                        case "testnet":
                            vc.derivation = "m/84'/1'/0'"
                        case "mainnet":
                            vc.derivation = "m/84'/0'/0'"
                        default:
                            break
                        }
                        
                        vc.recoveryDict["derivation"] = vc.derivation
                        vc.cv.addConnectingView(vc: self, description: "building your wallets descriptors, this can take a minute..")
                        let (primDescriptors, changeDescriptors) = vc.descriptors()
                        vc.buildPrimDescriptors(primDescriptors, changeDescriptors)
                        
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Legacy - BIP44 - m/44'/\(chain)/0'/0", style: .default, handler: { action in
                        
                        switch network {
                        case "testnet":
                            vc.derivation = "m/44'/1'/0'"
                        case "mainnet":
                            vc.derivation = "m/44'/0'/0'"
                        default:
                            break
                        }
                        
                        vc.recoveryDict["derivation"] = vc.derivation
                        vc.cv.addConnectingView(vc: self, description: "building your wallets descriptors, this can take a minute..")
                        let (primDescriptors, changeDescriptors) = vc.descriptors()
                        vc.buildPrimDescriptors(primDescriptors, changeDescriptors)
                        
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Nested Segwit - BIP49 - m/49'/\(chain)/0'/0", style: .default, handler: { action in
                        
                        switch network {
                        case "testnet":
                            vc.derivation = "m/49'/1'/0'"
                        case "mainnet":
                            vc.derivation = "m/49'/0'/0'"
                        default:
                            break
                        }
                        
                        vc.recoveryDict["derivation"] = vc.derivation
                        vc.cv.addConnectingView(vc: self, description: "building your wallets descriptors, this can take a minute..")
                        let (primDescriptors, changeDescriptors) = vc.descriptors()
                        vc.buildPrimDescriptors(primDescriptors, changeDescriptors)
                        
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    
                    alert.popoverPresentationController?.sourceView = vc.view
                    vc.present(alert, animated: true, completion: nil)
                    
                }
                
            }
            
        }
        
    }
    
    private func processTextfieldInput() {
        print("processTextfieldInput")
        
        if textField.text != "" {
            
            //check if user pasted more then one word
            let processed = processedCharacters(textField.text!)
            let userAddedWords = processed.split(separator: " ")
            var multipleWords = [String]()
            
            if userAddedWords.count > 1 {
                
                //user add multiple words
                for (i, word) in userAddedWords.enumerated() {
                    
                    var isValid = false
                    
                    for bip39Word in bip39Words {
                        
                        if word == bip39Word {
                            isValid = true
                            multipleWords.append("\(word)")
                        }
                        
                    }
                    
                    if i + 1 == userAddedWords.count {
                        
                        // we finished our checks
                        if isValid {
                            
                            // they are valid bip39 words
                            addMultipleWords(words: multipleWords)
                            
                            textField.text = ""
                            
                        } else {
                            
                            //they are not all valid bip39 words
                            textField.text = ""
                            
                            showAlert(vc: self, title: "Error", message: "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                //its one word
                let processedWord = textField.text!.replacingOccurrences(of: " ", with: "")
                
                for word in bip39Words {
                    
                    if processedWord == word {
                        
                        addWord(word: processedWord)
                        textField.text = ""
                        
                    }
                    
                }
                
            }
            
        } else {
            
            shakeAlert(viewToShake: textField)
            
        }
        
    }
    
    private func formatSubstring(subString: String) -> String {
        
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
        
    }
    
    private func resetValues() {
        
        textField.textColor = .white
        autoCompleteCharacterCount = 0
        textField.text = ""
        
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textField.textColor = .white
        
        if suggestions.count > 0 {
            
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
                
            })
            
        } else {
            
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [unowned vc = self] (timer) in //7
                
                vc.textField.text = substring
                
                if let _ = BIP39Mnemonic(vc.processedCharacters(vc.textField.text!)) {
                    
                    vc.processTextfieldInput()
                    vc.textField.textColor = .systemGreen
                    vc.validWordsAdded()
                    
                } else {
                    
                    vc.textField.textColor = .systemRed
                    
                }
                
                
            })
            
            autoCompleteCharacterCount = 0
            
        }
        
    }
    
    private func validWordsAdded() {
        
        //if !addingSeed && !addingIndpendentSeed {
            
            DispatchQueue.main.async { [unowned vc = self] in
                
                vc.textField.resignFirstResponder()
                vc.verify()
                
            }
            
//        } else if addingIndpendentSeed {
//
//            DispatchQueue.main.async { [unowned vc = self] in
//                vc.textField.resignFirstResponder()
//
//            }
//
//            let unencryptedSeed = (justWords.joined(separator: " ")).dataUsingUTF8StringEncoding
//
//            Encryption.encryptData(dataToEncrypt: unencryptedSeed) { [unowned vc = self] (encryptedSeed, error) in
//
//                if encryptedSeed != nil {
//
//
//                    let dict = ["seed":encryptedSeed!,"id":UUID()] as [String:Any]
//                    CoreDataService.saveEntity(dict: dict, entityName: .seeds) { (success, errorDesc) in
//
//                        if success {
//
//                            DispatchQueue.main.async { [unowned vc = self] in
//                                vc.textField.text = ""
//                                vc.label.text = ""
//                                vc.justWords.removeAll()
//                                vc.addedWords.removeAll()
//                                vc.updatePlaceHolder(wordNumber: 1)
//                                NotificationCenter.default.post(name: .seedAdded, object: nil, userInfo: nil)
//                            }
//
//                            showAlert(vc: vc, title: "Seed saved!", message: "You may go back or add another seed.")
//
//                        } else {
//
//                           showAlert(vc: vc, title: "Error", message: "We had an error saving that seed.")
//
//                        }
//
//                    }
//
//                }
//
//            }
                
        //} else {
            
//            DispatchQueue.main.async { [unowned vc = self] in
//
//                if vc.justWords.count == 12 {
//
//                    let alert = UIAlertController(title: "That is a valid BIP39 mnemonic", message: "You may now create your wallet", preferredStyle: .actionSheet)
//
//                    alert.addAction(UIAlertAction(title: "Create wallet", style: .default, handler: { action in
//
//                        DispatchQueue.main.async { [unowned vc = self] in
//
//                            vc.onSeedDoneBlock!(vc.justWords.joined(separator: " "))
//                            vc.navigationController!.popViewController(animated: true)
//
//                        }
//
//                    }))
//
//                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//                    alert.popoverPresentationController?.sourceView = self.view
//                    vc.present(alert, animated: true, completion: nil)
//
//                }
//
//            }
            
        //}
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
        subString = formatSubstring(subString: subString)
        
        if subString.count == 0 {
            
            resetValues()
            
        } else {
            
            searchAutocompleteEntriesWIthSubstring(substring: subString)
            
        }
        
        return true
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        processTextfieldInput()
        return true
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        
        var possibleMatches: [String] = []
        
        for item in bip39Words {
            
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            
            if (substringRange.location == 0) {
                
                possibleMatches.append(item)
                
            }
            
        }
        
        return possibleMatches
        
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.systemGreen,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        
        self.textField.attributedText = coloredString
        
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        
        if let newPosition = self.textField.position(from: self.textField.beginningOfDocument, offset: userQuery.count) {
            
            self.textField.selectedTextRange = self.textField.textRange(from: newPosition, to: newPosition)
            
        }
        
        let selectedRange: UITextRange? = textField.selectedTextRange
        textField.offset(from: textField.beginningOfDocument, to: (selectedRange?.start)!)
        
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
        
    }
    
    private func addMultipleWords(words: [String]) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.label.removeFromSuperview()
            vc.label.text = ""
            vc.addedWords.removeAll()
            vc.justWords = words
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
            }
            
            vc.label.textColor = .systemGreen
            vc.label.text = vc.addedWords.joined(separator: "")
            vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
            vc.label.numberOfLines = 0
            vc.label.sizeToFit()
            vc.wordView.addSubview(vc.label)
            
            
            if vc.justWords.count == 24 || vc.justWords.count == 12 {
                
                if let _ = BIP39Mnemonic(vc.justWords.joined(separator: " ")) {
                    
                    vc.validWordsAdded()
                    
                } else {
                                        
                    showAlert(vc: vc, title: "Invalid", message: "Just so you know that is not a valid recovery phrase, if you are inputting a 24 word phrase ignore this message and keep adding your words.")
                    
                }
                
            }
            
        }
        
    }
    
    private func addWord(word: String) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.label.removeFromSuperview()
            vc.label.text = ""
            vc.addedWords.removeAll()
            vc.justWords.append(word)
            
            for (i, word) in vc.justWords.enumerated() {
                
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
                
            }
            
            vc.label.textColor = .systemGreen
            vc.label.text = vc.addedWords.joined(separator: "")
            vc.label.frame = CGRect(x: 16, y: 0, width: vc.wordView.frame.width - 32, height: vc.wordView.frame.height - 10)
            vc.label.numberOfLines = 0
            vc.label.sizeToFit()
            vc.wordView.addSubview(vc.label)
            
            
            if vc.justWords.count == 24 || vc.justWords.count == 12 {
                
                if let _ = BIP39Mnemonic(vc.justWords.joined(separator: " ")) {
                    
                    vc.validWordsAdded()
                    
                } else {
                                        
                    showAlert(vc: vc, title: "Invalid", message: "Just so you know that is not a valid recovery phrase, if you are inputting a 24 word phrase ignore this message and keep adding your words.")
                    
                }
                
            }
            
        }
        
    }
    
    private func processedCharacters(_ string: String) -> String {
        var result = string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains)
        result = result.condenseWhitespace()
        return result
    }
    
    private func confirm() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.label.text = ""
            vc.performSegue(withIdentifier: "confirmFromWords", sender: vc)
        }
    }
    
    private func verify() {
        
        let parser = DescriptorParser()
        words = justWords.joined(separator: " ")
        if let desc = recoveryDict["descriptor"] as? String {
            
            let str = parser.descriptor(desc)
            let backupXpub = str.multiSigKeys[0]
            let derivation = str.derivationArray[0]
            
            MnemonicCreator.convert(words: words!) { [unowned vc = self] (mnemonic, error) in
                
                if !error && mnemonic != nil {
                    
                    let seed = mnemonic!.seedHex()
                    if let mk = HDKey(seed, vc.network()) {
                        
                        if let path = BIP32Path(derivation) {
                            
                            do {
                                
                                let hdKey = try mk.derive(path)
                                let xpub = hdKey.xpub
                                
                                if xpub == backupXpub {
                                    
                                    DispatchQueue.main.async { [unowned vc = self] in
                                                    
                                        let alert = UIAlertController(title: "Recovery words match your wallets xpub!", message: "You may now go to the next step", preferredStyle: .actionSheet)

                                        alert.addAction(UIAlertAction(title: "Next", style: .default, handler: { action in
                                            
                                            if vc.testingWords {
                                                
                                                vc.words = nil
                                                
                                            }
                                            
                                            vc.confirm()
                                            
                                        }))
                                        
                                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                                        alert.popoverPresentationController?.sourceView = self.view
                                        vc.present(alert, animated: true, completion: nil)
                                        
                                    }
                                    
                                    
                                } else {
                                    
                                    showAlert(vc: vc, title: "Error", message: "that recovery phrase does not match the required recovery phrase for this wallet")
                                    
                                }
                                
                            } catch {
                                
                                showAlert(vc: vc, title: "Error", message: "error deriving xpub from master key")
                                
                            }
                            
                        } else {
                            
                            showAlert(vc: vc, title: "Error", message: "error converting derivation to bip32 path")
                            
                        }
                        
                    } else {
                        
                        showAlert(vc: vc, title: "Error", message: "error deriving master key")
                        
                    }
                    
                } else {
                    
                    showAlert(vc: vc, title: "Error", message: "error converting your words to a valid mnemonic")
                    
                }
                
            }
            
        } else {
            /// It's words only
            func addSeed() {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.seedArray.append(vc.justWords.joined(separator: " "))
                    vc.justWords.removeAll()
                    vc.addedWords.removeAll()
                    vc.textField.text = ""
                    vc.label.text = ""
                    vc.updatePlaceHolder(wordNumber: 1)
                }
            }
            
            func seedAddedAddAnother() {
                DispatchQueue.main.async { [unowned vc = self] in
                    let alert = UIAlertController(title: "Seed added, you may now add another.", message: "", preferredStyle: .actionSheet)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { action in }))
                    alert.popoverPresentationController?.sourceView = self.view
                    vc.present(alert, animated: true, completion: nil)
                }
            }
            
            if !recoveringMultiSigWithWordsOnly {
                DispatchQueue.main.async { [unowned vc = self] in
                    let alert = UIAlertController(title: "That is a valid recovery phrase", message: "Are you recovering a multi-sig account or single-sig account?", preferredStyle: .actionSheet)
                    alert.addAction(UIAlertAction(title: "Single-sig", style: .default, handler: { action in
                        vc.chooseDerivation()
                    }))
                    alert.addAction(UIAlertAction(title: "Multi-sig", style: .default, handler: { action in
                        vc.recoveringMultiSigWithWordsOnly = true
                        addSeed()
                        seedAddedAddAnother()
                    }))
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    alert.popoverPresentationController?.sourceView = self.view
                    vc.present(alert, animated: true, completion: nil)
                }
            } else {
                /// Adding multiple sets of words to recover multi-sig with only words.
                DispatchQueue.main.async { [unowned vc = self] in
                    
                    let alert = UIAlertController(title: "That is a valid recovery phrase", message: "Add another seed phrase or recover this multi-sig account now? When recovering multi-sig accounts with words only we utilize BIP67 by default.", preferredStyle: .actionSheet)

                    alert.addAction(UIAlertAction(title: "Add another seed", style: .default, handler: { action in
                        vc.seedArray.append(vc.justWords.joined(separator: " "))
                        vc.justWords.removeAll()
                        vc.addedWords.removeAll()
                        vc.textField.text = ""
                        vc.label.text = ""
                        vc.updatePlaceHolder(wordNumber: 1)
                        seedAddedAddAnother()
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Recover Now", style: .default, handler: { action in
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.seedArray.append(vc.justWords.joined(separator: " "))
                            vc.justWords.removeAll()
                            vc.addedWords.removeAll()
                            vc.textField.text = ""
                            vc.updatePlaceHolder(wordNumber: 1)
                            vc.performSegue(withIdentifier: "segueToNumberOfSigners", sender: vc)
                        }
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    alert.popoverPresentationController?.sourceView = self.view
                    vc.present(alert, animated: true, completion: nil)
                    
                }
            }
        }
    }
    
    private func mnemonic() -> BIP39Mnemonic? {
        if words != nil {
            return BIP39Mnemonic(words!)
        } else {
            return nil
        }
    }
    
    private func masterKey(mnemonic: BIP39Mnemonic) -> HDKey? {
        return HDKey(mnemonic.seedHex(""), network())
    }
    
    private func path(deriv: String) -> BIP32Path? {
        return BIP32Path(deriv)
    }
    
    private func network() -> Network {
        if derivation!.contains("1") {
            return .testnet
        } else {
            return .mainnet
        }
    }
    
    private func fingerprint(key: HDKey) -> String {
        return key.fingerprint.hexString
    }
    
    private func xpub(path: BIP32Path) -> String? {
        if mnemonic() != nil {
            if let mk = masterKey(mnemonic: mnemonic()!) {
                do {
                    return try mk.derive(path).xpub
                } catch {
                    return nil
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func xprv(path: BIP32Path) -> String? {
        if mnemonic() != nil {
            if let mk = masterKey(mnemonic: mnemonic()!) {
                do {
                    return try mk.derive(path).xpriv
                } catch {
                    return nil
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func accountlessPath() -> String {
        var accountLessPath = ""
        if derivation != nil {
            let arr = derivation!.split(separator: "/")
            for (i, item) in arr.enumerated() {
                if i < 3 {
                    accountLessPath += item + "/"
                }
            }
        }
        return accountLessPath
    }
    
    private func descriptors() -> (primaryDescriptors: [String], changeDescriptors: [String]) {
        var primDescs:[String] = []
        var changeDescs:[String] = []
        if words != nil {
            if let mnemonic = mnemonic() {
                if let mk = masterKey(mnemonic: mnemonic) {
                    for i in 0...9 {
                        if let path = path(deriv: accountlessPath() + "\(i)'") {
                            let pathWithFingerprint = (path.description).replacingOccurrences(of: "m", with: fingerprint(key: mk))
                            if let xpub = xpub(path: path) {
                                var primDesc = ""
                                switch self.derivation {
                                case "m/84'/1'/0'":
                                    primDesc = "\"wpkh([\(pathWithFingerprint)]\(xpub)/0/*)\""
                                    
                                case "m/84'/0'/0'":
                                    primDesc = "\"wpkh([\(pathWithFingerprint)]\(xpub)/0/*)\""
                                    
                                case "m/44'/1'/0'":
                                    primDesc = "\"pkh([\(pathWithFingerprint)]\(xpub)/0/*)\""
                                     
                                case "m/44'/0'/0'":
                                    primDesc = "\"pkh([\(pathWithFingerprint)]\(xpub)/0/*)\""
                                    
                                case "m/49'/1'/0'":
                                    primDesc = "\"sh(wpkh([\(pathWithFingerprint)]\(xpub)/0/*))\""
                                    
                                case "m/49'/0'/0'":
                                    primDesc = "\"sh(wpkh([\(pathWithFingerprint)]\(xpub)/0/*))\""
                                    
                                default:
                                    break
                                    
                                }
                                primDescs.append(primDesc)
                                changeDescs.append(primDesc.replacingOccurrences(of: "/0/*", with: "/1/*"))
                            }
                        }
                    }
                }
            }
        }
        return (primDescs, changeDescs)
    }
    
    private func setXprvs(completion: @escaping ((Bool)) -> Void) {
        if words != nil {
            var encryptedXprvs:[Data] = []
            for i in 0...9 {
                if let path = path(deriv: accountlessPath() + "\(i)'") {
                    if let xprv = xprv(path: path) {
                        Encryption.encryptData(dataToEncrypt: xprv.dataUsingUTF8StringEncoding) { [unowned vc = self] (encryptedData, error) in
                            if encryptedData != nil {
                                encryptedXprvs.append(encryptedData!)
                                if i == 9 {
                                    vc.recoveryDict["xprvs"] = encryptedXprvs
                                    completion(true)
                                }
                            } else {
                                completion(false)
                            }
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        } else {
            completion(false)
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((descriptor: String?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(walletName: "", command: .getdescriptorinfo, param: "\(desc)") { (object, errorDescription) in
            if let dict = object as? NSDictionary {
                if let descriptor = dict["descriptor"] as? String {
                    completion((descriptor, nil))
                } else {
                    completion((nil, errorDescription ?? "unknown"))
                }
            } else {
                completion((nil, errorDescription ?? "unknown"))
            }
        }
    }
    
    private func buildChangeDescriptors(_ descriptors: [String]) {
        if index < descriptors.count {
            getDescriptorInfo(desc: descriptors[index]) { [unowned vc = self] (descriptor, errorMessage) in
                if descriptor != nil {
                    vc.processedChangeDescriptors.append(descriptor!)
                    vc.index += 1
                    vc.buildChangeDescriptors(descriptors)
                } else {
                    showAlert(vc: vc, title: "Error", message: "Error getting descriptor info: \(errorMessage ?? "unknown")")
                    vc.cv.removeConnectingView()
                }
            }
        } else {
            setWalletDict()
        }
    }
    
    private func buildPrimDescriptors(_ descriptors: [String], _ changeDescriptors: [String]) {
        if index < descriptors.count {
            getDescriptorInfo(desc: descriptors[index]) { [unowned vc = self] (descriptor, errorMessage) in
                if descriptor != nil {
                    vc.processedPrimaryDescriptors.append(descriptor!)
                    vc.index += 1
                    vc.buildPrimDescriptors(descriptors, changeDescriptors)
                } else {
                    showAlert(vc: vc, title: "Error", message: "Error getting descriptor info: \(errorMessage ?? "unknown")")
                    vc.cv.removeConnectingView()
                }
            }
        } else {
            index = 0
            buildChangeDescriptors(changeDescriptors)
        }
    }
    
    private func setWalletDict() {
        for desc in processedPrimaryDescriptors {
            if desc.contains("/84'/1'/0'") || desc.contains("/84'/0'/0'") || desc.contains("/44'/1'/0'") || desc.contains("/44'/0'/0'") || desc.contains("/49'/1'/0'") || desc.contains("/49'/0'/0'") {
                if desc.contains("/0/*") {
                    walletNameHash = Encryption.sha256hash(desc)
                    recoveryDict["descriptor"] = desc
                    recoveryDict["name"] = walletNameHash
                } else if desc.contains("/1/*") {
                    recoveryDict["changeDescriptor"] = desc
                }
            }
        }
        recoveryDict["type"] = "DEFAULT"
        recoveryDict["id"] = UUID()
        recoveryDict["blockheight"] = Int32(0)
        recoveryDict["maxRange"] = 2500
        recoveryDict["lastUsed"] = Date()
        recoveryDict["isArchived"] = false
        recoveryDict["birthdate"] = keyBirthday()
        recoveryDict["nodeIsSigner"] = false
        CoreDataService.retrieveEntity(entityName: .wallets) { [unowned vc = self] (wallets, errorDescription) in
            if wallets != nil {
                if wallets!.count == 0 {
                    vc.recoveryDict["isActive"] = true
                } else {
                    vc.recoveryDict["isActive"] = false
                }
                vc.setXprvs { (success) in
                    if success {
                        vc.cv.removeConnectingView()
                        vc.confirm()
                    } else {
                        vc.cv.removeConnectingView()
                        showAlert(vc: vc, title: "Error", message: "There was an error encrypting your xprvs.")
                    }
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToNumberOfSigners":
            if let vc = segue.destination as? ChooseNumberOfSignersViewController {
                vc.seedArray = seedArray
            }
            
        case "confirmFromWords":
            if let vc = segue.destination as? ConfirmRecoveryViewController {
                vc.walletNameHash = self.walletNameHash
                vc.walletDict = self.recoveryDict
                vc.words = self.words
                vc.derivation = self.derivation
                vc.changeDescriptors = processedChangeDescriptors
                vc.primaryDescriptors = processedPrimaryDescriptors
            }
            
        default:
            break
            
        }
    }

}

extension String {
    func condenseWhitespace() -> String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
