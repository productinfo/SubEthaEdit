//
//  NSStringTCMAdditions.m
//  
//
//  Created by Martin Ott on Tue Feb 17 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "NSStringTCMAdditions.h"
#import <OgreKit/OgreKit.h>

#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <sys/socket.h>

static void convertLineEndingsInString(NSMutableString *string, NSString *newLineEnding)
{
    unsigned newEOLLen;
    unichar newEOLStackBuf[2];
    unichar *newEOLBuf;
    BOOL freeNewEOLBuf = NO;

    unsigned length = [string length];
    unsigned curPos = 0;
    unsigned start, end, contentsEnd;


    newEOLLen = [newLineEnding length];
    if (newEOLLen > 2) {
        newEOLBuf = NSZoneMalloc(NULL, sizeof(unichar) * newEOLLen);
        freeNewEOLBuf = YES;
    } else {
        newEOLBuf = newEOLStackBuf;
    }
    [newLineEnding getCharacters:newEOLBuf];

    NSMutableArray *changes=[[NSMutableArray alloc] init];

    while (curPos < length) {
        [string getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:NSMakeRange(curPos, 0)];
        if (contentsEnd < end) {
            int oldLength = (end - contentsEnd);
            int changeInLength = newEOLLen - oldLength;
            BOOL alreadyNewEOL = YES;
            if (changeInLength == 0) {
                unsigned i;
                for (i = 0; i < newEOLLen; i++) {
                    if ([string characterAtIndex:contentsEnd + i] != newEOLBuf[i]) {
                        alreadyNewEOL = NO;
                        break;
                    }
                }
            } else {
                alreadyNewEOL = NO;
            }
            if (!alreadyNewEOL) {
                [changes addObject:[NSValue valueWithRange:NSMakeRange(contentsEnd, oldLength)]];
            }
        }
        curPos = end;
    }

    int count=[changes count];
    while (--count >= 0) {
        [string replaceCharactersInRange:[[changes objectAtIndex:count] rangeValue] withString:newLineEnding];
        // TODO: put this change also into the undomanager
    }

    [changes release];

    if (freeNewEOLBuf) {
        NSZoneFree(NSZoneFromPointer(newEOLBuf), newEOLBuf);
    }
}

@implementation NSMutableString (NSStringTCMAdditions)

- (void)convertLineEndingsToLineEndingString:(NSString *)aNewLineEndingString {
    convertLineEndingsInString(self,aNewLineEndingString);
}

- (NSMutableString *)addBRs {
    unsigned index=[self length];
    unsigned startIndex,lineEndIndex,contentsEndIndex;
    while (index!=0) {
        [self getLineStart:&startIndex end:&lineEndIndex contentsEnd:&contentsEndIndex forRange:NSMakeRange(index-1,0)];
        if (contentsEndIndex!=lineEndIndex) {
            [self replaceCharactersInRange:NSMakeRange(contentsEndIndex,0)
                  withString:@"<br />"];
        }
        index=startIndex;
    }
    return self;
}


@end


@implementation NSString (NSStringTCMAdditions) 

+ (NSString *)stringWithUUIDData:(NSData *)aData {
    if (aData!=nil) {
        CFUUIDRef uuid=CFUUIDCreateFromUUIDBytes(NULL,*(CFUUIDBytes *)[aData bytes]);
        NSString *uuidString=(NSString *)CFUUIDCreateString(NULL,uuid);
        CFRelease(uuid);
        return [uuidString autorelease];
    } else {
        return nil;
    }
}


