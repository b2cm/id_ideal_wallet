import 'package:x509b/x509.dart';

String rootCertsAsPem = '''
-----BEGIN CERTIFICATE-----
MIICejCCAiCgAwIBAgIUYd0daWz8yPdNjWysHwDxs98P12AwCgYIKoZIzj0EAwIw
gZMxCzAJBgNVBAYTAkRFMRAwDgYDVQQIDAdTYWNoc2VuMRIwEAYDVQQHDAlNaXR0
d2VpZGExHDAaBgNVBAoME0hvY2hzY2h1bGUgTWl0dGVpZGExFjAUBgNVBAMMDWNh
LmVjLmhzbXcuZGUxKDAmBgkqhkiG9w0BCQEWGXNvbWVBZG1pbkBocy1taXR0d2Vp
ZGEuZGUwHhcNMjIxMDEzMTIyNjEyWhcNMjIxMTEyMTIyNjEyWjCBkzELMAkGA1UE
BhMCREUxEDAOBgNVBAgMB1NhY2hzZW4xEjAQBgNVBAcMCU1pdHR3ZWlkYTEcMBoG
A1UECgwTSG9jaHNjaHVsZSBNaXR0ZWlkYTEWMBQGA1UEAwwNY2EuZWMuaHNtdy5k
ZTEoMCYGCSqGSIb3DQEJARYZc29tZUFkbWluQGhzLW1pdHR3ZWlkYS5kZTBWMBAG
ByqGSM49AgEGBSuBBAAKA0IABBGTXkhDBD1O8iP/tjtk8rpqUokOyojoeNU1rvlK
sxmVEuMcmzO3BualzALps1vytM1ROoT96Y5RAuNSiSoOgc+jUzBRMB0GA1UdDgQW
BBTIHdhmIYFWzJlq08atlIiFMzTqbTAfBgNVHSMEGDAWgBTIHdhmIYFWzJlq08at
lIiFMzTqbTAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIC1Mn5fT
gMcucYzWZ/SvIoXxCMcdDdUWi+t5PpZaRZ+pAiEA0hgrC3ylVYyYukuSO0UFY8i9
5Xdv4j1w4FO/wlYU7xY=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICsDCCAhmgAwIBAgIUY2QF5P6bhMIcqAs2xelalaNnzxEwDQYJKoZIhvcNAQEL
BQAwaTELMAkGA1UEBhMCREUxEjAQBgNVBAgMCU1pdHR3ZWlkYTESMBAGA1UEBwwJ
TWl0dHdlaWRhMR0wGwYDVQQKDBRIb2Noc2NodWxlIE1pdHR3ZWlkYTETMBEGA1UE
AwwKY2EuaHNtdy5kZTAgFw0yMjEwMDcxMDU4MDNaGA8yMDUwMDIyMjEwNTgwM1ow
aTELMAkGA1UEBhMCREUxEjAQBgNVBAgMCU1pdHR3ZWlkYTESMBAGA1UEBwwJTWl0
dHdlaWRhMR0wGwYDVQQKDBRIb2Noc2NodWxlIE1pdHR3ZWlkYTETMBEGA1UEAwwK
Y2EuaHNtdy5kZTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA04f792epPH1S
MEBuktLbKBC97YMiYUL456Eq8YzIIX64k2pmERrjynoREMgdnIAu+dpZOJuVllJa
lWyXyWVkXVGZ0gLFdDXU8k+NdROiPEDnUvFaZvn9g9B89r0Agf1/BCW/YdQ6AjXd
AZbIcXsSwoA28UJCMTd+95yuJkdjZaMCAwEAAaNTMFEwHQYDVR0OBBYEFLqEkAUs
CIEk/d7449FshSclgT6jMB8GA1UdIwQYMBaAFLqEkAUsCIEk/d7449FshSclgT6j
MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADgYEAUWy9PPRG/EINGbBJ
Loi1qxCdszQZwfDBLBgQFf36u0o3+kgpzytDcVbZH+kYO8KdfskMbaGfNL44TIOD
8+n77t53qfGFzfMdf+ehXW/vTrbrGXftGeriEJVjHTbIh9XT/mK8FilIAI7n1A3g
ZR7M9OI/3Qhe56xr4gB5hl1iln8=
-----END CERTIFICATE-----
''';

var rootCerts = parsePem(rootCertsAsPem).toList().cast<X509Certificate>();
