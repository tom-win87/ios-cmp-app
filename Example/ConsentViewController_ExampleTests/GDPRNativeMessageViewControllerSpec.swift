//
//  GDPRNativeMessageViewControllerSpec.swift
//  ConsentViewController_ExampleTests
//
//  Created by Vilas on 23/03/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
@testable import ConsentViewController

// swiftlint:disable function_body_length

class GDPRNativeMessageViewControllerSpec: QuickSpec {
    override func spec() {
        describe("GDPRNativeMessageViewController") {
            let customFileds = ["Custom": "Fileds"]
            let attributeStyle = AttributeStyle(fontFamily: "System-Font", fontSize: 14, color: "#00FA9A", backgroundColor: "#944488")
            let messageAttribute = MessageAttribute(text: "Test GDPR Message", style: attributeStyle, customFields: customFileds)
            let messageAction = MessageAction(text: "Test GDPR Message", style: attributeStyle, customFields: customFileds, choiceId: 12, choiceType: GDPRActionType.AcceptAll)
            let gdprMessage = GDPRMessage(title: messageAttribute, body: messageAttribute, actions: [messageAction], customFields: customFileds)
            var mockConsentDelegate = MockConsentDelegate()
            var gpdrMessageUiDelegate = GDPRUIDelegateMock(mockConsentDelegate)
            var gdprNativeMessageViewController = GDPRNativeMessageViewController(messageContents: gdprMessage, consentViewController: gpdrMessageUiDelegate)

            let titleLabel = UILabel()
            let descriptionTextView = UITextView()
            let acceptButton = UIButton()

            beforeEach {
                mockConsentDelegate = MockConsentDelegate()
                gpdrMessageUiDelegate = GDPRUIDelegateMock(mockConsentDelegate)
                gdprNativeMessageViewController = GDPRNativeMessageViewController(messageContents: gdprMessage, consentViewController: gpdrMessageUiDelegate)
            }

            it("Test onShowOptionsTap method") {
                gdprNativeMessageViewController.onShowOptionsTap(AnyClass.self)
                expect(mockConsentDelegate.isOnActionCalled).to(equal(false), description: "onAction delegate method calls successfully")
            }

            it("Test onShowOptionsTap method") {
                gdprNativeMessageViewController.onRejectTap(AnyClass.self)
                expect(mockConsentDelegate.isOnActionCalled).to(equal(false), description: "onAction delegate method calls successfully")
            }

            it("Test onShowOptionsTap method") {
                gdprNativeMessageViewController.onAcceptTap(AnyClass.self)
                expect(mockConsentDelegate.isOnActionCalled).to(equal(true), description: "onAction delegate method calls successfully")
            }

            it("Test loadOrHideActionButton method") {
                gdprNativeMessageViewController.loadOrHideActionButton(actionType: GDPRActionType.AcceptAll, button: acceptButton)
                expect(acceptButton.titleLabel?.text).to(equal("Test GDPR Message"), description: "Expected data is added in label")
            }

            it("Test loadTitle method") {
                gdprNativeMessageViewController.loadTitle(forAttribute: messageAttribute, label: titleLabel)
                expect(titleLabel.text).to(equal("Test GDPR Message"), description: "Expected data is added in label")
            }

            it("Test loadBody method") {
                gdprNativeMessageViewController.loadBody(forAttribute: messageAttribute, textView: descriptionTextView)
                expect(descriptionTextView.text).to(equal("Test GDPR Message"), description: "Expected data is added in textview")
            }

            context("Test onAction delegate method") {
                it("Test GDPRMessageViewController calls onAction delegate method") {
                    gdprNativeMessageViewController.action(GDPRActionType.AcceptAll)
                    expect(mockConsentDelegate.isOnActionCalled).to(equal(true), description: "onAction delegate method calls successfully")
                }
            }

            describe("showPrivacyManager") {
                it("calls loadPrivacyManager on its gpdrMessageUiDelegate") {
                    gdprNativeMessageViewController.showPrivacyManager()
                    expect(gpdrMessageUiDelegate.loadPrivacyManagerCalled).to(beTruthy())
                }
            }

            it("Test hexStringToUIColor method") {
                let rgbColor = gdprNativeMessageViewController.hexStringToUIColor(hex: "#757575")
                expect(rgbColor?.cgColor.components).to(equal([0.4588235294117647, 0.4588235294117647, 0.4588235294117647, 1.0]), description: "Hex string converted to UIColor")
            }
        }
    }
}
