# Envelope handling
The wallet could receive Didcomm encrypted messages, didcomm signed messages and Out of Band messages.
These must be handled to find the relevant plaintext message in it.

```mermaid
flowchart TB
A(Receive message)
B(check for Attachment)
C(decrypt message)
D{message typ?}
E(check signature)
F(getPayload)
G(get message from Attachment)

Fin(handle message based on type)

A-->D

D--Out-Of-Band message-->B
B-->G
G--plaintext message expected-->Fin

D--plaintext message-->Fin

D--encrypted message-->C
D--signed message-->E

F-->D
C-->F
E-->F
```

**Note**: sending problem reports is not implemented yet; wallet will only throw exception

# Offer Credential

```mermaid
flowchart TB
A(get offered credential and details from message)
B{proof type supported?}
C(send Problem report)
D{does the wallet control the did}
E(generate new did)
F(show credential to user)
G{Accept?}
H(send Problem report)
I(build propose credential message with new did in credential)
J(sign attachment of this message)
K(send propose credential)
L(build and send request credential message)

A-->B
B--No-->C
B--Yes-->D
D--Yes-->L
D--No-->F
F-->G
G--No-->H
G--Yes-->E
E-->I
I-->J
J-->K
```

# Issue Credential
```mermaid
flowchart TB
A(get previous message from wallet)
B{is request credential?}
C(send problem report)
D(get credential from issue message)
E(check signature of credential)
F(send problem report)
G(store in wallet)
H(send ack)

A-->B
B--No-->C
B--Yes-->D
D-->E
E--invalid-->F
E--valid-->G
G-->H

```
**Note**: sending problem reports is not implemented yet; wallet will only throw exception

# Request Presentation
```mermaid
flowchart TB
A(get presentaion definition from message)
B(get all credentials from Wallet)
C(filter credential list with presentaion definition)
D(show filter result to user)
E{send?}
F(send problem report)
G(build and sign presenation)
H(build and send presentation message)

A-->B
B-->C
C-->D
D-->E
E--No-->F
E--Yes-->G
G-->H
```
