//
//  SourcePointClient.swift
//  GDPRConsentViewController
//
//  Created by Andre Herculano on 13.03.19.
//

import Foundation

protocol SourcePointProtocol {
    init(
        accountId: Int,
        propertyId: Int,
        propertyName: GDPRPropertyName,
        pmId: String,
        campaignEnv: GDPRCampaignEnv,
        targetingParams: TargetingParams,
        timeout: TimeInterval
    )

    // swiftlint:disable:next function_parameter_count
    func getMessage(
        native: Bool,
        consentUUID: GDPRUUID?,
        euconsent: String,
        authId: String?,
        meta: Meta,
        completionHandler: @escaping (MessageResponse?, GDPRConsentViewControllerError?)
    -> Void)

    func postAction(
        action: GDPRAction,
        consentUUID: GDPRUUID,
        meta: Meta,
        completionHandler: @escaping (ActionResponse?, GDPRConsentViewControllerError?)
    -> Void)

    func customConsent(
        toConsentUUID consentUUID: String,
        vendors: [String],
        categories: [String],
        legIntCategories: [String],
        completionHandler: @escaping (CustomConsentResponse?, GDPRConsentViewControllerError?)
    -> Void)

    func setRequestTimeout(_ timeout: TimeInterval)
}

/**
A Http client for SourcePoint's endpoints
 - Important: it should only be used the SDK as its public API is still in constant development and is probably going to change.
 */
class SourcePointClient: SourcePointProtocol {
    static let WRAPPER_API = URL(string: "https://cdn.privacy-mgmt.com/wrapper/tcfv2/v1/gdpr/")!
    static let GET_MESSAGE_CONTENTS_URL = URL(string: "native-message?inApp=true", relativeTo: SourcePointClient.WRAPPER_API)!
    static let GET_MESSAGE_URL_URL = URL(string: "message-url?inApp=true", relativeTo: SourcePointClient.WRAPPER_API)!
    static let CONSENT_URL = URL(string: "consent?inApp=true", relativeTo: SourcePointClient.WRAPPER_API)!
    static let CUSTOM_CONSENT_URL = URL(string: "custom-consent?inApp=true", relativeTo: SourcePointClient.WRAPPER_API)!

    var client: HttpClient

    let requestUUID = UUID()

    let accountId: Int
    let propertyId: Int
    let propertyName: GDPRPropertyName
    let pmId: String
    let campaignEnv: GDPRCampaignEnv
    let targetingParams: TargetingParams?

    init(
        accountId: Int,
        propertyId: Int,
        propertyName: GDPRPropertyName,
        pmId: String,
        campaignEnv: GDPRCampaignEnv,
        targetingParams: TargetingParams?,
        client: HttpClient
    ) {
        self.accountId = accountId
        self.propertyId = propertyId
        self.propertyName = propertyName
        self.pmId = pmId
        self.campaignEnv = campaignEnv
        self.targetingParams = targetingParams
        self.client = client
    }

    required convenience init(
        accountId: Int,
        propertyId: Int,
        propertyName: GDPRPropertyName,
        pmId: String,
        campaignEnv: GDPRCampaignEnv,
        targetingParams: TargetingParams,
        timeout: TimeInterval
    ) {
        self.init(
            accountId: accountId,
            propertyId: propertyId,
            propertyName: propertyName,
            pmId: pmId,
            campaignEnv: campaignEnv,
            targetingParams: targetingParams,
            client: SimpleClient(timeoutAfter: timeout)
        )
    }

    func setRequestTimeout(_ timeout: TimeInterval) {
        client = SimpleClient(timeoutAfter: timeout)
    }

