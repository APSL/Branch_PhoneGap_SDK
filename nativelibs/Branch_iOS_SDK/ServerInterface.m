//
//  ServerInterface.m
//  Branch-SDK
//
//  Created by Alex Austin on 6/6/14.
//  Copyright (c) 2014 Branch Metrics. All rights reserved.
//

#import "ServerInterface.h"
#import "PreferenceHelper.h"
#import "Config.h"

@implementation ServerInterface

// make a generalized get request
- (void)getRequestAsync:(NSDictionary *)params url:(NSString *)url andTag:(NSString *)requestTag {
    if (params) {
        NSArray *allKeys = [params allKeys];
        if ([allKeys count] > 0) {
            url = [url stringByAppendingString:@"?"];
        }
        int count = (int)[allKeys count];
        int i = 0;
        for (NSString *key in allKeys) {
            if ([key length] > 0) {
                if ([params objectForKey:key]) {
                    url = [url stringByAppendingString:key];
                    url = [url stringByAppendingString:@"="];
                    url = [url stringByAppendingString:[[params objectForKey:key] description]];
                    if(i < count-1)
                        url = [url stringByAppendingString:@"&"];
                }
            }
            i = i + 1;
        }
    }
    Debug(@"using url = %@", url);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    
    [request setHTTPMethod:@"GET"];
    [request setValue:@"0" forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"applications/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:nil];
    
    [self genericHTTPRequest:request withTag:requestTag];
}

// make a generalized post request
- (void)postRequestAsync:(NSDictionary *)post url:(NSString *)url andTag:(NSString *)requestTag {
    NSData *postData = [ServerInterface encodePostParams:post];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    Debug(@"using url = %@", url);
    Debug(@"body = %@", [post description]);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setTimeoutInterval:3];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:postData];
    
    [self genericHTTPRequest:request withTag:requestTag];
}

+ (NSData *)encodePostParams:(NSDictionary *)params {
    NSError *writeError = nil;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&writeError];
    return postData;
}

+ (NSString *)encodePostToUniversalString:(NSDictionary *)params {
    NSMutableString *encodedParams = [[NSMutableString alloc] initWithString:@"{ "];
    for (NSString *key in params) {
        NSString *value = nil;
        BOOL string = YES;
        if ([[params objectForKey:key] isKindOfClass:[NSString class]]) {
            value = [params objectForKey:key];
        } else if ([[params objectForKey:key] isKindOfClass:[NSDictionary class]]) {
            value = [ServerInterface encodePostToUniversalString:[params objectForKey:key]];
        } else if ([[params objectForKey:key] isKindOfClass:[NSNumber class]]) {
            value = [[params objectForKey:key] stringValue];
            string = NO;
        }
        [encodedParams appendString:@"\""];
        [encodedParams appendString:key];
        if (string) [encodedParams appendString:@"\":\""];
        else [encodedParams appendString:@"\":"];
        [encodedParams appendString:value];
        if (string) [encodedParams appendString:@"\","];
        else [encodedParams appendString:@","];
    }
    [encodedParams appendString:@"\"source\":\"ios\" }"];
    Debug(@"encoded params : %@", encodedParams);
    return encodedParams;
}

- (void)genericHTTPRequest:(NSMutableURLRequest *)request withTag:(NSString *)requestTag {
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler: ^(NSURLResponse *response, NSData *POSTReply, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSNumber *statusCode = [NSNumber numberWithLong:[httpResponse statusCode]];
        
        ServerResponse *serverResponse = [[ServerResponse alloc] initWithTag:requestTag andStatusCode:statusCode];
        
        if (POSTReply != nil) {
            NSError *convError;
            id jsonData = [NSJSONSerialization JSONObjectWithData:POSTReply options:NSJSONReadingMutableContainers error:&convError];
            serverResponse.data = jsonData;            
        }
        
        Debug(@"returned = %@", [serverResponse description]);
        
        if (self.delegate) [self.delegate serverCallback:serverResponse];
    }];
}


@end
