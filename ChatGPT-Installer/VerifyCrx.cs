using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;

// Verifies the developer RSA proof bound to the requested extension ID.
// This is not a replacement for Chrome's complete Web Store verifier.
public static class VerifyCrx {
    static byte[] Slice(byte[] b, int p, int n) {
        if (p < 0 || n < 0 || p > b.Length - n) throw new InvalidDataException("Truncated package");
        var r = new byte[n]; Buffer.BlockCopy(b,p,r,0,n); return r;
    }
    static int Varint(byte[] b, ref int p) {
        long v = 0;
        for (int s=0;s<35;s+=7) {
            if(p>=b.Length) throw new InvalidDataException("Invalid protobuf");
            byte c=b[p++]; v |= (long)(c & 127)<<s;
            if((c&128)==0) { if(v>int.MaxValue) break; return (int)v; }
        }
        throw new InvalidDataException("Oversized protobuf value");
    }
    static List<byte[]> Fields(byte[] b, int field) {
        var values=new List<byte[]>(); int p=0;
        while(p<b.Length) {
            int tag=Varint(b,ref p), wire=tag&7;
            if(tag==0) throw new InvalidDataException("Invalid protobuf tag");
            if(wire==2) {
                int n=Varint(b,ref p); var v=Slice(b,p,n); p+=n;
                if((tag>>3)==field) values.Add(v);
            } else if(wire==0) { Varint(b,ref p); }
            else if(wire==1 || wire==5) { int n=wire==1?8:4; Slice(b,p,n); p+=n; }
            else throw new InvalidDataException("Unsupported protobuf wire type");
        }
        return values;
    }
    static byte[] One(byte[] b,int field) {
        var v=Fields(b,field);
        if(v.Count!=1) throw new InvalidDataException("Missing or duplicate field");
        return v[0];
    }
    static byte[] Der(byte[] b,ref int p,int tag) {
        if(p>=b.Length || b[p++]!=tag || p>=b.Length) throw new InvalidDataException("Invalid RSA key");
        int n=b[p++];
        if(n>=128) {
            int count=n&127; n=0;
            if(count<1 || count>4) throw new InvalidDataException("Invalid DER length");
            for(int i=0;i<count;i++) { if(p>=b.Length) throw new InvalidDataException(); n=checked(n*256+b[p++]); }
        }
        var result=Slice(b,p,n); p+=n; return result;
    }
    static byte[] Integer(byte[] b,ref int p) {
        var n=Der(b,ref p,2);
        if(n.Length>1 && n[0]==0) return Slice(n,1,n.Length-1);
        return n;
    }
    static RSAParameters RsaKey(byte[] spki) {
        int p=0; var seq=Der(spki,ref p,48); p=0;
        Der(seq,ref p,48); var bits=Der(seq,ref p,3);
        if(bits.Length<2 || bits[0]!=0) throw new InvalidDataException("Invalid RSA bit string");
        p=1; var key=Der(bits,ref p,48); p=0;
        return new RSAParameters { Modulus=Integer(key,ref p), Exponent=Integer(key,ref p) };
    }
    static string Id(byte[] b) {
        if(b.Length<16) throw new InvalidDataException("Invalid ID");
        var s=new StringBuilder();
        for(int i=0;i<16;i++) {s.Append((char)('a'+(b[i]>>4))); s.Append((char)('a'+(b[i]&15)));}
        return s.ToString();
    }
    public static string ExtractZip(string crx,string zip,string expectedId) {
        var info=new FileInfo(crx);
        if(info.Length<12 || info.Length>150*1024*1024) throw new InvalidDataException("Invalid package size");
        byte[] b=File.ReadAllBytes(crx);
        if(Encoding.ASCII.GetString(b,0,4)!="Cr24" || BitConverter.ToUInt32(b,4)!=3)
            throw new InvalidDataException("Google did not return a CRX3 package");
        uint n=BitConverter.ToUInt32(b,8);
        if(n>4*1024*1024 || n>b.Length-12) throw new InvalidDataException("Invalid CRX header");
        int offset=12+(int)n;
        var header=Slice(b,12,(int)n); var signed=One(header,10000);
        var declared=One(signed,1);
        if(declared.Length!=16 || Id(declared)!=expectedId) throw new InvalidDataException("Extension ID mismatch");
        byte[] digest;
        using(var sha=SHA256.Create())
        using(var data=new MemoryStream()) {
            byte[] prefix=Encoding.ASCII.GetBytes("CRX3 SignedData\0");
            data.Write(prefix,0,prefix.Length);
            byte[] len=BitConverter.GetBytes(signed.Length); data.Write(len,0,4);
            data.Write(signed,0,signed.Length); data.Write(b,offset,b.Length-offset);
            data.Position=0; digest=sha.ComputeHash(data);
        }
        foreach(var proof in Fields(header,2)) {
            var key=One(proof,1); var signature=One(proof,2);
            using(var sha=SHA256.Create()) { if(Id(sha.ComputeHash(key))!=expectedId) continue; }
            using(var rsa=new RSACryptoServiceProvider()) {
                rsa.PersistKeyInCsp=false; rsa.ImportParameters(RsaKey(key));
                if(!rsa.VerifyHash(digest,CryptoConfig.MapNameToOID("SHA256"),signature))
                    throw new InvalidDataException("Invalid developer signature");
            }
            File.WriteAllBytes(zip,Slice(b,offset,b.Length-offset));
            return Convert.ToBase64String(key);
        }
        throw new InvalidDataException("No matching RSA developer proof; refusing unsupported package");
    }
}
