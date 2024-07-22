# Openid4VCI

```mermaid
flowchart TD
a[Credential Offer] --> b[Issuer metadaten]
b --> c[get offered credential & show to user]
c -- User accepted --> d[check grant type]
d -- Pre-Authorized --> e[get auth server metadata]

subgraph A[Authorization]
d -- authorization code --> f[Registerd with auth-server? Client metadata available]
f --no-->g[show error]
f --yes --> h[generate pkce codeVerifier and -Challenge]
h --> i[get metadata of auth-server]
i -- no metadata found --> j[launch auth frontend with standard endpoint authserver/authorize]
i -- metadata found --> k[check if issuer in metadata is authserver]
k -- no --> l[show Error]
k -- yes --> m[check if endpoint for pushed request is available]
m -- yes -->n[do pushed request = post]
n -- request sucessfull 200 or 201 --> o[open request uri in webview]
n -- request failed --> p[show error]
m -- no --> q[get authorization_endpoint from metadata]
q -- not found --> r[show error]
q -- found --> s[launch = redirect to auth endpoint]
end


s --> t[wait for redirected response to wallet.bccm.dev/redirect]
o --> t
j --> t
t --> u[evaluate state and code]
u --> w[get stored process information]
u -- state or code not send --> v[show error]

subgraph B[Token]
w --> e
e --> x[token_endpoint given in metadata]
x -- yes --> y[use given endpoint]
x -- no --> z[use standard endpoint  authserver/token]
y --> aa[ get request token]
z --> aa
end


aa --failed --> bb[show error]

subgraph C[Credential]
aa -- success --> cc[get credential issuer metadata]
cc -- tokenresponse contains no cNonce --> dd[send false credential request]
dd --> ee[get credential error response with cNonce]
cc -- tokenresponse has cNonce --> ff[check supported proof type in issuer metadata]
ee --> ff
ff -- nothing given --> gg[generate jwt proof]
ff -- jwt --> gg
ff -- ldp_vp --> hh[generate ldp_vp proof]
ff -- cwt --> ii[not supported = show error ]
gg --> jj[check if response encryption is required]
hh --> jj
jj -- yes --> kk[generate decryption keyPair]
kk --> ll[request credential = credential-endpoint]
jj -- no --> ll
ll -- sucessfull response encrypted--> mm[decrypt response]
mm --> nn[credential contained in response?]
ll -- successfull response cleartext --> nn
nn -- yes --> oo[store credential]
nn -- no, only transaction_id -->pp[wait some seconds + do request to deferred endpoint]
pp --> nn
end

```

## auth request parameter (redirect)

- response_type=code
- client_id
- redirect_uri
- state
- code_challenge
- code_challenge_method=S256

## pushed request parameter

- client_id
- redirect_uri
- response_type=code
- state
- code_challenge
- code_challenge_method=S256
- scope *or*
- authorization_details

## auth request parameter (redirect after pushed)

- client_id
- redirect_uri
- request_uri
- state
- response_type=code
- nonce=abcdefg
- scope (if given in offer)

## token request pre auth parameter

- grant_type
- pre-authorized_code
- user_pin (if required)

## token request auth flow parameter

- grant_type=authorization_code
- code
- client_id
- redirect_uri
- state
- code_verifier

## Credential Response Encryption

### Supported Alg values

- [x] RSA-OEAP-256
- [ ] ECDH-ES

### Supported Enc values

- [x] A128CBC-HS256
- [x] A192CBC-HS384 (since 3.2.3)
- [x] A256CBC-HS512 (since 3.2.3)
- [x] A128GCM (since 3.2.3)
- [x] A192GCM (since 3.2.3)
- [x] A256GCM (since 3.2.3)
