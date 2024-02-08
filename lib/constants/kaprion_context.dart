import 'dart:async';

import 'package:dart_ssi/credentials.dart';
import 'package:json_ld_processor/json_ld_processor.dart';

FutureOr<RemoteDocument> loadDocumentKaprion(
    Uri url, LoadDocumentOptions? options) {
  if (url.toString() ==
      'https://demo.shop.kaprion.net/assets/credentialSubject/v3/id-ideal-ld-doc-v3.jsonld') {
    return RemoteDocument(document: kaprionContext3);
  } else if (url.toString() ==
      'https://demo.shop.kaprion.net/assets/credentialSubject/v4/id-ideal-ld-doc-v4.jsonld') {
    return RemoteDocument(document: kaprionContext4);
  } else if (url.toString() ==
      'https://demo.shop.kaprion.net/ControlService/credentialSubject/v4') {
    return RemoteDocument(document: kaprionContext4);
  } else {
    return loadDocumentFast(url, options);
  }
}

var kaprionContext4 = {
  "@context": [
    {"@version": 1.1},
    {
      "contextVersion": "4",
      "idideal": "https://demo.shop.kaprion.net/credentialSubject#",
      "schema": "http://schema.org/",
      "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      "xsd": "https://www.w3.org/TR/xmlschema11-2/#",
      "sec": "https://w3id.org/security#",
      "bank": "https://www.iban.com/country/germany#",
      "VDVTicket": "idideal:VDVTicket",
      "PublicKeyCertificate": "idideal:PublicKeyCertificate",
      "KDKPersonK": "idideal:KDKPersonK",
      "KDKAddressK": "idideal:KDKAddressK",
      "KDKBiometricPhotoK": "idideal:KDKBiometricPhotoK",
      "KDKBirthCertificateK": "idideal:KDKBirthCertificateK",
      "KDKAgeProofK": "idideal:KDKAgeProofK",
      "SEPADirectDebitMandate": "idideal:SEPADirectDebitMandate",
      "DresdenPass": "idideal:DresdenPass",
      "isProtectedByCRE": {
        "@id": "idideal:isProtectedByCRE",
        "@type": "schema:Boolean"
      },
      "brand": {"@id": "schema:brand", "@type": "schema:Text"},
      "name": {"@id": "schema:name", "@type": "schema:Text"},
      "passengerType": {"@id": "idideal:passengerType", "@type": "schema:Text"},
      "takeaway": {"@id": "idideal:takeaway", "@type": "idideal:TakeawayType"},
      "typeOfTakeaway": {
        "@id": "idideal:typeOfTakeaway",
        "@type": "schema:Text"
      },
      "quantity": {"@id": "idideal:quantity", "@type": "schema:Integer"},
      "category": {"@id": "schema:category", "@type": "schema:Text"},
      "class": {"@id": "idideal:class", "@type": "schema:Text"},
      "totalPrice": {
        "@id": "schema:totalPrice",
        "@type": "schema:PriceSpecification"
      },
      "price": {"@id": "schema:price", "@type": "schema:Number"},
      "priceCurrency": {"@id": "schema:priceCurrency", "@type": "schema:Text"},
      "valueAddedTaxIncluded": {
        "@id": "schema:valueAddedTaxIncluded",
        "@type": "schema:Boolean"
      },
      "vat": {"@id": "idideal:vat", "@type": "schema:Text"},
      "priceLevel": {"@id": "idideal:priceLevel", "@type": "schema:Integer"},
      "areaOfValidity": {
        "@id": "idideal:areaOfValidity",
        "@type": "idideal:AreaOfValidityType"
      },
      "provider": {"@id": "idideal:provider", "@type": "schema:Text"},
      "area": {"@id": "idideal:area", "@type": "schema:Text"},
      "ticketToken": {"@id": "idideal:ticketToken", "@type": "xsd:hexBinary"},
      "canIssue": {"@id": "idideal:canIssue", "@type": "schema:Text"},
      "sameAs": {"@id": "schema:sameAs", "@type": "schema:URL"},
      "address": {"@id": "schema:address", "@type": "schema:PostalAddress"},
      "addressCountry": {
        "@id": "schema:addressCountry",
        "@type": "schema:Text"
      },
      "addressLocality": {
        "@id": "schema:addressLocality",
        "@type": "schema:Text"
      },
      "addressRegion": {"@id": "schema:addressRegion", "@type": "schema:Text"},
      "postOfficeBoxNumber": {
        "@id": "schema:postOfficeBoxNumber",
        "@type": "schema:Text"
      },
      "postalCode": {"@id": "schema:postalCode", "@type": "schema:Text"},
      "streetAddress": {"@id": "schema:streetAddress", "@type": "schema:Text"},
      "areaServed": {"@id": "schema:areaServed", "@type": "@id"},
      "availableLanguage": {"@id": "schema:availableLanguage", "@type": "@id"},
      "contactOption": {
        "@id": "schema:contactOption",
        "@type": "schema:ContactPointOption"
      },
      "contactType": {"@id": "schema:contactType", "@type": "schema:Text"},
      "email": {"@id": "schema:email", "@type": "schema:Text"},
      "faxNumber": {"@id": "schema:faxNumber", "@type": "schema:Text"},
      "hoursAvailable": {
        "@id": "schema:hoursAvailable",
        "@type": "schema:OpeningHoursSpecification"
      },
      "productSupported": {"@id": "schema:productSupported", "@type": "@id"},
      "telephone": {"@id": "schema:telephone", "@type": "schema:Text"},
      "companyInformation": {
        "@id": "idideal:companyInformation",
        "@type": "idideal:CompanyInformationType"
      },
      "legalName": {"@id": "schema:legalName", "@type": "schema:Text"},
      "organizationType": {
        "@id": "idideal:organizationType",
        "@type": "schema:Text"
      },
      "registryNumber": {
        "@id": "idideal:registryNumber",
        "@type": "schema:Text"
      },
      "registry": {"@id": "idideal:registry", "@type": "schema:Text"},
      "publicKey": {"@id": "sec:publicKey", "@type": "@id"},
      "familyName": {"@id": "schema:familyName", "@type": "schema:Text"},
      "birthName": {"@id": "idideal:birthName", "@type": "schema:Text"},
      "givenName": {"@id": "schema:givenName", "@type": "schema:Text"},
      "gender": {"@id": "schema:gender", "@type": "schema:GenderType"},
      "streetName": {"@id": "schema:streetAddress", "@type": "schema:Text"},
      "houseNumber": {"@id": "idideal:houseNumber", "@type": "schema:Text"},
      "residentSince": {"@id": "idideal:residentSince", "@type": "xsd:date"},
      "image": {"@id": "schema:image", "@type": "schema:URL"},
      "img": {"@id": "schema:image", "@type": "schema:Text"},
      "encodingFormat": {
        "@id": "schema:encodingFormat",
        "@type": "schema:Text"
      },
      "sha256": {"@id": "schema:sha256", "@type": "schema:Text"},
      "birthDate": {"@id": "schema:birthDate", "@type": "schema:Date"},
      "birthPlace": {"@id": "schema:birthPlace", "@type": "schema:Text"},
      "parent": {"@id": "idideal:parent", "@type": "idideal:ParentType"},
      "termCode": {"@id": "schema:termCode", "@type": "schema:Text"},
      "inDefinedTermSet": {
        "@id": "schema:inDefinedTermSet",
        "@type": "schema:URL"
      },
      "meetsRequirement": {
        "@id": "idideal:meetsRequirement",
        "@type": "schema:Boolean"
      },
      "keywords": {"@id": "schema:keywords", "@type": "schema:Text"},
      "creditInstitution": {"@id": "schema:legalName", "@type": "schema:Text"},
      "iban": {"@id": "bank:3.%20IBAN%20Structure", "@type": "schema:Text"},
      "bic": {
        "@id": "bank:6.%20BIC%20and%20Structure%20of%20BIC%20Code",
        "@type": "schema:Text"
      },
      "repeatablePayment": {
        "@id": "idideal:repeatablePayment",
        "@type": "schema:Boolean"
      },
      "intendedUse": {"@id": "idideal:intendedUse", "@type": "schema:Text"},
      "provisionalHolder": {
        "@id": "idideal:provisionalHolder",
        "@type": "idideal:ProvisionalHolderType"
      },
      "Wohngeldbescheid": "idideal:Wohngeldbescheid",
      "Zahlungsempfaenger": {
        "@id": "idideal:Zahlungsempfaenger",
        "@type": "@id"
      },
      "typ": {"@id": "idideal:typ", "@type": "schema:Text"},
      "erstantrag": {"@id": "idideal:erstantrag", "@type": "schema:Boolean"},
      "einheit": {"@id": "idideal:einheit", "@type": "schema:currency"},
      "szenario": {"@id": "idideal:typ", "@type": "schema:Text"},
      "ihreAngaben": {
        "@id": "idideal:ihreAngaben",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "bruttoEinkommen": {
            "@id": "idideal:bruttoEinkommen",
            "@type": "schema:Number"
          },
          "bruttoMiete": {
            "@id": "idideal:bruttoMiete",
            "@type": "schema:Number"
          },
          "anzWohngeldBerechtigt": {
            "@id": "idideal:anzWohngeldBerechtigt",
            "@type": "schema:Number"
          },
          "kinderbetreuungskosten": {
            "@id": "idideal:kinderbetreuungskosten",
            "@type": "schema:Number"
          },
          "mietenstufe": {
            "@id": "idideal:mietenstufe",
            "@type": "schema:Number"
          }
        }
      },
      "berechnung": {
        "@id": "idideal:berechnung",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "werbungskosten": {
            "@id": "idideal:werbungskosten",
            "@type": "schema:Number"
          },
          "gesamtEinkommenNachAbzuegen": {
            "@id": "idideal:gesamtEinkommenNachAbzuegen",
            "@type": "schema:Number"
          },
          "berueksichtigungMiete": {
            "@id": "idideal:berueksichtigungMiete",
            "@type": "schema:Number"
          },
          "betriebskostenAbzug": {
            "@id": "idideal:betriebskostenAbzug",
            "@type": "schema:Number"
          },
          "heizkostenpauschale": {
            "@id": "idideal:heizkostenpauschale",
            "@type": "schema:Number"
          }
        }
      },
      "gesamtbetrag": {"@id": "idideal:gesamtbetrag", "@type": "schema:Number"},
      "SocialPass": "idideal:DresdenPass",
      "documentPresence": {
        "@id": "idideal:documentPresence",
        "@type": "schema:Text"
      },
      "evidenceDocument": {
        "@id": "idideal:evidenceDocument",
        "@type": "schema:Text"
      },
      "verifier": {"@id": "idideal:verifier", "@type": "@id"},
      "subjectPresence": {
        "@id": "idideal:subjectPresence",
        "@type": "schema:Boolean"
      },
      "docId": {"@id": "idideal:docId", "@type": "@id"},
      "controller": {"@id": "sec:controller", "@type": "@id"},
      "url": {"@id": "schema:url", "@type": "schema:URL"},
      "JsonWebKey2020": {
        "@id": "https://w3id.org/security#JsonWebKey2020",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "publicKeyJwk": {
            "@id": "https://w3id.org/security#publicKeyJwk",
            "@type": "@json"
          }
        }
      },
      "Besuchernachweis": "idideal:Besuchernachweis",
      "standName": "idideal:standName",
      "beschreibung": "idideal:beschreibung",
      "HidyContextDemo": "idideal:HidyContextDemo",
      "Ed25519VerificationKey2020": {
        "@id": "https://w3id.org/security#Ed25519VerificationKey2020",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "controller": {
            "@id": "https://w3id.org/security#controller",
            "@type": "@id"
          },
          "revoked": {
            "@id": "https://w3id.org/security#revoked",
            "@type": "http://www.w3.org/2001/XMLSchema#dateTime"
          },
          "publicKeyMultibase": {
            "@id": "https://w3id.org/security#publicKeyMultibase",
            "@type": "https://w3id.org/security#multibase"
          }
        }
      }
    }
  ]
};

