//
//  SourcePointClientSpec.swift
//  ConsentViewController_ExampleTests
//
//  Created by Vilas on 29/03/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

// swiftlint:disable force_try function_body_length force_cast

import Quick
import Nimble
@testable import ConsentViewController

public class MockHttp: HttpClient {
    var getWasCalledWithUrl: URL?
    var postWasCalledWithUrl: URL?
    var postWasCalledWithBody: Data?
    var success: Data?
    var error: Error?

    init(success: Data?) {
        self.success = success
    }

    init(error: Error?) {
        self.error = error
    }

    public func get(url: URL?, completionHandler: @escaping CompletionHandler) {}

    func request(_ urlRequest: URLRequest, _ completionHandler: @escaping CompletionHandler) {}

    public func post(url: URL?, body: Data?, completionHandler: @escaping CompletionHandler) {
        postWasCalledWithUrl = url?.absoluteURL
        postWasCalledWithBody = body
        var urlRequest = URLRequest(url: postWasCalledWithUrl!)
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.success != nil ?
                completionHandler(self.success!, nil) :
                completionHandler(nil, APIParsingError(url!.absoluteString, self.error))
        })
    }
}

class SourcePointClientSpec: QuickSpec {
    static let propertyId = 123

    func getClient(_ client: MockHttp) -> SourcePointClient {
        return SourcePointClient(
            accountId: 123,
            propertyId: SourcePointClientSpec.propertyId,
            propertyName: try! GDPRPropertyName("tcfv2.mobile.demo"),
            pmId: "123",
            campaignEnv: .Public,
            targetingParams: ["native": "false"],
            client: client)
    }

    override func spec() {
        Nimble.AsyncDefaults.Timeout = 2

        var client: SourcePointClient!
        var httpClient: MockHttp?
        var mockedResponse: Data?

        describe("statics") {
            it("CUSTOM_CONSENT_URL") {
                expect(SourcePointClient.CUSTOM_CONSENT_URL.absoluteURL).to(equal(
                    URL(string: "https://wrapper-api.sp-prod.net/tcfv2/v1/gdpr/custom-consent?inApp=true")!.absoluteURL
                ))
            }
        }

        describe("Test SourcePointClient Methods") {
            beforeEach {
                mockedResponse = "{\"url\": \"https://notice.sp-prod.net/?message_id=59706\"}".data(using: .utf8)
                httpClient = MockHttp(success: mockedResponse)
                client = self.getClient(httpClient!)
            }

            context("Test getMessage") {
                it("calls get on the http client with the right url") {
                    client.getMessage(
                        native: false,
                        consentUUID: "744BC49E-7327-4255-9794-FB07AA43E1DF",
                        euconsent: "COwkbAyOwkbAyAGABBENAeCAAAAAAAAAAAAAAAAAAAAA",
                        authId: "test",
                        completionHandler: { _, _  in})
                    expect(httpClient?.postWasCalledWithUrl).to(equal(URL(string: "https://wrapper-api.sp-prod.net/tcfv2/v1/gdpr/message-url?inApp=true")))
                }

                it("calls get on the http client with the right url") {
                    client.getMessage(
                        url: SourcePointClient.GET_MESSAGE_URL_URL,
                        consentUUID: "744BC49E-7327-4255-9794-FB07AA43E1DF",
                        euconsent: "COwkbAyOwkbAyAGABBENAeCAAAAAAAAAAAAAAAAAAAAA",
                        authId: nil,
                        completionHandler: { _, _  in })
                    expect(httpClient?.postWasCalledWithUrl).to(equal(URL(string: "https://wrapper-api.sp-prod.net/tcfv2/v1/gdpr/message-url?inApp=true")))
                }
            }

            context("Test postAction") {
                it("calls post on the http client with the right url") {
                    let acceptAllAction = GDPRAction(type: .AcceptAll, id: "1234")
                    client.postAction(action: acceptAllAction, consentUUID: "744BC49E-7327-4255-9794-FB07AA43E1DF", completionHandler: { _, _  in})
                    expect(httpClient?.postWasCalledWithUrl).to(equal(URL(string: "https://wrapper-api.sp-prod.net/tcfv2/v1/gdpr/consent?inApp=true")))
                }
            }

            context("Test targetingParamsToString") {
                it("Test TargetingParamsToString with parameter") {
                    let targetingParams = ["native": "false"]
                    let targetingParamString = client.targetingParamsToString(targetingParams)
                    let encodeTargetingParam = "{\"native\":\"false\"}".data(using: .utf8)
                    let encodedString = String(data: encodeTargetingParam!, encoding: .utf8)
                    expect(targetingParamString).to(equal(encodedString))
                }
            }

            describe("customConsent") {
                it("makes a POST to SourcePointClient.CUSTOM_CONSENT_URL") {
                    let http = MockHttp(success: "".data(using: .utf8)!)
                    self.getClient(http).customConsent(toConsentUUID: "", vendors: [], categories: [], legIntCategories: []) { _, _ in }
                    expect(http.postWasCalledWithUrl).to(equal(SourcePointClient.CUSTOM_CONSENT_URL.absoluteURL))
                }

                it("makes a POST with the correct body") {
                    var parsedRequest: [String: Any]?
                    let http = MockHttp(success: "".data(using: .utf8)!)
                    self.getClient(http).customConsent(toConsentUUID: "uuid", vendors: [], categories: [], legIntCategories: []) { _, _ in }
                    parsedRequest = try! JSONSerialization.jsonObject(with: http.postWasCalledWithBody!) as! [String: Any]

                    expect((parsedRequest?["consentUUID"] as! String)).to(equal("uuid"))
                    expect((parsedRequest?["vendors"] as! [String])).to(equal([]))
                    expect((parsedRequest?["categories"] as! [String])).to(equal([]))
                    expect((parsedRequest?["legIntCategories"] as! [String])).to(equal([]))
                    expect((parsedRequest?["propertyId"] as! Int)).to(equal(SourcePointClientSpec.propertyId))
                }

                context("on success") {
                    beforeEach {
                        client = self.getClient(MockHttp(success: """
                        {
                            "vendors": [],
                            "categories": [],
                            "legIntCategories": [],
                            "specialFeatures": []
                        }
                        """.data(using: .utf8)!))
                    }

                    it("calls the completion handler with a CustomConsentResponse") {
                        var consentsResponse: CustomConsentResponse?
                        client.customConsent(toConsentUUID: "uuid", vendors: [], categories: [], legIntCategories: []) { response, _ in
                            consentsResponse = response
                        }
                        expect(consentsResponse).toEventually(equal(CustomConsentResponse(
                            vendors: [],
                            categories: [],
                            legIntCategories: [],
                            specialFeatures: []
                        )))
                    }

                    it("calls completion handler with nil as error") {
                        var error: GDPRConsentViewControllerError? = .none
                        client.customConsent(toConsentUUID: "uuid", vendors: [], categories: [], legIntCategories: []) { _, e in
                            error = e
                        }
                        expect(error).toEventually(beNil())
                    }
                }

                context("on failure") {
                    beforeEach {
                        client = self.getClient(MockHttp(error: nil))
                    }

                    it("calls the completion handler with an GDPRConsentViewControllerError") {
                        var error: GDPRConsentViewControllerError?
                        client.customConsent(toConsentUUID: "uuid", vendors: [], categories: [], legIntCategories: []) { _, e in
                            error = e
                        }
                        expect(error).toEventually(beAKindOf(GDPRConsentViewControllerError.self))
                    }
                }
            }
        }
    }
}
