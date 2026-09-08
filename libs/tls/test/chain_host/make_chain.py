#!/usr/bin/env python3
"""Write the certificates the chain-validation test judges.

The validator's job is to say no.  What it must say no TO is a set of
certificates that are wrong in one specific way each -- past its validity
window, covering a different host, issued by something that is not a CA, not
reaching a pinned root -- and each of those has to be a real certificate,
signed for real, or the test proves nothing about the check it is aiming at.
So they are generated here rather than hand-written: `cryptography` builds and
signs them, and the fixture is only ever as wrong as the case name says.

Everything is ECDSA P-256 or Ed25519, both of which the client computes in
pure Ada.  The RSA links go through the ESP32-S3's accelerator, so they can
only be checked on the board -- examples/esp32s3_x509_chain does that.
"""
import datetime as dt
import os
import sys

try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, ed25519, rsa
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
except ImportError:
    sys.exit("needs python3-cryptography (pip install cryptography)")

HOST = "test.example.com"
UTC = dt.timezone.utc


def when(year, month=1, day=1):
    return dt.datetime(year, month, day, tzinfo=UTC)


def name(common):
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common)])


def new_key(kind):
    if kind == "ed25519":
        return ed25519.Ed25519PrivateKey.generate()
    if kind == "rsa":
        return rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return ec.generate_private_key(ec.SECP256R1())


def sign(builder, issuer_key, digest=None):
    #  Ed25519 signs the message itself, so it takes no digest argument;
    #  the others take one, SHA-256 unless the caller wants a different link.
    if isinstance(issuer_key, ed25519.Ed25519PrivateKey):
        return builder.sign(issuer_key, None)
    return builder.sign(issuer_key, digest or hashes.SHA256())


def make(subject, key, issuer, issuer_key, *, ca, not_before=when(2020),
         not_after=when(2035), sans=(), eku=None, key_usage=None, digest=None):
    b = (x509.CertificateBuilder()
         .subject_name(name(subject))
         .issuer_name(name(issuer))
         .public_key(key.public_key())
         .serial_number(x509.random_serial_number())
         .not_valid_before(not_before)
         .not_valid_after(not_after)
         .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True))
    if sans:
        b = b.add_extension(
            x509.SubjectAlternativeName([x509.DNSName(s) for s in sans]), critical=False)
    if eku:
        b = b.add_extension(x509.ExtendedKeyUsage(eku), critical=False)
    if key_usage:
        b = b.add_extension(key_usage, critical=True)
    return sign(b, issuer_key, digest)


CA_USAGE = x509.KeyUsage(
    digital_signature=False, content_commitment=False, key_encipherment=False,
    data_encipherment=False, key_agreement=False, key_cert_sign=True,
    crl_sign=True, encipher_only=False, decipher_only=False)

LEAF_USAGE = x509.KeyUsage(
    digital_signature=True, content_commitment=False, key_encipherment=False,
    data_encipherment=False, key_agreement=False, key_cert_sign=False,
    crl_sign=False, encipher_only=False, decipher_only=False)

SERVER = [ExtendedKeyUsageOID.SERVER_AUTH]
CLIENT = [ExtendedKeyUsageOID.CLIENT_AUTH]


def build():
    out = {}

    #  The good PKI: a pinned root, an intermediate under it, and a leaf that
    #  covers HOST outright and *.wild.example.com by wildcard.
    root_key = new_key("p256")
    root = make("Host Test Root", root_key, "Host Test Root", root_key,
                ca=True, key_usage=CA_USAGE)
    inter_key = new_key("p256")
    inter = make("Host Test Intermediate", inter_key, "Host Test Root", root_key,
                 ca=True, key_usage=CA_USAGE)
    leaf_key = new_key("p256")

    def leaf(subject_key, **kw):
        kw.setdefault("sans", (HOST, "*.wild.example.com"))
        kw.setdefault("eku", SERVER)
        kw.setdefault("key_usage", LEAF_USAGE)
        return make(HOST, subject_key, "Host Test Intermediate", inter_key,
                    ca=False, **kw)

    out["root"] = root
    out["inter"] = inter
    out["leaf"] = leaf(leaf_key)

    #  One wrong thing each, and nothing else different.
    out["leaf_expired"] = leaf(leaf_key, not_before=when(2020), not_after=when(2021))
    out["leaf_clientauth"] = leaf(leaf_key, eku=CLIENT)

    #  An issuer whose signature verifies but which is marked CA:FALSE -- the
    #  case basicConstraints exists for.
    rogue_key = new_key("p256")
    out["notca"] = make("Host Test Not A CA", rogue_key, "Host Test Root", root_key,
                        ca=False, key_usage=CA_USAGE)
    out["leaf_under_notca"] = make(
        HOST, leaf_key, "Host Test Not A CA", rogue_key, ca=False,
        sans=(HOST,), eku=SERVER, key_usage=LEAF_USAGE)

    #  A perfectly good root that simply is not the pinned one.
    other_key = new_key("p256")
    out["other_root"] = make("Unrelated Root", other_key, "Unrelated Root", other_key,
                             ca=True, key_usage=CA_USAGE)

    #  The same shape again in Ed25519, so the test covers both pure-Ada
    #  signature algorithms rather than only the one the policy cases use.
    ed_root_key = new_key("ed25519")
    out["ed_root"] = make("Host Test Ed Root", ed_root_key, "Host Test Ed Root",
                          ed_root_key, ca=True, key_usage=CA_USAGE)
    out["ed_leaf"] = make(HOST, new_key("ed25519"), "Host Test Ed Root", ed_root_key,
                          ca=False, sans=(HOST,), eku=SERVER, key_usage=LEAF_USAGE)

    #  RSA, one certificate per digest.  Their signatures can only be CHECKED on
    #  the board, but they are parsed here: the DER strictness rules the parser
    #  applies are the same for every algorithm, and a rule that quietly stopped
    #  RSA certificates parsing would take the real trust anchors with it.
    rsa_root_key = new_key("rsa")
    rsa_leaf_key = new_key("rsa")
    for digest in (hashes.SHA256(), hashes.SHA384(), hashes.SHA512()):
        tag = digest.name                                   # sha256 / sha384 / sha512
        out["rsa_root_" + tag] = make(
            "Host Test RSA Root " + tag, rsa_root_key, "Host Test RSA Root " + tag,
            rsa_root_key, ca=True, key_usage=CA_USAGE, digest=digest)
        out["rsa_leaf_" + tag] = make(
            HOST, rsa_leaf_key, "Host Test RSA Root " + tag, rsa_root_key, ca=False,
            sans=(HOST,), eku=SERVER, key_usage=LEAF_USAGE, digest=digest)
    return out


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    fx = os.path.join(here, "fixtures")
    os.makedirs(fx, exist_ok=True)
    for label, cert in build().items():
        der = cert.public_bytes(serialization.Encoding.DER)
        with open(os.path.join(fx, label + ".der"), "wb") as f:
            f.write(der)
        print(f"  {label:<18} {len(der):4} bytes")