var kaprionContext3 = {
  "@context": [
    {"@version": 1.1},
    {
      "contextVersion": "3.3",
      "idideal": "https://demo.shop.kaprion.net/credentialSubject#",
      "schema": "http://schema.org/",
      "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      "xsd": "https://www.w3.org/TR/xmlschema11-2/#",
      "sec": "https://w3id.org/security#",
      "bank": "https://www.iban.com/country/germany#",
      "VDVTicket": "idideal:VDVTicket",
      "PublicKeyCertificate": "idideal:PublicKeyCertificate",
      "KDKPersonK": "idideal:KDKPersonK",
      "KDKAddressK": "idideal:KDKAddressK",
      "KDKBiometricPhotoK": "idideal:KDKBiometricPhotoK",
      "KDKBirthCertificateK": "idideal:KDKBirthCertificateK",
      "KDKAgeProofK": "idideal:KDKAgeProofK",
      "SEPADirectDebitMandate": "idideal:SEPADirectDebitMandate",
      "DresdenPass": "idideal:DresdenPass",
      "isProtectedByCRE": {
        "@id": "idideal:isProtectedByCRE",
        "@type": "schema:Boolean"
      },
      "brand": {"@id": "schema:brand", "@type": "schema:Text"},
      "name": {"@id": "schema:name", "@type": "schema:Text"},
      "passengerType": {"@id": "idideal:passengerType", "@type": "schema:Text"},
      "takeaway": {"@id": "idideal:takeaway", "@type": "idideal:TakeawayType"},
      "typeOfTakeaway": {
        "@id": "idideal:typeOfTakeaway",
        "@type": "schema:Text"
      },
      "quantity": {"@id": "idideal:quantity", "@type": "schema:Integer"},
      "category": {"@id": "schema:category", "@type": "schema:Text"},
      "class": {"@id": "idideal:class", "@type": "schema:Text"},
      "totalPrice": {
        "@id": "schema:totalPrice",
        "@type": "schema:PriceSpecification"
      },
      "price": {"@id": "schema:price", "@type": "schema:Number"},
      "priceCurrency": {"@id": "schema:priceCurrency", "@type": "schema:Text"},
      "valueAddedTaxIncluded": {
        "@id": "schema:valueAddedTaxIncluded",
        "@type": "schema:Boolean"
      },
      "vat": {"@id": "idideal:vat", "@type": "schema:Text"},
      "priceLevel": {"@id": "idideal:priceLevel", "@type": "schema:Integer"},
      "areaOfValidity": {
        "@id": "idideal:areaOfValidity",
        "@type": "idideal:AreaOfValidityType"
      },
      "provider": {"@id": "idideal:provider", "@type": "schema:Text"},
      "area": {"@id": "idideal:area", "@type": "schema:Text"},
      "ticketToken": {"@id": "idideal:ticketToken", "@type": "xsd:hexBinary"},
      "canIssue": {"@id": "idideal:canIssue", "@type": "schema:Text"},
      "sameAs": {"@id": "schema:sameAs", "@type": "schema:URL"},
      "address": {"@id": "schema:address", "@type": "schema:PostalAddress"},
      "addressCountry": {
        "@id": "schema:addressCountry",
        "@type": "schema:Text"
      },
      "addressLocality": {
        "@id": "schema:addressLocality",
        "@type": "schema:Text"
      },
      "addressRegion": {"@id": "schema:addressRegion", "@type": "schema:Text"},
      "postOfficeBoxNumber": {
        "@id": "schema:postOfficeBoxNumber",
        "@type": "schema:Text"
      },
      "postalCode": {"@id": "schema:postalCode", "@type": "schema:Text"},
      "streetAddress": {"@id": "schema:streetAddress", "@type": "schema:Text"},
      "areaServed": {"@id": "schema:areaServed", "@type": "@id"},
      "availableLanguage": {"@id": "schema:availableLanguage", "@type": "@id"},
      "contactOption": {
        "@id": "schema:contactOption",
        "@type": "schema:ContactPointOption"
      },
      "contactType": {"@id": "schema:contactType", "@type": "schema:Text"},
      "email": {"@id": "schema:email", "@type": "schema:Text"},
      "faxNumber": {"@id": "schema:faxNumber", "@type": "schema:Text"},
      "hoursAvailable": {
        "@id": "schema:hoursAvailable",
        "@type": "schema:OpeningHoursSpecification"
      },
      "productSupported": {"@id": "schema:productSupported", "@type": "@id"},
      "telephone": {"@id": "schema:telephone", "@type": "schema:Text"},
      "companyInformation": {
        "@id": "idideal:companyInformation",
        "@type": "idideal:CompanyInformationType"
      },
      "legalName": {"@id": "schema:legalName", "@type": "schema:Text"},
      "organizationType": {
        "@id": "idideal:organizationType",
        "@type": "schema:Text"
      },
      "registryNumber": {
        "@id": "idideal:registryNumber",
        "@type": "schema:Text"
      },
      "registry": {"@id": "idideal:registry", "@type": "schema:Text"},
      "publicKey": {"@id": "sec:publicKey", "@type": "@id"},
      "familyName": {"@id": "schema:familyName", "@type": "schema:Text"},
      "birthName": {"@id": "idideal:birthName", "@type": "schema:Text"},
      "givenName": {"@id": "schema:givenName", "@type": "schema:Text"},
      "gender": {"@id": "schema:gender", "@type": "schema:GenderType"},
      "streetName": {"@id": "schema:streetAddress", "@type": "schema:Text"},
      "houseNumber": {"@id": "idideal:houseNumber", "@type": "schema:Text"},
      "residentSince": {"@id": "idideal:residentSince", "@type": "xsd:date"},
      "image": {"@id": "schema:image", "@type": "schema:URL"},
      "img": {"@id": "schema:image", "@type": "schema:Text"},
      "encodingFormat": {
        "@id": "schema:encodingFormat",
        "@type": "schema:Text"
      },
      "sha256": {"@id": "schema:sha256", "@type": "schema:Text"},
      "birthDate": {"@id": "schema:birthDate", "@type": "schema:Date"},
      "birthPlace": {"@id": "schema:birthPlace", "@type": "schema:Text"},
      "parent": {"@id": "idideal:parent", "@type": "idideal:ParentType"},
      "termCode": {"@id": "schema:termCode", "@type": "schema:Text"},
      "inDefinedTermSet": {
        "@id": "schema:inDefinedTermSet",
        "@type": "schema:URL"
      },
      "meetsRequirement": {
        "@id": "idideal:meetsRequirement",
        "@type": "schema:Boolean"
      },
      "keywords": {"@id": "schema:keywords", "@type": "schema:Text"},
      "creditInstitution": {"@id": "schema:legalName", "@type": "schema:Text"},
      "iban": {"@id": "bank:3.%20IBAN%20Structure", "@type": "schema:Text"},
      "bic": {
        "@id": "bank:6.%20BIC%20and%20Structure%20of%20BIC%20Code",
        "@type": "schema:Text"
      },
      "repeatablePayment": {
        "@id": "idideal:repeatablePayment",
        "@type": "schema:Boolean"
      },
      "intendedUse": {"@id": "idideal:intendedUse", "@type": "schema:Text"},
      "provisionalHolder": {
        "@id": "idideal:provisionalHolder",
        "@type": "idideal:ProvisionalHolderType"
      },
      "Wohngeldbescheid": "idideal:Wohngeldbescheid",
      "Zahlungsempfaenger": {
        "@id": "idideal:Zahlungsempfaenger",
        "@type": "@id"
      },
      "typ": {"@id": "idideal:typ", "@type": "schema:Text"},
      "erstantrag": {"@id": "idideal:erstantrag", "@type": "schema:Boolean"},
      "einheit": {"@id": "idideal:einheit", "@type": "schema:currency"},
      "szenario": {"@id": "idideal:typ", "@type": "schema:Text"},
      "ihreAngaben": {
        "@id": "idideal:ihreAngaben",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "bruttoEinkommen": {
            "@id": "idideal:bruttoEinkommen",
            "@type": "schema:Number"
          },
          "bruttoMiete": {
            "@id": "idideal:bruttoMiete",
            "@type": "schema:Number"
          },
          "anzWohngeldBerechtigt": {
            "@id": "idideal:anzWohngeldBerechtigt",
            "@type": "schema:Number"
          },
          "kinderbetreuungskosten": {
            "@id": "idideal:kinderbetreuungskosten",
            "@type": "schema:Number"
          },
          "mietenstufe": {
            "@id": "idideal:mietenstufe",
            "@type": "schema:Number"
          }
        }
      },
      "berechnung": {
        "@id": "idideal:berechnung",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "werbungskosten": {
            "@id": "idideal:werbungskosten",
            "@type": "schema:Number"
          },
          "gesamtEinkommenNachAbzuegen": {
            "@id": "idideal:gesamtEinkommenNachAbzuegen",
            "@type": "schema:Number"
          },
          "berueksichtigungMiete": {
            "@id": "idideal:berueksichtigungMiete",
            "@type": "schema:Number"
          },
          "betriebskostenAbzug": {
            "@id": "idideal:betriebskostenAbzug",
            "@type": "schema:Number"
          },
          "heizkostenpauschale": {
            "@id": "idideal:heizkostenpauschale",
            "@type": "schema:Number"
          }
        }
      },
      "gesamtbetrag": {"@id": "idideal:gesamtbetrag", "@type": "schema:Number"},
      "SocialPass": "idideal:DresdenPass",
      "documentPresence": {
        "@id": "idideal:documentPresence",
        "@type": "schema:Text"
      },
      "evidenceDocument": {
        "@id": "idideal:evidenceDocument",
        "@type": "schema:Text"
      },
      "verifier": {"@id": "idideal:verifier", "@type": "@id"},
      "subjectPresence": {
        "@id": "idideal:subjectPresence",
        "@type": "schema:Boolean"
      },
      "docId": {"@id": "idideal:docId", "@type": "@id"},
      "JsonWebKey2020": {
        "@id": "https://w3id.org/security#JsonWebKey2020",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "publicKeyJwk": {
            "@id": "https://w3id.org/security#publicKeyJwk",
            "@type": "@json"
          }
        }
      },
      "Ed25519VerificationKey2020": {
        "@id": "https://w3id.org/security#Ed25519VerificationKey2020",
        "@context": {
          "@protected": true,
          "id": "@id",
          "type": "@type",
          "controller": {
            "@id": "https://w3id.org/security#controller",
            "@type": "@id"
          },
          "revoked": {
            "@id": "https://w3id.org/security#revoked",
            "@type": "http://www.w3.org/2001/XMLSchema#dateTime"
          },
          "publicKeyMultibase": {
            "@id": "https://w3id.org/security#publicKeyMultibase",
            "@type": "https://w3id.org/security#multibase"
          }
        }
      }
    }
  ]
};
