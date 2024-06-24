import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

Map<String, String> translationAttributes = {
  'Address': 'Adresse',
  'BirthName': 'Geburtsname',
  'FamilyName': 'Familienname',
  'GivenNames': 'Vorname(n)',
  'PlaceOfBirth': 'Geburtsort',
  'DateOfBirth': 'Geburtsdatum',
  'DoctoralDegree': 'Doktortitel',
  'ArtisticName': 'Künstlername',
  'ValidUntil': 'Ablaufdatum',
  'Nationality': 'Staatsangehörigkeit',
  'IssuingCountry': 'Aussteller-Land',
  'DocumentType': 'Dokumententyp',
  'ResidencePermitI': 'Aufenthaltserlaubnis 1',
  'ResidencePermitII': 'Aufenthaltserlaubnis 2',
  'CommunityID': 'Wohnort-ID',
  'AddressVerification': 'Adressverifikation',
  'AgeVerification': 'Altersverifikation'
};

class MainContent extends StatelessWidget {
  const MainContent({super.key});

  List<Widget> buildContent(AusweisProvider ausweis, BuildContext context) {
    return [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Card(
              child: ListTile(
            subtitle: Text(
              ausweis.requesterCert!.subjectName,
            ),
            title: Text('Anfragender'),
            onTap: () => showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 30),
                      child: Scaffold(
                        body: ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              title: Text('Anfragender'),
                              subtitle: Text(
                                  '${ausweis.requesterCert!.subjectName}\n${ausweis.requesterCert!.subjectUrl}'),
                            ),
                            ListTile(
                              title: Text(
                                  'Aussteller des Berechtigungszertifikats'),
                              subtitle: Text(
                                  '${ausweis.requesterCert!.issuerName}\n${ausweis.requesterCert!.issuerUrl}'),
                            ),
                            ListTile(
                              title: Text('Gültigkeit'),
                              subtitle: Text(
                                  '${ausweis.requesterCert!.effectiveDate.day.toString().padLeft(2, '0')}.${ausweis.requesterCert!.effectiveDate.month.toString().padLeft(2, '0')}.${ausweis.requesterCert!.effectiveDate.year} - ${ausweis.requesterCert!.expirationDate.day.toString().padLeft(2, '0')}.${ausweis.requesterCert!.expirationDate.month.toString().padLeft(2, '0')}.${ausweis.requesterCert!.expirationDate.year}'),
                            ),
                            if (ausweis.requesterCert!.purpose.isNotEmpty)
                              ListTile(
                                title: Text('Grund'),
                                subtitle: Text(ausweis.requesterCert!.purpose),
                              ),
                            ListTile(
                              title: Text('Anbieterinformationen'),
                              subtitle:
                                  Text(ausweis.requesterCert!.termsOfUsage),
                            )
                          ],
                        ),
                        persistentFooterButtons: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Ok'))
                        ],
                      ));
                }),
          ))),
      const SizedBox(
        height: 10,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Card(
          child:
              ExpansionTile(title: const Text('Angefragte Daten:'), children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ausweis.requestedAttributes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  visualDensity:
                      const VisualDensity(horizontal: 0, vertical: -4),
                  subtitle: Text(translationAttributes[
                          ausweis.requestedAttributes[index]] ??
                      ausweis.requestedAttributes[index]),
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return const Divider();
              },
            )
          ]),
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AusweisProvider>(builder: (context, ausweis, child) {
      return Scaffold(
        body: SingleChildScrollView(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
              Text(
                'Ausweisen',
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const SizedBox(
                height: 10,
              ),
              if (ausweis.requestedAttributes.isNotEmpty &&
                  ausweis.requesterCert != null)
                ...buildContent(ausweis, context)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LinearProgressIndicator(
                    value: ausweis.statusProgress,
                    minHeight: 7,
                    semanticsLabel: 'Anfrage wird geladen',
                    semanticsValue: 'Anfrage wird geladen',
                  ),
                ),
            ])),
        persistentFooterButtons: ausweis.requestedAttributes.isNotEmpty &&
                ausweis.requesterCert != null
            ? [
                FooterButtons(
                  positiveText: 'Weiter zur Pin Eingabe',
                  positiveFunction: () =>
                      Provider.of<AusweisProvider>(context, listen: false)
                          .accept(),
                  negativeFunction: () =>
                      Provider.of<AusweisProvider>(context, listen: false)
                          .cancel(),
                ),
              ]
            : [],
      );
    });
  }
}