    func targetingParamsToString(_ params: TargetingParams?) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: params ?? [:]),
            let paramsString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return paramsString
    }

    // swiftlint:disable:next function_parameter_count line_length
    func getMessage(url: URL, consentUUID: GDPRUUID?, euconsent: String, authId: String?, meta: Meta, completionHandler: @escaping (MessageResponse?, GDPRConsentViewControllerError? ) -> Void) {
        do {
            let body = try JSONEncoder().encode(MessageRequest(
                uuid: consentUUID,
                euconsent: euconsent,
                authId: authId,
                accountId: accountId,
                propertyId: propertyId,
                propertyHref: propertyName,
                campaignEnv: campaignEnv,
                targetingParams: targetingParamsToString(targetingParams),
                requestUUID: requestUUID,
                meta: meta
            ))
            client.post(urlString: url.absoluteString, body: body) { data, error in
                if let error = error {
                    completionHandler(nil, error)
                } else {
                    do {
                        completionHandler(try JSONDecoder().decode(MessageResponse.self, from: data!), nil)
                    } catch {
                        completionHandler(nil, InvalidResponseWebMessageError(error as? DecodingError))
                    }
                }
            }
        } catch {
            completionHandler(nil, InvalidRequestError(error as? DecodingError))
        }
    }

    // swiftlint:disable:next line_length function_parameter_count
    func getMessage(native: Bool, consentUUID: GDPRUUID?, euconsent: String, authId: String?, meta: Meta, completionHandler: @escaping (MessageResponse?, GDPRConsentViewControllerError?) -> Void) {
        getMessage(
            url: native ?
                SourcePointClient.GET_MESSAGE_CONTENTS_URL :
                SourcePointClient.GET_MESSAGE_URL_URL,
            consentUUID: consentUUID,
            euconsent: euconsent,
            authId: authId,
            meta: meta,
            completionHandler: completionHandler
        )
    }

    func postAction(action: GDPRAction, consentUUID: GDPRUUID, meta: Meta, completionHandler: @escaping (ActionResponse?, GDPRConsentViewControllerError?) -> Void) {
        let url = SourcePointClient.CONSENT_URL

        do {
            let pmPayload = try JSONDecoder().decode(SPGDPRArbitraryJson.self, from: action.payload)
            let body = try JSONEncoder().encode(ActionRequest(
                propertyId: propertyId,
                propertyHref: propertyName,
                accountId: accountId,
                actionType: action.type.rawValue,
                choiceId: action.id,
                privacyManagerId: pmId,
                requestFromPM: action.id == nil,
                uuid: consentUUID,
                requestUUID: requestUUID,
                pmSaveAndExitVariables: pmPayload,
                meta: meta,
                publisherData: action.publisherData,
                consentLanguage: action.consentLanguage
            ))
            client.post(urlString: url.absoluteString, body: body) { data, error  in
                if let error = error {
                    completionHandler(nil, error)
                } else {
                    do {
                        completionHandler(try JSONDecoder().decode(ActionResponse.self, from: data!), nil)
                    } catch {
                        completionHandler(nil, InvalidResponseConsentError(error as? DecodingError))
                    }
                }
            }
        } catch {
            completionHandler(nil, InvalidRequestError(error as? DecodingError))
        }
    }

    func customConsent(
        toConsentUUID consentUUID: String,
        vendors: [String],
        categories: [String],
        legIntCategories: [String],
        completionHandler: @escaping (CustomConsentResponse?, GDPRConsentViewControllerError?) -> Void) {
        do {
            let body = try JSONEncoder().encode(CustomConsentRequest(
                consentUUID: consentUUID,
                propertyId: propertyId,
                vendors: vendors,
                categories: categories,
                legIntCategories: legIntCategories
            ))
            client.post(urlString: SourcePointClient.CUSTOM_CONSENT_URL.absoluteString, body: body) { data, error in
                if let error = error {
                    completionHandler(nil, error)
                } else {
                    do {
                        completionHandler(try JSONDecoder().decode(CustomConsentResponse.self, from: data!), nil)
                    } catch {
                        completionHandler(nil, InvalidResponseConsentError(error as? DecodingError))
                    }
                }
            }
        } catch {
            completionHandler(nil, InvalidRequestError(error as? DecodingError))
        }
    }
}