+ (NSString *)stringWithAddressData:(NSData *)aData
{
    struct sockaddr *socketAddress = (struct sockaddr *)[aData bytes];
    
    // IPv6 Addresses are "FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF" at max, which is 40 bytes (0-terminated)
    // IPv4 Addresses are "255.255.255.255" at max which is smaller
    
    char stringBuffer[40];
    NSString *addressAsString = nil;
    if (socketAddress->sa_family == AF_INET) {
        if (inet_ntop(AF_INET, &((struct in_addr)((struct sockaddr_in *)socketAddress)->sin_addr), stringBuffer, 40)) {
            addressAsString = [NSString stringWithUTF8String:stringBuffer];
        } else {
            addressAsString = @"IPv4 un-ntopable";
        }
        int port = ((struct sockaddr_in *)socketAddress)->sin_port;
        addressAsString = [addressAsString stringByAppendingFormat:@":%d", port];
    } else if (socketAddress->sa_family == AF_INET6) {
         if (inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)socketAddress)->sin6_addr), stringBuffer, 40)) {
            addressAsString = [NSString stringWithUTF8String:stringBuffer];
        } else {
            addressAsString = @"IPv6 un-ntopable";
        }
        int port = ((struct sockaddr_in6 *)socketAddress)->sin6_port;
        
        // Suggested IPv6 format (see http://www.faqs.org/rfcs/rfc2732.html)
        addressAsString = [NSString stringWithFormat:@"[%@]:%d", addressAsString, port]; 
    } else {
        addressAsString = @"neither IPv6 nor IPv4";
    }
    
    return [[addressAsString copy] autorelease];
}

+ (NSString *)stringWithData:(NSData *)aData encoding:(NSStringEncoding)aEncoding
{
    return [[[NSString alloc] initWithData:aData encoding:aEncoding] autorelease];
}

+ (NSString *)UUIDString
{
    CFUUIDRef myUUID = CFUUIDCreate(NULL);
    CFStringRef myUUIDString = CFUUIDCreateString(NULL, myUUID);
    [(NSString *)myUUIDString retain];
    CFRelease(myUUIDString);
    CFRelease(myUUID);
    
    return [(NSString *)myUUIDString autorelease];
}

- (BOOL) isValidSerial 
{
    NSArray *splitArray = [self componentsSeparatedByString:@"-"];
    if ([splitArray count]==4) {
        NSString *zero = [splitArray objectAtIndex:0];
        NSString *one = [splitArray objectAtIndex:1];
        NSString *two = [splitArray objectAtIndex:2];
        NSString *tri = [splitArray objectAtIndex:3];
        if (([zero length] == 3) && ([one length] == 4) && ([two length] == 4) && ([tri length] == 4)) {
            long prefix = [zero base36Value];
            // Buchstaben zwirbeln
            long number = [[NSString stringWithFormat:@"%c%c%c%c",
                      [two characterAtIndex:3],
                      [one characterAtIndex:1],
                      [tri characterAtIndex:0],
                      [tri characterAtIndex:2]] base36Value];
            long rndnumber = [[NSString stringWithFormat:@"%c%c%c%c",
                      [one characterAtIndex:0],
                      [tri characterAtIndex:3],
                      [two characterAtIndex:0],
                      [one characterAtIndex:3]] base36Value];
            long chksum = [[NSString stringWithFormat:@"%c%c%c%c",
                      [two characterAtIndex:1],
                      [one characterAtIndex:2],
                      [tri characterAtIndex:1],
                      [two characterAtIndex:2]] base36Value];
            // check for validity
            if (((rndnumber%42) == 0) && (rndnumber >= 42*1111)) {
                if ((((prefix+number+chksum+rndnumber)%4242)==0) && (chksum >= 42*1111)) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (long) base36Value 
{
    unichar c;
    int i,p;
    long result = 0;
    NSString *aString = [self uppercaseString];
    
    for (i=[aString length]-1,p=0;i>=0;i--,p++) {
        c = [aString characterAtIndex:i];
        // 65-90:A-Z, 48-57:0-9
        if ((c >= 48) && (c <= 57)) {
            result += (long)(c-48)*pow(36,p);
        }
        if ((c >= 65) && (c <= 90)) {
            result += (long)(c-55)*pow(36,p);
        }
    }
    
    return result;
}

- (BOOL)isWhiteSpace {
    static unichar s_space=0,s_tab,s_cr,s_nl;
    if (s_space==0) {
        s_space=[@" " characterAtIndex:0];
        s_tab=[@"\t" characterAtIndex:0];
        s_cr=[@"\r" characterAtIndex:0];
        s_nl=[@"\n" characterAtIndex:0];
    }

    unsigned int i=0;
    BOOL result=YES;
    for (i=0;i<[self length];i++) {
        unichar character=[self characterAtIndex:i];
        if (character!=s_space &&
            character!=s_tab &&
            character!=s_cr &&
            character!=s_nl) {
            result=NO;
            break;    
        }
    }
    return result;
}

- (unsigned) detabbedLengthForRange:(NSRange)aRange tabWidth:(int)aTabWidth {
    NSRange foundRange=[self rangeOfString:@"\t" options:0 range:aRange];
    if (foundRange.location==NSNotFound) {
        return aRange.length;
    } else {
        unsigned additionalLength=0;
        NSRange searchRange=aRange;
        while (foundRange.location!=NSNotFound) {
            additionalLength+=aTabWidth-((foundRange.location-aRange.location+additionalLength)%aTabWidth+1);
            searchRange.length-=foundRange.location-searchRange.location+1;
            searchRange.location=foundRange.location+1;
            foundRange=[self rangeOfString:@"\t" options:0 range:searchRange];
        }
        return aRange.length+additionalLength;
    }
}

- (BOOL)detabbedLength:(unsigned)aLength fromIndex:(unsigned)aFromIndex 
                length:(unsigned *)rLength upToCharacterIndex:(unsigned *)rIndex
              tabWidth:(int)aTabWidth {
    NSRange searchRange=NSMakeRange(aFromIndex,aLength);
    if (NSMaxRange(searchRange)>[self length]) {
        searchRange.length=[self length]-searchRange.location;
    }
    NSRange foundRange=[self rangeOfString:@"\t" options:0 range:searchRange];
    if (foundRange.location==NSNotFound) {
        *rLength=searchRange.length;
        *rIndex=aFromIndex+searchRange.length;
        return (searchRange.length==aLength);
    } else {
        NSRange lineRange=[self lineRangeForRange:NSMakeRange(aFromIndex,0)];
        *rLength=0;
        while (foundRange.location!=NSNotFound) {
            if (aLength<foundRange.location-searchRange.location) {
                *rLength+=aLength;
                *rIndex=searchRange.location+aLength;
                return YES;
            } else {
                int movement=foundRange.location-searchRange.location;
                *rLength+=movement;
                aLength -=movement;
                int spacesTabTakes=aTabWidth-(aFromIndex-lineRange.location+(*rLength))%aTabWidth;
                if (spacesTabTakes>(int)aLength) {
                    *rIndex=foundRange.location;
                    return NO;
                } else {
                    *rLength+=spacesTabTakes;
                    aLength -=spacesTabTakes;
                    searchRange.location+=movement+1;
                    searchRange.length  -=movement+1;
                }
            }
            foundRange=[self rangeOfString:@"\t" options:0 range:searchRange];
        }
        
        if (aLength<=searchRange.length) {
            *rLength+=aLength;
            *rIndex  =searchRange.location+aLength;
            return YES;
        } else {
            *rLength+=searchRange.length;
            *rIndex  =NSMaxRange(searchRange);
            return NO;
        }
    }
}

- (NSMutableString *)stringByReplacingEntitiesForUTF8:(BOOL)forUTF8  {
    static NSDictionary *sEntities=nil;
    if (!sEntities) {
        sEntities=[[NSDictionary dictionaryWithObjectsAndKeys:
          @"&iexcl;",@"&#161;",
          @"&cent;",@"&#162;",
          @"&pound;",@"&#163;",
          @"&curren;",@"&#164;",
          @"&yen;",@"&#165;",
          @"&brvbar;",@"&#166;",
          @"&sect;",@"&#167;",
          @"&uml;",@"&#168;",
          @"&copy;",@"&#169;",
          @"&ordf;",@"&#170;",
          @"&laquo;",@"&#171;",
          @"&not;",@"&#172;",
          @"&reg;",@"&#174;",
          @"&macr;",@"&#175;",
          @"&deg;",@"&#176;",
          @"&plusmn;",@"&#177;",
          @"&sup2;",@"&#178;",
          @"&sup3;",@"&#179;",
          @"&acute;",@"&#180;",
          @"&micro;",@"&#181;",
          @"&para;",@"&#182;",
          @"&middot;",@"&#183;",
          @"&cedil;",@"&#184;",
          @"&sup1;",@"&#185;",
          @"&ordm;",@"&#186;",
          @"&raquo;",@"&#187;",
          @"&frac14;",@"&#188;",
          @"&frac12;",@"&#189;",
          @"&frac34;",@"&#190;",
          @"&iquest;",@"&#191;",
          @"&Agrave;",@"&#192;",
          @"&Aacute;",@"&#193;",
          @"&Acirc;",@"&#194;",
          @"&Atilde;",@"&#195;",
          @"&Auml;",@"&#196;",
          @"&Aring;",@"&#197;",
          @"&AElig;",@"&#198;",
          @"&Ccedil;",@"&#199;",
          @"&Egrave;",@"&#200;",
          @"&Eacute;",@"&#201;",
          @"&Ecirc;",@"&#202;",
          @"&Euml;",@"&#203;",
          @"&Igrave;",@"&#204;",
          @"&Iacute;",@"&#205;",
          @"&Icirc;",@"&#206;",
          @"&Iuml;",@"&#207;",
          @"&ETH;",@"&#208;",
          @"&Ntilde;",@"&#209;",
          @"&Ograve;",@"&#210;",
          @"&Oacute;",@"&#211;",
          @"&Ocirc;",@"&#212;",
          @"&Otilde;",@"&#213;",
          @"&Ouml;",@"&#214;",
          @"&times;",@"&#215;",
          @"&Oslash;",@"&#216;",
          @"&Ugrave;",@"&#217;",
          @"&Uacute;",@"&#218;",
          @"&Ucirc;",@"&#219;",
          @"&Uuml;",@"&#220;",
          @"&Yacute;",@"&#221;",
          @"&THORN;",@"&#222;",
          @"&szlig;",@"&#223;",
          @"&agrave;",@"&#224;",
          @"&aacute;",@"&#225;",
          @"&acirc;",@"&#226;",
          @"&atilde;",@"&#227;",
          @"&auml;",@"&#228;",
          @"&aring;",@"&#229;",
          @"&aelig;",@"&#230;",
          @"&ccedil;",@"&#231;",
          @"&egrave;",@"&#232;",
          @"&eacute;",@"&#233;",
          @"&ecirc;",@"&#234;",
          @"&euml;",@"&#235;",
          @"&igrave;",@"&#236;",
          @"&iacute;",@"&#237;",
          @"&icirc;",@"&#238;",
          @"&iuml;",@"&#239;",
          @"&eth;",@"&#240;",
          @"&ntilde;",@"&#241;",
          @"&ograve;",@"&#242;",
          @"&oacute;",@"&#243;",
          @"&ocirc;",@"&#244;",
          @"&otilde;",@"&#245;",
          @"&ouml;",@"&#246;",
          @"&divide;",@"&#247;",
          @"&oslash;",@"&#248;",
          @"&ugrave;",@"&#249;",
          @"&uacute;",@"&#250;",
          @"&ucirc;",@"&#251;",
          @"&uuml;",@"&#252;",
          @"&yacute;",@"&#253;",
          @"&thorn;",@"&#254;",
          @"&yuml;",@"&#255;",
          @"&OElig;",@"&#338;",
          @"&oelig;",@"&#339;",
          @"&quot;",@"&#34;",
          @"&Scaron;",@"&#352;",
          @"&scaron;",@"&#353;",
          @"&Yuml;",@"&#376;",
          @"&amp;",@"&#38;",
          @"&fnof;",@"&#402;",
          @"&lt;",@"&#60;",
          @"&gt;",@"&#62;",
          @"&circ;",@"&#710;",
          @"&tilde;",@"&#732;",
          @"&ndash;",@"&#8211;",
          @"&mdash;",@"&#8212;",
          @"&lsquo;",@"&#8216;",
          @"&rsquo;",@"&#8217;",
          @"&sbquo;",@"&#8218;",
          @"&ldquo;",@"&#8220;",
          @"&rdquo;",@"&#8221;",
          @"&bdquo;",@"&#8222;",
          @"&dagger;",@"&#8224;",
          @"&Dagger;",@"&#8225;",
          @"&bull;",@"&#8226;",
          @"&hellip;",@"&#8230;",
          @"&permil;",@"&#8240;",
          @"&prime;",@"&#8242;",
          @"&Prime;",@"&#8243;",
          @"&lsaquo;",@"&#8249;",
          @"&rsaquo;",@"&#8250;",
          @"&oline;",@"&#8254;",
          @"&frasl;",@"&#8260;",
          @"&euro;",@"&#8364;",
          @"&image;",@"&#8465;",
          @"&weierp;",@"&#8472;",
          @"&real;",@"&#8476;",
          @"&trade;",@"&#8482;",
          @"&alefsym;",@"&#8501;",
          @"&larr;",@"&#8592;",
          @"&uarr;",@"&#8593;",
          @"&rarr;",@"&#8594;",
          @"&darr;",@"&#8595;",
          @"&harr;",@"&#8596;",
          @"&crarr;",@"&#8629;",
          @"&lArr;",@"&#8656;",
          @"&uArr;",@"&#8657;",
          @"&rArr;",@"&#8658;",
          @"&dArr;",@"&#8659;",
          @"&hArr;",@"&#8660;",
          @"&forall;",@"&#8704;",
          @"&part;",@"&#8706;",
          @"&exist;",@"&#8707;",
          @"&empty;",@"&#8709;",
          @"&nabla;",@"&#8711;",
          @"&isin;",@"&#8712;",
          @"&notin;",@"&#8713;",
          @"&ni;",@"&#8715;",
          @"&prod;",@"&#8719;",
          @"&sum;",@"&#8721;",
          @"&minus;",@"&#8722;",
          @"&lowast;",@"&#8727;",
          @"&radic;",@"&#8730;",
          @"&prop;",@"&#8733;",
          @"&infin;",@"&#8734;",
          @"&ang;",@"&#8736;",
          @"&and;",@"&#8743;",
          @"&or;",@"&#8744;",
          @"&cap;",@"&#8745;",
          @"&cup;",@"&#8746;",
          @"&int;",@"&#8747;",
          @"&there4;",@"&#8756;",
          @"&sim;",@"&#8764;",
          @"&cong;",@"&#8773;",
          @"&asymp;",@"&#8776;",
          @"&ne;",@"&#8800;",
          @"&equiv;",@"&#8801;",
          @"&le;",@"&#8804;",
          @"&ge;",@"&#8805;",
          @"&sub;",@"&#8834;",
          @"&sup;",@"&#8835;",
          @"&nsub;",@"&#8836;",
          @"&sube;",@"&#8838;",
          @"&supe;",@"&#8839;",
          @"&oplus;",@"&#8853;",
          @"&otimes;",@"&#8855;",
          @"&perp;",@"&#8869;",
          @"&sdot;",@"&#8901;",
          @"&lceil;",@"&#8968;",
          @"&rceil;",@"&#8969;",
          @"&lfloor;",@"&#8970;",
          @"&rfloor;",@"&#8971;",
          @"&lang;",@"&#9001;",
          @"&rang;",@"&#9002;",
          @"&Alpha;",@"&#913;",
          @"&Beta;",@"&#914;",
          @"&Gamma;",@"&#915;",
          @"&Delta;",@"&#916;",
          @"&Epsilon;",@"&#917;",
          @"&Zeta;",@"&#918;",
          @"&Eta;",@"&#919;",
          @"&Theta;",@"&#920;",
          @"&Iota;",@"&#921;",
          @"&Kappa;",@"&#922;",
          @"&Lambda;",@"&#923;",
          @"&Mu;",@"&#924;",
          @"&Nu;",@"&#925;",
          @"&Xi;",@"&#926;",
          @"&Omicron;",@"&#927;",
          @"&Pi;",@"&#928;",
          @"&Rho;",@"&#929;",
          @"&Sigma;",@"&#931;",
          @"&Tau;",@"&#932;",
          @"&Upsilon;",@"&#933;",
          @"&Phi;",@"&#934;",
          @"&Chi;",@"&#935;",
          @"&Psi;",@"&#936;",
          @"&Omega;",@"&#937;",
          @"&alpha;",@"&#945;",
          @"&beta;",@"&#946;",
          @"&gamma;",@"&#947;",
          @"&delta;",@"&#948;",
          @"&epsilon;",@"&#949;",
          @"&zeta;",@"&#950;",
          @"&eta;",@"&#951;",
          @"&theta;",@"&#952;",
          @"&iota;",@"&#953;",
          @"&kappa;",@"&#954;",
          @"&lambda;",@"&#955;",
          @"&mu;",@"&#956;",
          @"&nu;",@"&#957;",
          @"&xi;",@"&#958;",
          @"&omicron;",@"&#959;",
          @"&pi;",@"&#960;",
          @"&rho;",@"&#961;",
          @"&sigmaf;",@"&#962;",
          @"&sigma;",@"&#963;",
          @"&tau;",@"&#964;",
          @"&upsilon;",@"&#965;",
          @"&phi;",@"&#966;",
          @"&loz;",@"&#9674;",
          @"&chi;",@"&#967;",
          @"&psi;",@"&#968;",
          @"&omega;",@"&#969;",
          @"&thetasym;",@"&#977;",
          @"&upsih;",@"&#978;",
          @"&spades;",@"&#9824;",
          @"&clubs;",@"&#9827;",
          @"&hearts;",@"&#9829;",
          @"&piv;",@"&#982;",
          @"&emsp;",@"&#8195;",
          @"&ensp;",@"&#8194;",
          @"&lrm;",@"&#8206;",
          @"&nbsp;",@"&#160;",
          @"&rlm;",@"&#8207;",
          @"&shy;",@"&#173;",
          @"&thinsp;",@"&#8201;",
          @"&zwj;",@"&#8205;",
          @"&zwnj;",@"&#8204;",
          @"&diams;",@"&#9830;", nil] retain];
    }

    NSMutableString *string;
    string = [[self mutableCopy] autorelease];
    int index = 0;
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    while (index < [string length]) {
        unichar c=[string characterAtIndex:index];                         
        if ((c > 128 && !forUTF8) || c=='&' || c=='<' || c=='>') {                           
            NSString *encodedString = [NSString stringWithFormat: @"&#%d;", c];
            if ([sEntities objectForKey:encodedString]) {
                encodedString = [sEntities objectForKey:encodedString];
            }        
            [string replaceCharactersInRange:NSMakeRange(index, 1) withString:encodedString];
            index+=[encodedString length]-1;
        } else if (forUTF8) {
            if (c==0x00A0) {
                [string replaceCharactersInRange:NSMakeRange(index, 1) withString:@"&nbsp;"];
                index+=6-1;
            }
        }
//        else if (c=='\n' || c=='\r') {
//            [string replaceCharactersInRange:NSMakeRange(index,1) withString:@"<br/>\n"];
//            index+=5;
//        } else if (c=='\t') {
//            [string replaceCharactersInRange:NSMakeRange(index,1) withString:@"&nbsp;&nbsp;&nbsp;"];
//            index+=17;
//        } else if (c==' ') {
//            [string replaceCharactersInRange:NSMakeRange(index,1) withString:@"&nbsp;"];
//            index+=5;
//        }
        index ++; 
        if (index%50==0) {
            [pool release];
            pool=[[NSAutoreleasePool alloc] init];
        }                        
    }
    [pool release];
    
    return string;
}
@end

@implementation NSAttributedString (NSAttributedStringTCMAdditions)

/*"AttributeMapping:

        "WrittenBy" => { "openTag" => "<span class="@%">",
                             "closeTag" => "</span>"},
        "ForegroundColor" => {"openTag"=>"<span style="color: %@;">",
                              "closeTag"=>"</span>" }
        "Bold" => {"openTag" => "<strong>",
                   "closeTag" => "</strong>"}
        "Italic" => {"openTag" => "<em>",
                     "closeTag"=> "</em>"};
"*/

- (NSString *)XHTMLStringWithAttributeMapping:(NSDictionary *)anAttributeMapping forUTF8:(BOOL)forUTF8 {
    NSMutableString *result=[[[NSMutableString alloc] initWithCapacity:[self length]*2] autorelease];
    NSMutableDictionary *state=[NSMutableDictionary new];
    NSMutableDictionary *toOpen=[NSMutableDictionary new];
    NSMutableDictionary *toClose=[NSMutableDictionary new];
    NSMutableArray *stateStack=[NSMutableArray new];
    
    
    NSRange foundRange;
    NSRange maxRange=NSMakeRange(0,[self length]);
    NSDictionary *attributes;
    unsigned int index=0;
    do {
        NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
        attributes=[self attributesAtIndex:index
                    longestEffectiveRange:&foundRange inRange:maxRange];
        
        NSEnumerator *relevantAttributes=[anAttributeMapping keyEnumerator];
        NSString *key;
        while ((key=[relevantAttributes nextObject])) {
            id currentValue=[state      objectForKey:key];
            id nextValue   =[attributes objectForKey:key];
            if (currentValue == nil && nextValue == nil) {
                // nothing
            } else if (currentValue == nil) {
                [toOpen setObject:nextValue forKey:key];
            } else if (nextValue == nil) {
                [toClose setObject:currentValue forKey:key];
            } else if (![currentValue isEqual:nextValue]) {
                [toClose setObject:currentValue forKey:key];
                [toOpen setObject:nextValue forKey:key];
            }
        }
        int stackPosition=[stateStack count];
        while ([toClose count] && stackPosition>0) {
            stackPosition--;
            NSDictionary *pair=[stateStack objectAtIndex:stackPosition];
            NSString *attributeName=[pair objectForKey:@"AttributeName"];
            [result appendFormat:[[anAttributeMapping objectForKey:attributeName] objectForKey:@"closeTag"],[pair objectForKey:@"AttributeValue"]];
            if ([toClose objectForKey:attributeName]) {
                [toClose removeObjectForKey:attributeName];
                [stateStack removeObjectAtIndex:stackPosition];
                [state removeObjectForKey:attributeName];
            }
        }
        while (stackPosition<[stateStack count]) {
            NSDictionary *pair=[stateStack objectAtIndex:stackPosition];
            NSString *attributeName=[pair objectForKey:@"AttributeName"];
            [result appendFormat:[[anAttributeMapping objectForKey:attributeName] objectForKey:@"openTag"],[pair objectForKey:@"AttributeValue"]];
            stackPosition++;
        }
        NSEnumerator *openAttributes=[toOpen keyEnumerator];
        NSString *attributeName;
        while ((attributeName=[openAttributes nextObject])) {
            [result appendFormat:[[anAttributeMapping objectForKey:attributeName] objectForKey:@"openTag"],[toOpen objectForKey:attributeName]];
            [state setObject:[toOpen objectForKey:attributeName] forKey:attributeName];
            [stateStack addObject:[NSDictionary dictionaryWithObjectsAndKeys:attributeName,@"AttributeName",[toOpen objectForKey:attributeName],@"AttributeValue",nil]];
        }
        [toOpen removeAllObjects];
        
        NSString *contentString=[[[self string] substringWithRange:foundRange] stringByReplacingEntitiesForUTF8:forUTF8];
        [result appendString:contentString];
        
        index=NSMaxRange(foundRange);
        [pool release];
    } while (index<NSMaxRange(maxRange));
    // close all remaining open tags
    int stackPosition=[stateStack count];
    while (stackPosition>0) {
        stackPosition--;
        NSDictionary *pair=[stateStack objectAtIndex:stackPosition];
        NSString *attributeName=[pair objectForKey:@"AttributeName"];
        [result appendFormat:[[anAttributeMapping objectForKey:attributeName] objectForKey:@"closeTag"],[pair objectForKey:@"AttributeValue"]];
    }
    
    [toOpen release];
    [toClose release];
    [stateStack release];
    [state release];
    return result;
}

@end



@implementation NSMutableAttributedString (NSMutableAttributedStringTCMAdditions) 

- (NSRange)detab:(BOOL)shouldDetab inRange:(NSRange)aRange tabWidth:(int)aTabWidth askingTextView:(NSTextView *)aTextView {
    [self beginEditing];

    static OGRegularExpression *tabExpression,*spaceExpression;
    if (!tabExpression) {
        tabExpression  =[[OGRegularExpression regularExpressionWithString:@"\t+"] retain];
        spaceExpression=[[OGRegularExpression regularExpressionWithString:@"  +"] retain];
    }

    unsigned changeInLength=0;
    
    if (shouldDetab) {
        NSArray *matches=[tabExpression allMatchesInString:[self string] range:aRange];
        int i=0;
        int count=[matches count];
        for (i=0;i<count;i++) {
            OGRegularExpressionMatch *match=[matches objectAtIndex:i];
            NSRange matchRange=[match rangeOfMatchedString];
            matchRange.location+=changeInLength;
            NSRange lineRange=[[self string] lineRangeForRange:matchRange];
            int replacementStringLength=(matchRange.length-1)*aTabWidth+
                                        (aTabWidth-(matchRange.location-lineRange.location)%aTabWidth);
            NSString *replacementString=[@"" stringByPaddingToLength:replacementStringLength withString:@" " startingAtIndex:0];
            if ((aTextView && [aTextView shouldChangeTextInRange:matchRange replacementString:replacementString]) 
                || !aTextView) {
                [self replaceCharactersInRange:matchRange withString:replacementString];
                if (aTextView) {
                    [self addAttributes:[aTextView typingAttributes] 
                          range:NSMakeRange(matchRange.location,replacementStringLength)];
                }
                changeInLength+=replacementStringLength-matchRange.length;
            }
        }
    } else {
        NSArray *matches=[spaceExpression allMatchesInString:[self string] range:aRange];
        int i=0;
        int count=[matches count];
        for (i=count-1;i>=0;i--) {
            OGRegularExpressionMatch *match=[matches objectAtIndex:i];
            NSRange matchRange=[match rangeOfMatchedString];
            NSRange lineRange=[[self string] lineRangeForRange:matchRange];
            if (matchRange.length>=(aTabWidth-(matchRange.location-lineRange.location)%aTabWidth)) {
                // align end of spaces to tab boundary
                matchRange.length-=(NSMaxRange(matchRange)-lineRange.location)%aTabWidth;
                int replacementStringLength=matchRange.length/aTabWidth;
                if ((matchRange.location-lineRange.location)%aTabWidth!=0) replacementStringLength+=1;
                NSString *replacementString=[@"" stringByPaddingToLength:replacementStringLength withString:@"\t" startingAtIndex:0];
                if ((aTextView && [aTextView shouldChangeTextInRange:matchRange replacementString:replacementString])
                    || !aTextView) {
                    [self replaceCharactersInRange:matchRange withString:replacementString];
                    if (aTextView) {
                        [self addAttributes:[aTextView typingAttributes] 
                              range:NSMakeRange(matchRange.location,replacementStringLength)];
                    }
                    changeInLength+=replacementStringLength-matchRange.length;
                }
            }
        }
    }

    aRange.length+=changeInLength;
    [self endEditing];

    [aTextView didChangeText];
    return aRange;
}


- (void)makeLeadingWhitespaceNonBreaking {
    NSString *hardspaceString=nil;
    if (hardspaceString==nil) {
        unichar hardspace=0x00A0;
        hardspaceString=[[NSString stringWithCharacters:&hardspace length:1] retain];
    }
    unsigned index=[self length];
    unsigned startIndex,lineEndIndex,contentsEndIndex;
    while (index!=0) {
        [[self string] getLineStart:&startIndex end:&lineEndIndex contentsEnd:&contentsEndIndex forRange:NSMakeRange(index-1,0)];
        unsigned firstNonWhitespace=startIndex;
        NSString *string=[self string];
        while (firstNonWhitespace<contentsEndIndex &&
               [string characterAtIndex:firstNonWhitespace]==' ') {
            firstNonWhitespace++;
        }
        if (firstNonWhitespace>startIndex) {
            NSRange replaceRange=NSMakeRange(startIndex,firstNonWhitespace-startIndex);
            [self replaceCharactersInRange:replaceRange
                  withString:[@"" stringByPaddingToLength:replaceRange.length withString:hardspaceString startingAtIndex:0]];
        }
        index=startIndex;
    }
    
    OGRegularExpression *moreThanOneSpace=[[[OGRegularExpression alloc] initWithString:@"  +" options:OgreFindLongestOption|OgreFindNotEmptyOption] autorelease];
    NSEnumerator *matches=[[moreThanOneSpace allMatchesInString:[self string] range:NSMakeRange(0,[self length])] reverseObjectEnumerator];
    OGRegularExpressionMatch *match=nil;
    while ((match=[matches nextObject])) {
        NSRange matchRange=[match rangeOfMatchedString];
        [self replaceCharactersInRange:matchRange
              withString:[@" " stringByPaddingToLength:matchRange.length withString:hardspaceString startingAtIndex:0]];
    }
}

- (void)appendString:(NSString *)aString {
    [self replaceCharactersInRange:NSMakeRange([self length],0) withString:aString];
}


@end